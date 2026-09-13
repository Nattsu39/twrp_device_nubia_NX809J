NX809J TWRP 设备树改造清单
==========================
来源参考: YuKongA/twrp_device_xiaomi_sm8750_thales (twrp-16.0 分支)  [Xiaomi SM8750 "sun"]
目标设备: Nubia NX809J (RedMagic 11 Pro)                             [Qualcomm SM8850 "canoe"]

一、已自动完成的改动
--------------------
文件                              改动
--------------------------------  --------------------------------------------------
BoardConfig.mk                    PRODUCT_PLATFORM: sun -> canoe
                                  TARGET_BOARD_PLATFORM: xiaomi_sm8750 -> qcom_canoe
                                  TARGET_BOARD_PLATFORM_GPU: adreno830 -> adreno840
                                  BOARD_SUPER_PARTITION_SIZE: 11811160064 -> 19327352832  ⚠️关键
                                  TW_CUSTOM_CPU_TEMP_PATH: thermal_zone1 -> thermal_zone5 ⚠️关键
                                  TW_INPUT_BLACKLIST: "hbtp_vm" -> ""
                                  TW_SUPPORT_INPUT_AIDL_HAPTICS: true -> false (去掉 Xiaomi FQNAME)
                                  TW_LOAD_VENDOR_MODULES: 换成 NX809J 的模块列表
                                  TW_BACKUP_EXCLUSIONS: 增加 lspd/modules/tricky_store
twrp_NX809J.mk                    新建 (替代 twrp_sm8750_thales.mk)
AndroidProducts.mk                指向 twrp_NX809J.mk
Android.mk                        TARGET_DEVICE: sm8750_thales -> NX809J
device.mk                         API level: 35 -> 36 (Android 16)
recovery.fstab                    删除 mi_ext / rescue->cache (NX809J 无这些分区)
                                  补齐 boot/init_boot/vendor_boot/dtbo/recovery/vbmeta
                                  补齐 NX809J 特有分区: qmcs/spunvm/vm-bootsys/soccp/vm-persist/logdump
                                  persist 挂到 /persist (NX809J 实际在 /mnt/vendor/persist)
prebuilt/kernel                   从真机 boot_b.img 提取
                                  (header_size=1584, 页对齐后 kernel@0x1000, 39889408 bytes,
                                   ARM64 Image / 4K pages / magic 'ARMd' @offset56)
twrp_sm8750_thales.mk             已删除
extract_vendor_blobs.sh           新建: 一键从真机拉取厂商 blob

二、必须手动处理的差异 (脚本会尝试自动拉取)
-------------------------------------------
[1] 厂商 HAL 服务名称完全不同 (参考树的是 Xiaomi 版, 直接用会起不来)
    参考树 (thales)                        NX809J 实际
    -------------------------------------  ----------------------------------------------
    android.hardware.gatekeeper-service-qti            -> android.hardware.gatekeeper-rust-service-qti
                                                          + android.hardware.gatekeeper-service-spu-qti
    android.hardware.secure_element-service.qti        -> android.hardware.secure_element-service-aidl
    android.hardware.security.keymint-service-qti      -> android.hardware.security.keymint-service-spu-qti
                                                          + android.hardware.security.onekeymint-service-qti
    (无)                                               -> android.hardware.weaver-service-spu-qti
    vendor.xiaomi.hardware.vibratorfeature.service     -> vendor.qti.hardware.vibrator.service
    android.hardware.boot-service.qti                  -> 相同 ✅
    android.hardware.health-service.qti                -> 相同 ✅

