#!/bin/bash
# ============================================================================
# 从 NX809J 真机提取 TWRP 需要的厂商 blob
# 用法: bash extract_blobs.sh [设备树路径]   默认 device/nubia/NX809J
# 前置: adb 已授权 + 设备已 root (su 可用)
#
# ⚠️ 传输方式说明:
#    实测 `adb exec-out + dd/cat` 会被 LF->CRLF 污染(文件变大、sha256 不符)!
#    本脚本改用 `su -c base64` + 本地解码, 并逐文件比对大小, 保证字节精确。
# ============================================================================
set -u
DT="${1:-device/nubia/NX809J}"
[ -d "$DT" ] || { echo "找不到设备树: $DT"; exit 1; }
adb shell true 2>/dev/null || { echo "设备未连接/未授权"; exit 1; }

ROOT="$DT/recovery/root"
PULLED=0; MISSING=0; BADSIZE=0

dev_size() { adb shell "su -c 'stat -c %s \"$1\" 2>/dev/null'" 2>/dev/null | tr -d '\r\n'; }

pull() {  # pull <设备绝对路径> <设备树内相对路径>
  local src="$1" dst="$ROOT/$2" dsz lsz
  dsz=$(dev_size "$src")
  if [ -z "$dsz" ] || [ "$dsz" = "0" ]; then
    echo "  ❌ 缺失/不可读: $src"; MISSING=$((MISSING+1)); return 1
  fi
  mkdir -p "$(dirname "$dst")"
  if adb shell "su -c 'base64 \"$src\"'" 2>/dev/null | tr -d '\r\n' | base64 -d > "$dst" 2>/dev/null; then
    lsz=$(stat -c %s "$dst" 2>/dev/null || echo 0)
    if [ "$dsz" = "$lsz" ]; then
      echo "  ✅ $2 ($lsz bytes)"; PULLED=$((PULLED+1)); return 0
    else
      echo "  ⚠️  $2 大小不符 dev=$dsz local=$lsz"; BADSIZE=$((BADSIZE+1)); return 1
    fi
  else
    echo "  ❌ 读取失败: $src"; MISSING=$((MISSING+1)); return 1
  fi
}

dirtopull() {  # 整目录: 设备端 tar | base64 -> 本地解包
  local src="$1" dst="$ROOT/$2"
  mkdir -p "$(dirname "$dst")"
  if adb shell "su -c 'cd \"$(dirname "$src")\" && tar cf - \"$(basename "$src")\" | base64'" 2>/dev/null \
       | tr -d '\r\n' | base64 -d 2>/dev/null | tar xf - -C "$(dirname "$dst")" 2>/dev/null; then
    echo "  ✅ $2/ (目录)"; PULLED=$((PULLED+1)); return 0
  else
    echo "  ❌ 目录失败: $src"; MISSING=$((MISSING+1)); return 1
  fi
}

echo "=============================================="
echo " 1/7 厂商 HAL 服务  [NX809J 实际名称, 与参考树不同!]"
echo "=============================================="
for s in \
  android.hardware.boot-service.qti \
  android.hardware.gatekeeper-rust-service-qti \
  android.hardware.gatekeeper-service-spu-qti \
  android.hardware.health-service.qti \
  android.hardware.secure_element-service-aidl \
  android.hardware.security.keymint-service-spu-qti \
  android.hardware.security.onekeymint-service-qti \
  android.hardware.weaver-service-spu-qti \
  vendor.qti.hardware.vibrator.service ; do
  pull "/vendor/bin/hw/$s" "vendor/bin/hw/$s"
done
pull /vendor/bin/qseecomd vendor/bin/qseecomd
pull /vendor/bin/ssgtzd   vendor/bin/ssgtzd

echo
echo "=============================================="
echo " 2/7 HAL 的 init.rc"
echo "=============================================="
for rc in \
  android.hardware.boot-service.qti.rc \
  android.hardware.gatekeeper-service-qti.rc \
  android.hardware.health-service.qti.rc \
  android.hardware.secure_element-service.qti.rc \
  android.hardware.security.keymint-service-qti.rc \
  vendor.qti.hardware.vibrator.service.rc \
  qseecomd.rc ssgtzd.rc ; do
  pull "/vendor/etc/init/$rc" "vendor/etc/init/$rc"
done

echo
echo "=============================================="
echo " 3/7 VINTF manifest  [已按 NX809J 实际文件名修正]"
echo "=============================================="
for x in \
  android.hardware.gatekeeper-service-qti.xml \
  android.hardware.health-service.qti.xml \
  android.hardware.secure_element.xml \
  android.hardware.security.onekeymint-service-qti.xml \
  boot-service.qti.xml \
  vendor.qti.hardware.vibrator.service.xml \
  vendor.qti.syshealthmon-service.xml ; do
  pull "/vendor/etc/vintf/manifest/$x" "vendor/etc/vintf/manifest/$x"
