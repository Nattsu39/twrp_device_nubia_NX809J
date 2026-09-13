#
# TWRP BoardConfig for Nubia NX809J (RedMagic 11 Pro)
# 平台: Qualcomm "canoe" / SM8850 (Snapdragon 8 Elite Gen 5) / Android 16
#
# 改造自 YuKongA/twrp_device_xiaomi_sm8750_thales (twrp-16.0 分支)
# 标注 "[NX809J 实测]" 的值全部取自真机 adb/su 读取
#

# Building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Rules
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

# Bootloader   [NX809J 实测] ro.board.platform = canoe
PRODUCT_PLATFORM := canoe
TARGET_BOOTLOADER_BOARD_NAME := $(PRODUCT_PLATFORM)
TARGET_NO_BOOTLOADER := true

# Platform   [NX809J 实测] ro.soc.model = SM8850, ro.soc.manufacturer = QTI
TARGET_BOARD_PLATFORM := qcom_canoe
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
QCOM_BOARD_PLATFORMS += qcom_canoe

# Kernel   [NX809J 实测] boot 头 v4 / kernel_size=39889408 / pagesize=4096
BOARD_KERNEL_IMAGE_NAME       := Image
BOARD_BOOT_HEADER_VERSION     := 4
BOARD_KERNEL_PAGESIZE         := 4096
TARGET_KERNEL_CLANG_COMPILE   := true
TARGET_PREBUILT_KERNEL        := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS          += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS          += --pagesize $(BOARD_KERNEL_PAGESIZE)

# Ramdisk use lz4
BOARD_RAMDISK_USE_LZ4 := true

# A/B
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    odm \
    product \
    system \
    system_ext \
    system_dlkm \
    vendor \
    vendor_dlkm

# Verified Boot
BOARD_AVB_ENABLE := true

# Partitions
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# Workaround for error copying vendor files to recovery ramdisk
TARGET_COPY_OUT_VENDOR := vendor

TARGET_COPY_OUT_ODM := odm
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USES_VENDOR_DLKMIMAGE := true
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4

# Recovery 分区大小   [NX809J 实测] recovery_a = 104857600
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600

# Dynamic Partition   [NX809J 实测] super = 19327352832   ⚠️ 参考树是 11811160064, 必须改
BOARD_SUPER_PARTITION_SIZE := 19327352832
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := $(shell echo $$(($(BOARD_SUPER_PARTITION_SIZE) - 4194304)))
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor vendor_dlkm odm system_dlkm

# System as root
BOARD_ROOT_EXTRA_FOLDERS := firmware persist

# File systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Extras
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab

# Crypto (Android 16 FBE + metadata)
# [NX809J 实测] fstab: metadata_encryption=aes-256-xts:wrappedkey_v0
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_METADATA_PARTITION := true
TW_INCLUDE_OMAPI := true
TW_USE_FSCRYPT_POLICY := 2
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# Tool
TW_INCLUDE_7ZA := true
TW_INCLUDE_ZSTD := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_ENABLE_ALL_PARTITION_TOOLS := true

# Debug
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
TARGET_RECOVERY_DEVICE_MODULES += strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace
TARGET_RECOVERY_DEVICE_MODULES += prebuilt

# Fastbootd   ⚠️ NX809J 必开: abl_b 顶层 fastboot 没有 flash: 命令, 只能靠 fastbootd
TW_INCLUDE_FASTBOOTD := true

# Wi-Fi
TW_INCLUDE_WIFI := true

# Other TWRP Configurations
TW_THEME := portrait_hdpi
TW_FRAMERATE := 120
RECOVERY_SDCARD_ON_DATA := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_INCLUDE_NTFS_3G := true
TW_USE_DMCTL := true
TW_USE_TOOLBOX := true
TARGET_USES_MKE2FS := true
TW_EXTRA_LANGUAGES := true
TW_EXCLUDE_APEX := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true

# 亮度   [NX809J 实测] /sys/class/backlight/panel0-backlight
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 250

# 输入设备黑名单  [NX809J 实测] 无 hbtp_vm 设备; 触摸是 synaptics_tcm_touch
TW_INPUT_BLACKLIST := ""

# 震动/触感  [NX809J 实测] AWINIC aw86320 + swr_haptics, 没有 Xiaomi vibratorfeature
TW_SUPPORT_INPUT_AIDL_HAPTICS := false
TW_SUPPORT_INPUT_AIDL_HAPTICS_FIX_OFF := false

# CPU 温度  [NX809J 实测] cpu-0-0-0 在 thermal_zone5   ⚠️ 参考树是 zone1
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone5/temp"

# 厂商内核模块  [NX809J 实测] 位于 /vendor/lib/modules
# 注意: 触摸驱动(synaptics)与 rfkill 是 built-in/system_dlkm, 不在列表里
#       qcom-hv-haptics.ko 在 NX809J 上叫 haptic_86938.ko
TW_LOAD_VENDOR_MODULES := "aw86320.ko haptic_86938.ko swr_haptics_dlkm.ko cnss_prealloc.ko wlan_firmware_service.ko cnss_plat_ipc_qmi_svc.ko cnss_utils.ko cnss_nl.ko cnss2.ko qca_cld3_peach_v2.ko cfg80211.ko adsp_loader_dlkm.ko rproc_qcom_common.ko q6_dlkm.ko qcom_q6v5.ko qcom_q6v5_pas.ko qcom_sysmon.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_PREBUILT_MODULES_AT_FIRST := true

# 备份排除: 别把 KernelSU / LSPosed / 模块 数据打进备份
TW_BACKUP_EXCLUSIONS := /data/fonts,/data/adb/ap,/data/adb/ksu,/data/adb/lspd,/data/adb/modules,/data/adb/tricky_store