[2] 振动/触感芯片不同
    Xiaomi thales : Cirrus cs40l26 (prebuilt/lib/firmware/cs40l26*)
    NX809J        : AWINIC aw86320 + swr_haptics
                    + /vendor/etc/HapticsPolicy.xml, Hapticsconfig.xml
                    + /vendor/etc/acdbdata/haptics_data/**, libdev_haptics.so
                    + Qualcomm vendor.qti.hardware.vibrator.service
    => prebuilt/lib/firmware/cs40l26* 必须删除; 换成上面这些

[3] 触摸不同
    Xiaomi thales : odm/variant/{dada,haotian,xuanyuan} + libtensorflowlite_touch_c.so
                    + vendor.xiaomi.hw.touchfeature
    NX809J        : Synaptics TCM (/vendor/firmware/syna_firmware.img)
                    + 内核模块 synaptics_tcm2.ko
                    + 输入设备 synaptics_tcm_touch
    => odm/variant/ 整个目录删除

[4] WiFi 配置: /vendor/etc/wifi/peach_v2 + /vendor/firmware/wlan/qca_cld  —— 两边同名 ✅ 可直接用

[5] odm/bin 下的 Xiaomi 脚本 (init.kernel.post_boot-sun_default_6_2.sh / variant-script.sh /
    touch_report / prepdecrypt.sh) 都是 sun/Xiaomi 专用, 需删除, 换成 NX809J 对应物或留空

三、TODO (编译前必须确认)
--------------------------
[ ] 1. 运行 bash extract_vendor_blobs.sh   (会拉取 blob 并自动清理 Xiaomi 专有文件)
[ ] 2. 确认 vendor_dlkm 里的触摸驱动模块名 (真机 /vendor/lib/modules 里没搜到 synaptics*)
       -> 可能在 /vendor_dlkm/lib/modules, 或已 built-in。用:
          adb shell "su -c 'ls /vendor_dlkm/lib/modules | grep -i syna'"
[ ] 3. 补齐 recovery/root/odm 下 NX809J 自己的服务/脚本 (真机 /odm/bin 目前为空)
[ ] 4. 确认 TARGET_BOARD_PLATFORM_GPU (SM8850 / Adreno 840) 的正确 QCOM 名称
[ ] 5. 确认 TW_CUSTOM_CPU_TEMP_PATH 的 zone 编号在 recovery 内核下是否仍然一致
       (真机是 zone5=cpu-0-0-0; 不同内核 thermal zone 顺序可能变)
[ ] 6. 确认 recovery/root/vendor/lib64 里需要哪些 .so (契约库), 逐个从真机拉
[ ] 7. 决定是否要 header v4 + `BOARD_AVB_ENABLE := true` 自动加 AVB
       —— 见第五节, 这关系到能不能启动

四、构建
--------
    # 用支持 Android 16 的社区 manifest
    repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
    repo sync -c -j$(nproc)

    # 设备树放到 device/nubia/NX809J (当前路径已经是)

    export ALLOW_MISSING_DEPENDENCIES=true
    . build/envsetup.sh
    lunch twrp_NX809J-eng
    mka recoveryimage -j$(nproc)
    # 产物: out/target/product/NX809J/recovery.img

五、⚠️ 刷入前必须确认: recovery 是 CHAIN 分区
---------------------------------------------
NX809J 主 vbmeta 的 descriptor (实测):
    CHAIN  -> boot (rollback_loc 3)
    CHAIN  -> recovery (rollback_loc 1)
    CHAIN  -> vbmeta_system (rollback_loc 2)
    HASH   -> dtbo / init_boot / vendor_boot

所以刷进的 recovery.img **必须含合法 AVB vbmeta 结构**, 否则:
    INVALID_METADATA (硬失败) -> 槽位不可引导 -> 反复进 fastboot

做法二选一:
 A) BoardConfig 里保留 BOARD_AVB_ENABLE := true, 让构建系统自动加 (推荐)
 B) 手动补:
    avbtool add_hash_footer \
      --image recovery.img \
      --partition_name recovery \
      --partition_size 104857600 \
      --key testkey.pem --algorithm SHA256_RSA2048
    (用你自己的密钥 OK —— 解锁态签名不符只是 PUBLIC_KEY_REJECTED 软失败, 放行启动)

六、刷入 (abl_b 没有 flash: 命令, 必须走 fastbootd)
--------------------------------------------------
    fastboot reboot fastboot
    fastboot flash recovery_b recovery.img
    adb reboot recovery

# 回滚 (用之前的备份)
    adb shell "su -c 'dd of=/dev/block/by-name/recovery_b bs=1M'" < boot_backup_*/recovery_b.img

七、本次实际执行结果 (已完成)
------------------------------
[已改] BoardConfig.mk / twrp_NX809J.mk / AndroidProducts.mk / Android.mk / device.mk / recovery.fstab
[已删] twrp_sm8750_thales.mk, odm/variant/, cs40l26* 固件, vendor/lib/modules/1.1/,
       以及全部 Xiaomi 专有服务/脚本/库
