#!/usr/bin/env python3
"""Assemble the committed ramdisk overlay on the verified upstream TWRP image.

This preserves the upstream recovery executable (including its touch scaling
fix). It does not claim to rebuild that executable from source. CPIO ownership,
symlinks and modes are preserved without extracting them onto the host OS.
"""

import argparse
import hashlib
import json
import stat
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import lz4.block


ROOT = Path(__file__).resolve().parents[1]
BASE_SHA256 = "a55684ef0362b08f6776a5ff5fdf343976a7c7b58a6ccb883e67e11beeb35307"
AVBTOOL_SHA256 = "e5a664a38db623da00f080219bc0ee60a640a9dc4a872803616fae4938ac749b"
PARTITION_SIZE = 104857600
LZ4_MAGIC = b"\x02\x21\x4c\x18"
BLOCK_SIZE = 8 * 1024 * 1024


def align(value, boundary):
    return (value + boundary - 1) // boundary * boundary


@dataclass
class Entry:
    name: str
    fields: list[int]
    data: bytes

    def pack(self):
        name = self.name.encode() + b"\0"
        fields = self.fields.copy()
        fields[6] = len(self.data)
        fields[11] = len(name)
        header = b"070701" + b"".join(f"{value:08x}".encode() for value in fields)
        result = header + name
        result += bytes(align(len(result), 4) - len(result))
        result += self.data
        return result + bytes(align(len(result), 4) - len(result))


def read_cpio(data):
    entries = {}
    offset = 0
    while offset + 110 <= len(data):
        if data[offset:offset + 6] != b"070701":
            raise ValueError(f"Unsupported CPIO header at {offset}")
        fields = [int(data[offset + 6 + i * 8:offset + 14 + i * 8], 16)
                  for i in range(13)]
        name_end = offset + 110 + fields[11]
        if data[name_end - 1:name_end] != b"\0":
            raise ValueError("CPIO name is not terminated")
        name = data[offset + 110:name_end - 1].decode()
        start = align(name_end, 4)
        end = start + fields[6]
        if end > len(data):
            raise ValueError("Truncated CPIO entry")
        if name == "TRAILER!!!":
            if any(data[align(end, 4):]):
                raise ValueError("Unexpected content after CPIO trailer")
            return entries
        if name in entries or name.startswith("/") or ".." in Path(name).parts:
            raise ValueError(f"Unsafe or duplicate CPIO name: {name}")
        entries[name] = Entry(name, fields, data[start:end])
        offset = align(end, 4)
    raise ValueError("Missing CPIO trailer")


def decompress_ramdisk(data):
    if not data.startswith(LZ4_MAGIC):
        raise ValueError("Expected legacy LZ4 ramdisk")
    blocks = []
    offset = len(LZ4_MAGIC)
    while offset < len(data):
        size, = struct.unpack_from("<I", data, offset)
        offset += 4
        if not size or offset + size > len(data):
            raise ValueError("Invalid LZ4 block")
        blocks.append(lz4.block.decompress(data[offset:offset + size],
                                          uncompressed_size=BLOCK_SIZE))
        offset += size
    return b"".join(blocks)


def compress_ramdisk(data):
    result = bytearray(LZ4_MAGIC)
    for offset in range(0, len(data), BLOCK_SIZE):
        block = lz4.block.compress(data[offset:offset + BLOCK_SIZE],
                                   mode="high_compression", compression=9,
                                   store_size=False)
        result.extend(struct.pack("<I", len(block)))
        result.extend(block)
    return bytes(result)


