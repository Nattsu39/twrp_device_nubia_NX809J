"""Regression checks for the observed NX809J recovery failures."""

import json
import shlex
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def storage_patterns(fstab):
    return [line.split()[0] for line in fstab.splitlines()
            if line.strip() and not line.startswith("#") and "voldmanaged=" in line]


def twrp_matches(pattern, device):
    # Handle_Uevent in the shipped TWRP compares only this prefix.
    return device.startswith(pattern.split("*", 1)[0])


class RecoveryConfigurationTest(unittest.TestCase):
    def test_internal_ufs_never_matches_removable_storage(self):
        patterns = storage_patterns((ROOT / "recovery.fstab").read_text(encoding="utf-8"))
        for index, disk in enumerate("abcdef"):
            path = ("/devices/platform/soc/1d84000.ufshc/host0/"
                    f"target0:0:0/0:0:0:{index}/block/sd{disk}")
            for pattern in patterns:
                self.assertFalse(twrp_matches(pattern, path), (pattern, path))
                self.assertFalse(twrp_matches(pattern, path + f"/sd{disk}15"))

    def test_usb_controller_is_still_supported(self):
        # Representative USB storage child of the controller observed on device.
        path = ("/devices/platform/soc/a600000.ssusb/a600000.dwc3/"
                "xhci-hcd.0.auto/usb1/1-1/1-1:1.0/host1/target1:0:0/"
                "1:0:0:0/block/sdg")
        patterns = storage_patterns((ROOT / "recovery.fstab").read_text(encoding="utf-8"))
        self.assertTrue(any(twrp_matches(pattern, path) for pattern in patterns))

    def test_old_pattern_reproduces_internal_disk_bug(self):
        self.assertTrue(twrp_matches(
            "/devices/platform/soc/*.ssusb/*.dwc3/xhci-hcd.*.auto*",
            "/devices/platform/soc/1d84000.ufshc/host0/block/sda"))

    def test_missing_reference_partitions_are_removed(self):
        flags = (ROOT / "recovery/root/system/etc/twrp.flags").read_text(encoding="utf-8")
        for name in ("/mi_ext", "/cache", "/modemfirmware", "/rescue"):
            self.assertNotIn(name, flags)
        for line in flags.splitlines():
            if line.startswith(("/modem_image ", "/bluetooth_image ", "/dsp_image ")):
                self.assertIn("slotselect", line)

    def test_boot_entries_do_not_use_broken_flags_overlay(self):
        # The shipped LoadTwrpFlags incorrectly takes tokens[1] (filesystem)
        # as the block device. Inline v2 flags avoid that override and remain
        # compatible with the boot HAL, which also reads this same fstab.
        flags = (ROOT / "recovery/root/system/etc/twrp.flags").read_text(encoding="utf-8")
        self.assertFalse(any(line.startswith("/") for line in flags.splitlines()))
        lines = (ROOT / "recovery.fstab").read_text(encoding="utf-8").splitlines()
        rows = {shlex.split(line)[1]: shlex.split(line) for line in lines if line.startswith("/")}
        for name in ("boot", "init_boot", "vendor_boot", "dtbo", "recovery", "vbmeta", "vbmeta_system"):
            row = rows["/" + name]
            self.assertEqual(row[2], "emmc")
            self.assertEqual(row[0], "/dev/block/bootdevice/by-name/" + name)
            self.assertIn("slotselect", row[4])
            self.assertIn("backup=1", row[4])

    def test_all_rows_are_compatible_with_boot_hal_fstab_reader(self):
        for line in (ROOT / "recovery.fstab").read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                self.assertEqual(len(line.split()), 5, line)

    def test_vm_persist_is_raw_backup_not_ext4_mount(self):
        fstab = (ROOT / "recovery.fstab").read_text(encoding="utf-8")
        self.assertNotIn("/mnt/vendor/vm-persist", fstab)
        self.assertIn(" /vm_persist_image emmc ", fstab)

    def test_crypto_services_have_explicit_recovery_domain(self):
        for name in ("qseecomd", "android.hardware.security.onekeymint-service-qti",
                     "android.hardware.gatekeeper-service-qti"):
            rc = (ROOT / f"recovery/root/vendor/etc/init/{name}.rc").read_text(encoding="utf-8")
            self.assertIn("seclabel u:r:recovery:s0", rc)

    def test_vendor_property_set_leaves_room_for_runtime_properties(self):
        data = (ROOT / "recovery/root/vendor/build.prop").read_bytes()
        # The original 44,958-byte file added 678 vendor properties into the
        # single 128 KiB vendor_default_prop area and exhausted its allocator.
        self.assertLess(len(data), 4096)
        self.assertLess(len(data.splitlines()), 50)
        self.assertNotIn(b"metadata_init_delete_all_keys.enabled=true", data)

    def test_overlay_contains_all_declared_inputs(self):
        config = json.loads((ROOT / "ramdisk-overlay.json").read_text(encoding="utf-8"))
        for target, source in config["files"].items():
            self.assertTrue((ROOT / source).is_file(), target)
        self.assertIn("system/bin/init.nx809j-touch.sh", config["files"])
        self.assertEqual(config["properties"]["ro.build.version.security_patch"], "2026-09-01")


if __name__ == "__main__":
    unittest.main()