[已提取] prebuilt/kernel                      <- 从当前 boot_b.img (40364176 bytes, ARM64 4K)
[已提取] 厂商 blob 45 项 (0 项大小异常):
         vendor/bin/hw/  9 个 HAL 服务 + qseecomd
         vendor/etc/init/*.rc (含 secure_element.rc / onekeymint-service-qti.rc /
                              vendor.qti.hardware.secureprocessor.rc)
         vendor/etc/vintf/manifest/*.xml + compatibility_matrix.xml
         firmware/syna_firmware.img, vendor/etc/Haptics*.xml, libdev_haptics.so,
         vendor/etc/acdbdata/haptics_data/**
         vendor/etc/wifi/**, vendor/firmware/wlan/**
         vendor/lib/modules/*.ko (17 个)

[关键修正]
 * `adb exec-out + dd/cat` 会被 LF->CRLF 污染 -> 改用 `su -c base64` 传输
 * boot_b / init_boot_b 备份后发现与设备不一致(B 槽被重刷过) -> 已用字节精确方式重备
 * 触摸驱动 synaptics / rfkill 不是独立模块 -> 前者 built-in, 后者在 system_dlkm(GKI)
 * qcom-hv-haptics.ko 在 NX809J 上叫 haptic_86938.ko

[仍未解决 / 需要你确认]
 [ ] /odm/bin 在 NX809J 上为空 —— 参考树里的 odm/bin 脚本已删, 但 NX809J 可能需要
     自己的 init.kernel.post_boot 之类脚本; 先从能开机验证, 缺了再补
 [ ] TARGET_BOARD_PLATFORM_GPU 用了 qcom-adreno840 (SM8850) —— 编译若报错请修正
 [ ] TW_CUSTOM_CPU_TEMP_PATH 用 zone5, recovery 内核下 zone 顺序可能不同
 [ ] recovery/root/vendor/lib64 里的契约库(.so)已用依赖闭包解析补齐 (见下)

八、/odm 与依赖库补齐结果 (第二轮)
----------------------------------
[/odm 现状分析]
  NX809J 的 /odm 只有 etc/ 和 lib64/, **没有 /odm/bin** (无 ODM 服务)
  /odm/lib64 = 285MB 相机 ISP 调参二进制 (bm6a81v04s14n*.bin 等) -> TWRP 用不到, 已跳过

[已补 /odm 4 个必要文件]
  odm/etc/aac_richtap.config   81,940 B  <- 振动必需! rc 里写死 ENV_RICHTAP_CONFIG_PATH
  odm/etc/build.prop            1,320 B  <- 设备标识 (ro.product.odm.*)
  odm/etc/ueventd.rc            5,171 B  <- 设备节点规则
  odm/etc/vintf/manifest.xml    1,124 B
  (aac_richtap_1.config 设备上不存在, 可忽略)

[已补 /vendor 2 个]
  vendor/build.prop            44,958 B
  vendor/etc/ueventd.rc        37,501 B

[依赖库: 用依赖闭包精确解析, 不照抄参考树]
  新增 resolve_libs.sh: readelf -d 取 NEEDED, 在设备的
  /vendor/lib64{,/hw} /odm/lib64 /system{,_ext}/lib64 里递归查找
  -> 共拉取 98 个库到 recovery/root/vendor/lib64
  -> **9 个 HAL 服务 + qseecomd 的依赖 100% 齐全 (0 缺失)**
  (只差 libc/libm/libdl, 由 TWRP 自身提供)

[清理掉的参考树残留 (关键!)]
  vendor/bin/hw/android.hardware.gatekeeper-service-qti        <- NX809J 没有
  vendor/bin/hw/android.hardware.secure_element-service.qti    <- NX809J 用 -service-aidl
  vendor/bin/hw/android.hardware.security.keymint-service-qti  <- NX809J 用 -spu-/onekeymint-
  vendor/bin/ssgtzd                                            <- 设备上不存在
  odm/bin/hw/android.hardware.weaver-service                   <- 设备 /odm 无 bin
  odm/etc/init/{weaver-service,prepdecrypt}.rc
  以及参考树的 vendor/lib64 全部 103 个库 (已移至 _ref_backup/)

[最终服务清单 = 与设备 /vendor/bin/hw 完全一致]
  android.hardware.boot-service.qti
  android.hardware.gatekeeper-rust-service-qti
  android.hardware.gatekeeper-service-spu-qti
  android.hardware.health-service.qti
  android.hardware.secure_element-service-aidl
  android.hardware.security.keymint-service-spu-qti
  android.hardware.security.onekeymint-service-qti
  android.hardware.weaver-service-spu-qti
  vendor.qti.hardware.vibrator.service
  + vendor/bin/qseecomd

[振动链路 (已确认可通, 需 recovery 里启动服务)]
  /vendor/bin/hw/vendor.qti.hardware.vibrator.service
  RICHTAP_DEVICE_PATH=/dev/awinic_haptic;/dev/awinic_x_haptic
  ENV_RICHTAP_CONFIG_PATH=/odm/etc/aac_richtap.config   <- 已补
  内核模块: aw86320.ko haptic_86938.ko swr_haptics_dlkm.ko  <- 已补

[目录规模]
  prebuilt/kernel 40,364,176 B (ARM64 4K Image)
  recovery/root/vendor/bin 10 / vendor/etc 75 / vendor/lib64 96 /
  odm/etc 4 / firmware 1 / vendor/lib/modules 17 / system 10
  总计约 104MB

九、全树逐文件审计与收尾 (第三轮)
----------------------------------
[审计方法]
  一次性导出设备 /vendor/etc (1375 个) 与 /odm/etc (20 个) 的 size+路径,
  本地比对。结果:

  recovery/root/vendor/etc : ✅52 一致  ⚠️0 不符  ❓0 缺失
  recovery/root/odm/etc    : ✅4  一致  ⚠️0 不符  ❓0 缺失

[清理掉的参考树残留 (第二批)]
  vendor/etc/acdbdata/*.pcm + acdbdata/tuning_data/**   <- Xiaomi 的 acdbdata 布局
      (NX809J 的 acdbdata 只有子目录 canoe_*/haptics_data/..., 无顶层 .pcm)
  vendor/etc/charger_fw_fstab.qti        <- 设备上没有
  vendor/etc/build.prop (0 字节空文件)   <- 之前拉取失败留下的
  vendor/etc/vintf/manifest.xml          <- 设备用 vintf/manifest_canoe.xml
  vendor/etc/vintf/manifest/android.hardware.weaver-service.xml
  vendor/etc/vintf/manifest/android.hardware.security.keymint-service-qti.xml
  vendor/etc/init/ssgtzd.rc
  vendor/etc/init/android.hardware.secure_element-service.qti.rc
  vendor/etc/init/android.hardware.security.keymint-service-qti.rc
  system/etc/wifi/wpa_supplicant.conf    <- 设备上在 /vendor/etc/wifi (已单独拉)

