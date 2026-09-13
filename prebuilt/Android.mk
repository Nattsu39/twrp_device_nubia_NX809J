#
# Copyright (C) 2025 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
    LOCAL_MODULE := prebuilt
    LOCAL_MODULE_TAGS := optional
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)
    # NX809J 用 AWINIC 触感方案, 不需要 Cirrus cs40l26 固件;
    # 触摸固件(syna_firmware.img)放在 recovery/root/firmware/ 由 recovery 直接带上。
    # 若以后需要往 /lib/firmware 放固件, 建 prebuilt/lib/firmware/ 后取消下面注释。
    #LOCAL_POST_INSTALL_CMD += \
    #    mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/lib/firmware; \
    #    cp -rf $(LOCAL_PATH)/lib/firmware/* $(TARGET_RECOVERY_ROOT_OUT)/lib/firmware/;
include $(BUILD_PHONY_PACKAGE)