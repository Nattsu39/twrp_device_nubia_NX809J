# NX809J validation — 2026-10-25

Validated configuration commit: `d7a9e62e854da297d8845e2a34f84759cbe90c44`.

Final 100 MiB recovery image SHA256:
`fd67da5368e1da1e1b54dc3e8d59b6f3ee6fcc1d43d698ded5d6025f488925e0`.

The image was assembled from the pinned upstream executable and this branch's
ramdisk configuration with the verified local firmware inputs. It is not a full
TWRP source rebuild. Only recovery_a was flashed through SuperFastboot.

Two separate recovery boots each passed 26 device checks without manual driver
loading or crypto service workarounds:

- The image digest and A slot match the deployment target.
- Synaptics touch registers automatically; the existing coordinate fix remains.
  The user previously verified coordinates, and requested no further screen test.
- Internal UFS disks are absent from OTG entries.
- qseecomd listeners, KeyMint and keystore initialize; metadata maps to userdata,
  /data mounts as f2fs, and TWRP reports all present users decrypted.
- Boot, init_boot, vendor_boot, DTBO, recovery and both AVB entries refer to the
  active slot and report the actual nonzero device size. VM persist is a raw entry.
- Boot, init_boot, vendor_boot, DTBO, vbmeta, vbmeta_system and recovery_b hashes
  remain identical to the pre-deployment baseline.

| TWRP entry | Reported capacity |
| --- | --- |
| Boot | 96 MiB |
| Init boot | 8 MiB |
| Vendor boot | 96 MiB |
| DTBO | 72 MiB |
| Recovery | 100 MiB |
| Vbmeta / Vbmeta system | 64 KiB each |
| VM persist raw backup | 230 MiB |

The older direct-v1 fstab candidate is superseded: it caused the boot HAL to
reject the shared fstab because it requires five fields. The final configuration
uses v2 rows and inline flags. The shipped twrp.flags overlay parser is avoided.
Ten host configuration regressions and the AOSP AVB hash verification pass.

After the second final-image recovery boot, Android started successfully with
boot_completed=1, slot A, 6.12.38-android16-OP-WILD, SELinux Enforcing and user 0
RUNNING_UNLOCKED. The device was left running Android.

Physical USB storage hotplug, full backup/restore, additional credential types
and other firmware/security-patch combinations are outside these results. No
format, wipe, slot change, credential change or encryption reset was performed.
Detailed private device logs and recovery/metadata backups remain in the local
project rather than this public repository.