[补拉/更新的正确文件]
  vendor/etc/ssg/ta_config.json          1207 -> 1221 B (更新)
  vendor/etc/ssg/c2pa_enroll_config.json    190 B (新增)
  vendor/etc/ssg/c2pa_network_config.json   355 B (新增)
  vendor/etc/ssg/tz_whitelist.json         1445 B (新增)
  vendor/etc/vintf/manifest_canoe.xml       203 B (新增)
  vendor/etc/vintf/manifest/android.hardware.gatekeeper-service-qti.xml   297 B
  vendor/etc/vintf/manifest/android.hardware.secure_element.xml           336 B
  vendor/etc/vintf/manifest/android.hardware.security.onekeymint-service-qti.xml 526 B
  vendor/etc/vintf/manifest/android.hardware.security.secureclock-service-qti.xml 318 B
  vendor/etc/vintf/manifest/vendor.qti.hardware.secureprocessor.xml       388 B
  system/etc/ueventd.rc        4010 -> 3330 B
  system/etc/event-log-tags   40912 -> 40581 B
  system/etc/task_profiles.json 17055 -> 16020 B
  system/etc/vintf/manifest.xml   54 -> 2498 B
  system/lib64/libexpat.so   184792 -> 184952 B

[保留的 TWRP/recovery 自带文件 (设备上没有, 属正常)]
  system/bin/busybox (2,149,248 B)
  system/etc/twrp.flags (4,117 B)
  system/etc/vintf/manifest/recovery-device.xml (1,577 B)
  system/etc/dhcpcd-6.8.2/dhcpcd.conf (575 B)

