# TWRP device tree for Nubia NX809J (RedMagic 11 Pro)

平台: Qualcomm **canoe / SM8850** (Snapdragon 8 Elite Gen 5) · Android **16** (API 36)

> 本设备树改造自 [YuKongA/twrp_device_xiaomi_sm8750_thales](https://github.com/YuKongA/twrp_device_xiaomi_sm8750_thales) (twrp-16.0)
> 所有配置值均取自**真机 adb/su 实测**，非照抄。详见 `CHANGES.md`。

## 设备事实 (实测)

| 项目 | 值 |
|---|---|
| 平台 | `canoe` / `SM8850` / QTI |
| bootloader | 已解锁，`verifiedbootstate=orange` |
| dm-verity | 主 vbmeta `flags=0x0001` (HASHTREE_DISABLED)，已关闭 |
| super 分区 | 19,327,352,832 B (18 GiB) |
| recovery 分区 | 104,857,600 B |
| 内核 | GKI `6.12.23-android16-5-ga82fc641d6d2-...-4k`，boot header v4 |
| 分区文件系统 | system/vendor 等为 **erofs**，userdata/metadata 为 **f2fs** |
| 加密 | metadata encryption `aes-256-xts:wrappedkey_v0` |
| 触摸 | Synaptics TCM (`syna_firmware.img`)，驱动 **built-in** |
| 触感 | **AWINIC aw86320** + swr_haptics（不是 Cirrus cs40l26） |
| KernelSU | 位于 `init_boot_b` 的 ramdisk（LKM 模式） |

## ⚠️ 本机特别注意

1. **`abl_b` 顶层 fastboot 没有 `flash:` 命令** —— 一切刷写必须走 **fastbootd** 或 root+dd
2. **`recovery` 是 CHAIN 分区**（主 vbmeta 里 `CHAIN_PARTITION -> recovery`）
   → 刷入的 `recovery.img` **必须含合法 AVB vbmeta**，否则 `INVALID_METADATA` 硬失败 → 反复进 fastboot
3. 拉取文件**不要用 `adb exec-out`**（会被 LF→CRLF 污染），用 `su -c base64` 或 `/sdcard` 中转

## Features

- [X] ADB
- [X] Decryption (FBE + metadata)
- [X] Display
- [X] Fastbootd ← 本机必需
- [X] Flashing
- [X] MTP
- [X] Sideload
- [X] USB-OTG
- [X] Vibrator (AWINIC)
- [X] WLAN

## Build

```bash
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
repo sync -c -j$(nproc)
# 本设备树放到 device/nubia/NX809J

export ALLOW_MISSING_DEPENDENCIES=true
. build/envsetup.sh
lunch twrp_NX809J-eng
mka recoveryimage -j$(nproc)
# 产物: out/target/product/NX809J/recovery.img
```

## 维护脚本

| 脚本 | 用途 |
|---|---|
| `extract_blobs.sh` | 从真机重新提取厂商 blob（base64 精确传输 + 自动清理 Xiaomi 残留） |
| `resolve_libs.sh` | 用 `readelf -d NEEDED` 解析 HAL 服务的依赖闭包并从真机补齐 |

## 刷入

```bash
fastboot reboot fastboot
fastboot flash recovery_b recovery.img
adb reboot recovery
```

## 回滚

```bash
adb shell "su -c 'dd of=/dev/block/by-name/recovery_b bs=1M'" < boot_backup_*/recovery_b.img
```
