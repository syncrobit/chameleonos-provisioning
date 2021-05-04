#!/bin/sh

set -e

FINAL_OS_BASE_URL="https://syncrobit-firmware.us-east-1.linodeobjects.com"
FINAL_OS_LATEST_STABLE_URL="${FINAL_OS_BASE_URL}/cham/latest_stable.json"
FINAL_OS_LATEST_URL="${FINAL_OS_BASE_URL}/cham/latest.json"

export TARGET="$1"
export BOARD=$(basename $(dirname ${TARGET}))
export COMMON_DIR=$(dirname $0)
export BOARD_DIR=${COMMON_DIR}/../${BOARD}
export BOOT_DIR=${TARGET}/../images/boot/
export IMG_DIR=${TARGET}/../images
export DL_DIR=$(realpath ${TARGET}/../../../dl)

mkdir -p ${BOOT_DIR}

if [ -x ${BOARD_DIR}/postscript.sh ]; then
    ${BOARD_DIR}/postscript.sh
fi

# cleanups
${COMMON_DIR}/cleanups.sh
if [ -x ${BOARD_DIR}/cleanups.sh ]; then
    ${BOARD_DIR}/cleanups.sh
fi

# transform /var contents as needed
rm -rf ${TARGET}/var/cache
rm -rf ${TARGET}/var/lib
rm -rf ${TARGET}/var/lock
rm -rf ${TARGET}/var/log
rm -rf ${TARGET}/var/run
rm -rf ${TARGET}/var/spool
rm -rf ${TARGET}/var/tmp

ln -s /tmp ${TARGET}/var/cache
ln -s /tmp ${TARGET}/var/lock
ln -s /tmp ${TARGET}/var/run
ln -s /tmp ${TARGET}/var/spool
ln -s /tmp ${TARGET}/var/tmp
ln -s /tmp ${TARGET}/run
mkdir -p ${TARGET}/var/lib
mkdir -p ${TARGET}/var/log

# board-specific os.conf
if [ -r ${BOARD_DIR}/os.conf ]; then
    for line in $(cat ${BOARD_DIR}/os.conf); do
        key=$(echo ${line} | cut -d '=' -f 1)
        sed -i -r "s/${key}=.*/${line}/" /${TARGET}/etc/os.conf
    done
fi

# add admin user alias
if ! grep -qE '^admin:' ${TARGET}/etc/passwd; then
    echo "admin:x:0:0:root:/root:/bin/sh" >> ${TARGET}/etc/passwd
fi

# embed final OS
if [ -n "${CHPR_LATEST_BETA}" ]; then
    latest_url=${FINAL_OS_LATEST_URL}
else
    latest_url=${FINAL_OS_LATEST_STABLE_URL}
fi
latest_info=$(curl -sSL ${latest_url})
latest_path=$(echo "${latest_info}" | jq -r .path)
final_os_url="${FINAL_OS_BASE_URL}${latest_path}"
final_os_filename=$(basename ${latest_path})
final_os_filepath=${DL_DIR}/${final_os_filename}
echo "embedding final OS ${final_os_filename}"
if ! [ -s ${final_os_filepath} ]; then
    curl -L --fail ${final_os_url} -o ${final_os_filepath}.part
    fsize=$(stat -c %s ${final_os_filepath}.part)
    if [ ${fsize} -lt 80000000 ]; then
        echo "invalid final OS file size"
        exit 1
    fi
    mv ${final_os_filepath}.part ${final_os_filepath}
fi

cp ${final_os_filepath} ${TARGET}/final_firmware.img.xz
