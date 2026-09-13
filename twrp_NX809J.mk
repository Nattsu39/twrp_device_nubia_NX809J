#
# TWRP product makefile for Nubia NX809J (RedMagic 11 Pro)
#

DEVICE_PATH := device/nubia/NX809J

# Inherit from device.mk configuration
$(call inherit-product, $(DEVICE_PATH)/device.mk)

## Device identifier
PRODUCT_DEVICE := NX809J
PRODUCT_NAME := twrp_NX809J
PRODUCT_BRAND := nubia
PRODUCT_MANUFACTURER := nubia
PRODUCT_MODEL := NX809J

# Theme
TW_STATUS_ICONS_ALIGN := center