def apply_overlay(entries, config, firmware_dir):
    changed = {}
    next_inode = max(entry.fields[0] for entry in entries.values()) + 1
    contents = {}
    for target, source in config["files"].items():
        path = (ROOT / source).resolve()
        path.relative_to(ROOT)
        contents[target] = path.read_bytes()
    for target, expected in config["firmware_files"].items():
        path = (firmware_dir / target).resolve()
        path.relative_to(firmware_dir.resolve())
        content = path.read_bytes()
        if hashlib.sha256(content).hexdigest() != expected:
            raise ValueError(f"Firmware input SHA256 mismatch: {target}")
        if target in contents:
            raise ValueError(f"Duplicate overlay target: {target}")
        contents[target] = content
    for target, content in contents.items():
        if target in entries:
            entry = entries[target]
            if not stat.S_ISREG(entry.fields[1]):
                raise ValueError(f"Overlay target is not a regular file: {target}")
            entry.data = content
        else:
            parent = str(Path(target).parent).replace("\\", "/")
            if parent not in entries or not stat.S_ISDIR(entries[parent].fields[1]):
                raise ValueError(f"Missing parent directory: {parent}")
            mode = 0o100755 if target.endswith(".sh") else 0o100644
            fields = [next_inode, mode, 0, 0, 1, 0, len(content), 0, 0, 0, 0, 0, 0]
            entries[target] = Entry(target, fields, content)
            next_inode += 1
        changed[target] = hashlib.sha256(content).hexdigest()

    properties = config["properties"]
    found = set()
    lines = []
    for line in entries["prop.default"].data.decode().splitlines():
        key, separator, value = line.partition("=")
        if separator and key in properties:
            value = properties[key]
            found.add(key)
        lines.append(key + separator + value)
    if found != properties.keys():
        raise ValueError(f"Missing properties: {properties.keys() - found}")
    entries["prop.default"].data = ("\n".join(lines) + "\n").encode()
    changed["prop.default"] = hashlib.sha256(entries["prop.default"].data).hexdigest()
    return changed


def build(base, output, firmware_dir):
    if output.name != "recovery.img":
        raise ValueError("Use a versioned directory with filename recovery.img for AVB verification")
    image = base.read_bytes()
    if hashlib.sha256(image).hexdigest() != BASE_SHA256:
        raise ValueError("Upstream image SHA256 does not match the pinned release")
    if len(image) != PARTITION_SIZE or image[:8] != b"ANDROID!":
        raise ValueError("Unexpected boot image")
    if struct.unpack_from("<I", image, 8)[0] != 0:
        raise ValueError("This assembler only supports kernel-less recovery")
    if struct.unpack_from("<I", image, 40)[0] != 4:
        raise ValueError("Expected boot header v4")
    if struct.unpack_from("<I", image, 1580)[0] != 0:
        raise ValueError("Unexpected boot signature")

    size, = struct.unpack_from("<I", image, 12)
    entries = read_cpio(decompress_ramdisk(image[4096:4096 + size]))
    before = {name: (entry.fields.copy(), entry.data) for name, entry in entries.items()}
    config = json.loads((ROOT / "ramdisk-overlay.json").read_text())
    changed = apply_overlay(entries, config, firmware_dir)
    for name, (fields, content) in before.items():
        if entries[name].fields != fields:
            raise ValueError(f"Unexpected CPIO metadata change: {name}")
        if name not in changed and entries[name].data != content:
            raise ValueError(f"Unexpected content change: {name}")

    trailer = Entry("TRAILER!!!", [0] * 13, b"")
    archive = b"".join(entry.pack() for entry in entries.values()) + trailer.pack()
    archive += bytes(align(len(archive), 512) - len(archive))
    ramdisk = compress_ramdisk(archive)
    if decompress_ramdisk(ramdisk) != archive:
        raise ValueError("Ramdisk compression roundtrip failed")
    reread = read_cpio(archive)
    if {name: entry.data for name, entry in reread.items()} != {
            name: entry.data for name, entry in entries.items()}:
        raise ValueError("CPIO roundtrip failed")

    header = bytearray(image[:4096])
    struct.pack_into("<I", header, 12, len(ramdisk))
    payload = bytes(header) + ramdisk
    payload += bytes(align(len(payload), 4096) - len(payload))
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise FileExistsError(output)
    output.write_bytes(payload)
    avbtool = ROOT / "tools/avbtool.py"
    if hashlib.sha256(avbtool.read_bytes()).hexdigest() != AVBTOOL_SHA256:
        raise ValueError("Unexpected avbtool source")
    subprocess.run([sys.executable, str(avbtool), "add_hash_footer", "--image", str(output),
                    "--partition_name", "recovery", "--partition_size", str(PARTITION_SIZE),
                    "--algorithm", "NONE", "--salt", ""], check=True)
    subprocess.run([sys.executable, str(avbtool), "verify_image", "--image", str(output)],
                   check=True)
    report = {"base_sha256": BASE_SHA256, "image_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
              "size": output.stat().st_size, "changed_entries": changed,
              "preserved_entries": len(before) - len(set(before) & changed.keys()),
              "assembly": "pinned upstream executable with committed ramdisk overlay"}
    output.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--firmware-dir", type=Path, default=ROOT / "firmware-inputs")
    arguments = parser.parse_args()
    build(arguments.base, arguments.output, arguments.firmware_dir)
