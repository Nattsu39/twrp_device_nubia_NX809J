# NX809J Avium recovery integration

This branch targets the installed Avium Android 16 firmware: system security
patch 2026-09-01, vendor security patch 2026-03-01, and the compatible
6.12.38-android16-OP-WILD kernel in boot. It does not replace that kernel.

The deployed image and device results are recorded in [VALIDATION.md](VALIDATION.md).

## Changes

* Load the matching `spi-msm-geni` module from vendor_boot and bind the Synaptics
  platform device if its probe did not bind automatically.
* Restrict removable storage matching to the observed `a600000.ssusb` controller.
  The shipped TWRP matches the prefix before the first wildcard, so the upstream
  `/devices/platform/soc/*` prefix also selected internal UFS partitions.
* Remove Xiaomi-only partition entries and fix slot selection for firmware image
  backups. USB storage remains configured; physical OTG testing is separate.
* Define raw boot/firmware backups directly in recovery.fstab. The shipped
  twrp.flags parser incorrectly overrides v2 block paths with filesystem names,
  leaving Boot and Recovery at zero bytes. Keep the flags overlay empty and use
  inline v2 flags, retaining five fields for the boot HAL's shared fstab reader.
  Treat the unformatted VM persist volume
  as an optional raw backup rather than an ext4 filesystem to auto-mount.
* Give crypto services an explicit recovery SELinux domain and start KeyMint
  after the Qualcomm listeners are ready. Include the listeners loaded with
  `dlopen`, which the original DT_NEEDED-only extraction missed.
* Use the installed firmware's KeyMint binary and a small vendor property set.
  The original stock property dump exhausted the 128 KiB vendor default property
  area, preventing the listeners' readiness flag from being published.
* Use the target ROM's version and patch levels instead of future values, and
  keep keystore failures in recovery for diagnosis instead of rebooting to the
  bootloader. No formatting or encryption reset is part of the repair.

## Reproducible ramdisk assembly

The integration artifact uses the known upstream executable, including its
existing touch coordinate fix. It is a ramdisk assembly, **not a full rebuild of
TWRP**. The complete overlay is declared in `ramdisk-overlay.json`; other archive
entries retain their content, permissions, ownership and symlink targets.

Download the upstream image from release `2026-09-13-34755052873`:

https://github.com/zxdzxv/twrp_device_nubia_NX809J/releases/tag/2026-09-13-34755052873

Its required SHA256 is
`a55684ef0362b08f6776a5ff5fdf343976a7c7b58a6ccb883e67e11beeb35307`.
An image from another release is rejected even if its filename matches.

```sh
python -m pip install -r tools/requirements.txt
python tools/test_recovery_config.py
python tools/repack_recovery.py /path/to/upstream.img out/r1/recovery.img
```

Before assembly, supply the firmware files listed in `crypto-blobs.json` under
the ignored `firmware-inputs/` directory, retaining their `vendor/...` paths.
Extract these from the matching vendor image using a read-only mount. The
assembler verifies every input hash and refuses mismatches. `--firmware-dir`
can select another local input directory. These newly extracted proprietary
files are not published in this fork; the upstream files retain their original
history. An assembly needs both the public source and these local inputs.

The output must be named `recovery.img` for AVB descriptor verification. Use a
new output directory for each candidate. The assembler verifies the source hash,
CPIO and compression roundtrips, unchanged entries, partition size and AVB hash.
It writes a JSON report beside the image. `tools/avbtool.py` is unmodified AOSP
source from `platform/external/avb`, tag `android-16.0.0_r1`, SHA256
`e5a664a38db623da00f080219bc0ee60a640a9dc4a872803616fae4938ac749b`.

The original full-source workflow remains an upstream reference. Its mutable
manifest and inline coordinate patch are not the source of this integration
artifact. Do not claim a full source build from an assembly result.

## Device validation and deployment

Only the installed SuperFastboot is authorized for flashing this device. Verify
the product, active slot, partition capacity, candidate hash and rollback image
immediately before writing `recovery_a`. Never change slots based on a README
example. This device's B slot was not bootable during initial checks.

Cold-boot acceptance requires automatic touch device registration, no internal
UFS devices under OTG, working crypto listeners/KeyMint/keystore, successful
metadata mapping and `/data` mount, and a successful return to Android. The
earlier user-confirmed touch position does not prove cold-start initialization.
Do not format userdata or metadata to make a decryption test pass.

No personal data, lockscreen credential, metadata backup, RPMB data or private
key belongs in this repository. Locally supplied additions in `crypto-blobs.json` are
firmware executables, libraries and configuration from a read-only vendor mount.
