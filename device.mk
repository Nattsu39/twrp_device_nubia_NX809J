#
# Copyright (C) 2025 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Configure base.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Configure core_64_bit_only.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# Configure virtual_ab_ota compression_with_xor.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression_with_xor.mk)

# Configure emulated_storage.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Configure twrp config common.mk
$(call inherit-product, vendor/twrp/config/common.mk)

# API  [NX809J 实测] Android 16 = API 36
BOARD_SHIPPING_API_LEVEL := 36
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_TARGET_VNDK_VERSION := 36

# 16KB 页对齐检查
# API 36(bp2a) 默认 TARGET_CHECK_PREBUILT_MAX_PAGE_SIZE := true，会给每个
# prebuilt ELF 加上 --max-page-size=16384（见 build/make/core/config.mk:812）。
# TWRP 自带的 bootable/recovery/prebuilt/dhcpcd 是 4KB 对齐的旧二进制，于是
# check_elf_files 在 91% 处报错：
#   bootable/recovery/prebuilt/dhcpcd: error: Load segment has alignment 4096 but 16384 required.
# NX809J 实测 getconf PAGE_SIZE = 4096，本机是 4KB 页设备，该检查属于误报。
# 显式置 false 后 --max-page-size 参数变空（check_elf_file.mk:53），ELF 合法性仍会校验。
PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false

# Dynamic partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Enable Fuse Passthrough
PRODUCT_PROPERTY_OVERRIDES += persist.sys.fuse.passthrough.enable=true

# Otacert
PRODUCT_EXTRA_RECOVERY_KEYS += \
    $(DEVICE_PATH)/security/releasekey

# Required modules
TWRP_REQUIRED_MODULES += \
    prebuilt

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)