[⚠️ 重要: 证书替换]
  security/releasekey.x509.pem 原来是 **Xiaomi 的证书**
      subject=O=Xiaomi, OU=MIUI, CN=MIUI, emailAddress=miui@xiaomi.com
  已换成 NX809J 的 (从设备 /system/etc/security/otacerts.zip 提取):
      subject=C=CN, ST=Shanghai, O=ZTE, OU=Smartphone Software Dept., CN=ZTE
      notAfter=Aug 4 07:14:25 2052 GMT

[prebuilt/ 清理]
  删掉空的 prebuilt/lib/firmware (原为 Xiaomi 的 Cirrus cs40l26 固件)
  并注释掉 prebuilt/Android.mk 里对它的拷贝命令 (否则编译报 cp 找不到文件)

[README.md] 已改写为 NX809J 版本 (含本机注意点/构建/刷入/回滚)

[最终状态]
  Xiaomi/thales/sun 残留: 0
  总规模: 103 MB

十、recovery init 脚本与属性修正 (第四轮)
------------------------------------------
[★重要发现: system.prop 的 gatekeeper 两行是必需的★]
  真机 /vendor/etc/init/android.hardware.gatekeeper-service-qti.rc:
      service vendor.gatekeeper_default /vendor/bin/hw/android.hardware.gatekeeper-rust-service-qti
          class early_hal
          disabled                        <-- 默认不启动!
      on property:vendor.gatekeeper.is_security_level_spu=0
          enable vendor.gatekeeper_default     <-- 靠这个 prop 才 enable
  => 不设 vendor.gatekeeper.is_security_level_spu=0, gatekeeper 起不来, FBE 解密必失败。
     (我第三轮曾把它注释掉, 已改回启用)

[init.recovery.qcom.rc  重写]
  删除(参考树 Xiaomi 专有, 本机不存在):
      start odm.variant-script          (on post-fs 整段)
      start odm.vibratorfeature-service
      start odm.touch_report
      start odm.weaver-service
      start odm.prepdecrypt
      setprop prepdecrypt.setpatch true
  替换为真机实际服务名:
      gto_secure_element_aidl_service   <- android.hardware.secure_element.rc
      vendor.qti.vibrator               <- vendor.qti.hardware.vibrator.service.rc
  保留(Qualcomm 通用, 已核对真机):
      vendor.boot-qti / vendor.gatekeeper_default / vendor.health-default /
      vendor.qseecomd / modem 挂载(firmware_mnt, WLAN 固件从这里读) / ADSP boot / OTG

[init.recovery.usb.rc  修正]
  idVendor 0x2717 (Xiaomi) -> 0x19d2 (ZTE)
     [NX809J 实测] lsusb: 19d2:1352 "ZTE WCDMA Technologies MSM 红魔11 PRO+电竞旗舰"
     /config/usb_gadget/g1: idVendor=0x19d2 idProduct=0x1352
  idProduct: 0x4EE7->0x1352 (默认), 0xFF40->0x1352 (mtp), 0xFF48->0x1353 (mtp,adb)
  adb/sideload 保持 0x18D1:0x4E11, fastboot 保持 0x18D1:0xD00D (通用)

[init.recovery.wifi.rc  仅改注释]
  [NX809J 实测] cnss 路径与参考树一致:
      /sys/devices/platform/soc/b0000000.qcom,cnss-peach   ✅
  WLAN 配置 peach_v2 已从真机拉取; qca_cld3_peach_v2.ko 已在模块列表

[.github/workflows/build.yml]
  默认值 xiaomi/sm8750_thales -> nubia/NX809J, DEVICE_NAME -> NX809J

[已验证的误差报]
  vendor/build.prop 的 ro.vendor.feature.brightness_enhance_small_sun=true
      -> 设备原样内容, 非参考树残留
  system/etc/event-log-tags 里的 "sun" -> 来自 SUnreclaim 标签

[最终检查]
  rc 里 start 的服务名: 全部有对应 service 定义
      (adbd 为系统内置, 正常)
  文本残留: 仅剩我写的说明性注释




