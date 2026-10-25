#!/system/bin/sh
# Initialize the current vendor_boot's touch stack without replacing modules.

if [ ! -d /sys/module/spi_msm_geni ]; then
    insmod /lib/modules/spi-msm-geni.ko || exit 1
fi

device=/sys/bus/platform/devices/synaptics_tcm.0
driver=/sys/bus/platform/drivers/synaptics_tcm
attempt=0
while [ "$attempt" -lt 50 ]; do
    if [ -e "$device/driver" ]; then
        exit 0
    fi
    if [ -d "$device" ] && [ -w "$driver/bind" ]; then
        echo synaptics_tcm.0 > "$driver/bind" || exit 1
        exit 0
    fi
    sleep 0.1
    attempt=$((attempt + 1))
done

echo "NX809J: Synaptics platform device did not appear" >&2
exit 1