done
pull /vendor/etc/vintf/compatibility_matrix.xml vendor/etc/vintf/compatibility_matrix.xml

echo
echo "=============================================="
echo " 4/7 触摸/振动固件  [NX809J: Synaptics TCM + AWINIC]"
echo "=============================================="
pull /vendor/firmware/syna_firmware.img firmware/syna_firmware.img
pull /vendor/etc/HapticsPolicy.xml      vendor/etc/HapticsPolicy.xml
pull /vendor/etc/Hapticsconfig.xml      vendor/etc/Hapticsconfig.xml
pull /vendor/lib64/libdev_haptics.so    vendor/lib64/libdev_haptics.so
dirtopull /vendor/etc/acdbdata/haptics_data vendor/etc/acdbdata/haptics_data

echo
echo "=============================================="
echo " 5/7 WiFi 配置 (peach_v2)"
echo "=============================================="
dirtopull /vendor/etc/wifi vendor/etc/wifi
dirtopull /vendor/firmware/wlan vendor/firmware/wlan 2>/dev/null || true

echo
echo "=============================================="
echo " 6/7 内核模块"
echo "=============================================="
for m in synaptics_tcm2.ko aw86320.ko swr_haptics_dlkm.ko qcom-hv-haptics.ko \
         cnss_prealloc.ko wlan_firmware_service.ko cnss_plat_ipc_qmi_svc.ko cnss_utils.ko \
         cnss_nl.ko cnss2.ko rfkill.ko cfg80211.ko adsp_loader_dlkm.ko rproc_qcom_common.ko \
         q6_dlkm.ko qcom_q6v5.ko qcom_q6v5_pas.ko qcom_sysmon.ko ; do
  pull "/vendor/lib/modules/$m"  "vendor/lib/modules/$m" || \
  pull "/vendor_dlkm/lib/modules/$m" "vendor/lib/modules/$m" || true
done

echo
echo "=============================================="
echo " 7/7 清理参考树里的 Xiaomi 专有文件"
echo "=============================================="
for f in \
  "recovery/root/odm/bin/hw/vendor.xiaomi.hardware.vibratorfeature.service" \
  "recovery/root/odm/lib64/libtensorflowlite_touch_c.so" \
  "recovery/root/odm/lib64/ese_weaver_thales.so" \
  "recovery/root/vendor/lib64/mi_weaver.so" \
  "recovery/root/vendor/lib64/vendor.xiaomi.hardware.aidl.mtdservice-V1-ndk_platform.so" \
  "recovery/root/vendor/lib64/vendor.xiaomi.hw.touchfeature-V1-ndk.so" \
  "recovery/root/vendor/lib64/vendor.hardware.vibratorfeature.IVibratorExt-V1-ndk_platform.so" \
  "recovery/root/odm/bin/init.kernel.post_boot-sun_default_6_2.sh" \
  "recovery/root/odm/bin/variant-script.sh" \
  "recovery/root/odm/bin/touch_report" \
  "recovery/root/odm/bin/prepdecrypt.sh" \
  "recovery/root/odm/etc/init/vendor.xiaomi.hardware.vibratorfeature.service.rc" \
  "recovery/root/odm/etc/init/variant-script.rc" \
  "recovery/root/odm/etc/init/touch_report.rc" \
  "recovery/root/odm/etc/init/init.kernel.post_boot-sun.rc" \
  "recovery/root/odm/etc/waveform_conf.xml" \
  "recovery/root/odm/etc/vintf/manifest/vendor.xiaomi.hardware.vibratorfeature.service.xml" \
  "recovery/root/odm/etc/ueventd.rc" \
  "recovery/root/vendor/etc/gpfspath_oem_config.xml" ; do
  [ -e "$DT/$f" ] && rm -rf "$DT/$f" && echo "  🗑  已删 $f"
done
rm -rf "$DT/recovery/root/odm/variant" 2>/dev/null && echo "  🗑  已删 odm/variant/ (Xiaomi 触摸机型)"
rm -f  "$DT/prebuilt/lib/firmware/"cs40l26* 2>/dev/null && echo "  🗑  已删 prebuilt/lib/firmware/cs40l26* (Cirrus, NX809J 用 AWINIC)"

echo
echo "=============================================="
printf " 完成: 成功 %d 项, 缺失 %d 项, 大小异常 %d 项\n" "$PULLED" "$MISSING" "$BADSIZE"
echo "=============================================="
