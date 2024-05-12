#!/vendor/bin/sh
#
# Start indicated fingerprint HAL service
#
# Copyright (c) 2019 Lenovo
# All rights reserved.
#
# April 15, 2019  chengql2@lenovo.com  Initial version
# December 2, 2019  chengql2  Store fps_id into persist fs

script_name=${0##*/}
script_name=${script_name%.*}
function log {
    echo "$script_name: $*" > /dev/kmsg
}

persist_fps_id=/mnt/vendor/persist/fps/vendor_id
persist_fps_id2=/mnt/vendor/persist/fps/last_vendor_id
MAX_TIMES=30

if [ ! -f $persist_fps_id ]; then
    log "warn: no associated persist file found"
    return -1
fi
FPS_VENDOR_NONE=none
FPS_VENDOR_CHIPONE=chipone
#FPS_VENDOR_GOODIX=goodix
FPS_VENDOR_FOCAL=focal

prop_fps_status=vendor.hw.fingerprint.status
prop_persist_fps=persist.vendor.hardware.fingerprint

FPS_STATUS_NONE=none
FPS_STATUS_OK=ok

fps_vendor2=$(cat $persist_fps_id2)
if [ -z $fps_vendor2 ]; then
    fps_vendor2=$FPS_VENDOR_NONE
fi
log "FPS vendor (last): $fps_vendor2"
fps_vendor=$(cat $persist_fps_id)
if [ -z $fps_vendor ]; then
    fps_vendor=$FPS_VENDOR_NONE
fi
log "FPS vendor: $fps_vendor"

if [ $fps_vendor == $FPS_VENDOR_NONE ]; then
    log "warn: boot as the last FPS"
    fps=$fps_vendor2
else
    fps=$fps_vendor
fi

for i in $(seq 1 2)
do

setprop $prop_fps_status $FPS_STATUS_NONE
#if [ $fps == $FPS_VENDOR_GOODIX ]; then
#    log "start goodix hal"
#    start goodix_hal
if [ $fps == $FPS_VENDOR_FOCAL ]; then
    log "start focal hal"
    start focal_hal
else
    log "start fpsensor_hal"
    start chipone_fp_hal
fi

log "wait for HAL finish ..."
fps_status=$(getprop $prop_fps_status)
for ii in $(seq 1 $MAX_TIMES)
do
#    log "check fps vendor status: $fps_status"
    if [ $fps_status != $FPS_STATUS_NONE ]; then
        break
    fi
    sleep 0.2
    fps_status=$(getprop $prop_fps_status)
done
log "fingerprint HAL status: $fps_status"

if [ $fps_status == $FPS_STATUS_OK ]; then
    log "HAL success"
    setprop $prop_persist_fps $fps
    if [ $fps_vendor2 == $fps ]; then
        return 0
    fi
    log "- update FPS vendor (last)"
    echo $fps > $persist_fps_id2
    log "- done"
    return 0
fi

#    if [ $fps == $FPS_VENDOR_GOODIX ]; then
#	    stop goodix_hal
#        log "remove GOODIX driver"
#        rmmod goodix_mtk_tee
if [ $fps == $FPS_VENDOR_FOCAL ]; then
	stop focal_hal
        log "remove FOCAL driver"
        rmmod focal_fps
	sleep 0.5
        log "- install chipone driver"
        insmod /vendor/lib/modules/fpsensor_mtk_spi.ko
        fps=$FPS_VENDOR_CHIPONE
else
	stop chipone_fp_hal
        log "remove chipone driver"
        rmmod fpsensor_mtk_spi
	sleep 0.5
#        log "- install goodix driver"
#        insmod /vendor/lib/modules/goodix_mtk_tee.ko
#        fps=$FPS_VENDOR_GOODIX
        log "- install focal driver"
        insmod /vendor/lib/modules/focal_fps.ko
        fps=$FPS_VENDOR_FOCAL
fi
    log "- update FPS vendor"
    echo $fps > $persist_fps_id
    sleep 1

done
    log "error: HAL fail"
    setprop $prop_persist_fps $FPS_VENDOR_NONE
    echo $FPS_VENDOR_NONE > $persist_fps_id

    log "- done"
    return 1
