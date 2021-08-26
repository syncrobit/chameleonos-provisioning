#!/bin/bash

REGIONS="us-east-1 eu-central-1 ap-south-1"
BUCKET="syncrobit-firmware"
S3CMD="s3cmd -c ${HOME}/.s3cfg-linode"

function exit_usage() {
    echo "Usage: $0 <release|unrelease|promote|upload> [image.xz]"
    exit 1
}

if [[ -z "$1" ]]; then
    exit_usage
fi

cmd=$1
image_path=$2
base_path=$(dirname $0)

if [[ -z "$2" ]]; then
    if [[ ${cmd} == release-* ]] || [[ ${cmd} == upload ]] || [[ ${cmd} == promote-beta ]]; then
        exit_usage
    fi
fi

function s3upload() {
    # $1 - region
    # $2 - prefix
    # $3 - file
    
    host=${region}.linodeobjects.com
    ${S3CMD} put --acl-public --guess-mime-type --host=${host} --host-bucket=${host} $3 \
             s3://${BUCKET}/$2/$(basename $3)
}

function s3delete() {
    # $1 - region
    # $2 - prefix
    # $3 - file

    host=${region}.linodeobjects.com    
    ${S3CMD} del --host=${host} --host-bucket=${host} s3://${BUCKET}/$2/$3
}

function s3copy() {
    # $1 - region
    # $2 - prefix
    # $3 - src_file
    # $4 - dst_file

    host=${region}.linodeobjects.com    
    ${S3CMD} cp --host=${host} --host-bucket=${host} s3://${BUCKET}/$2/$3 s3://${BUCKET}/$2/$4
}

function make_latest() {
    # $1 - path
    # $2 - version

    echo "{"
    echo "    \"path\": \"$1\","
    echo "    \"version\": \"$2\","
    echo "    \"date\": \"$(date +%Y-%m-%d)\""
    echo "}"
}

function get_image_params() {
    # $1 - image name (e.g. chameleonos-chpr-raspberrypi4arm64-2021.03.14.1.img.xz)
    image_name=$1
    image_name=${image_name:0:-7}  # strip trailing ".img.gz"
    IFS=-; image_params=(${image_name}); unset IFS
    echo "${image_params[@]}"
}

function main() {
    # $1 - region
    
    region=$1
    if [[ -n "${image_path}" ]]; then
        image_name=$(basename ${image_path})
        image_params=($(get_image_params ${image_name}))
        os_name=${image_params[0]}
        os_prefix=${image_params[1]}
        board=${image_params[2]}
        version=${image_params[3]}
    fi
    
    case ${cmd} in
        release)
            if [[ "${os_prefix}" != "${THINGOS_PREFIX}" ]]; then
                echo "Invalid OS image prefix: ${os_prefix}"
                exit 1
            fi
            s3upload ${region} ${THINGOS_PREFIX} ${image_path}
            latest_file="latest.json"
            make_latest "/${THINGOS_PREFIX}/${image_name}" ${version} > /tmp/${latest_file}
            s3upload ${region} ${THINGOS_PREFIX} /tmp/${latest_file}
            ;;

        unrelease)
            latest_file="latest"
            latest_file+=".json"
            s3delete ${region} ${THINGOS_PREFIX} ${latest_file}
            ;;
        
        promote)
            if [[ "${os_prefix}" != "${THINGOS_PREFIX}" ]]; then
                echo "Invalid OS image prefix: ${os_prefix}"
                exit 1
            fi
            latest_file="latest.json"
            make_latest "/${THINGOS_PREFIX}/${image_name}" ${version} > /tmp/${latest_file}
            s3upload ${region} ${THINGOS_PREFIX} /tmp/${latest_file}
            ;;

        upload)
            if [[ "${os_prefix}" != "${THINGOS_PREFIX}" ]]; then
                echo "Invalid OS image prefix: ${os_prefix}"
                exit 1
            fi
            s3upload ${region} ${THINGOS_PREFIX} ${image_path}
            ;;
    esac
}

if [[ -z "${VENDOR}" ]]; then
    echo "Variable VENDOR is unset"
    exit 1
fi

set -a
source ${base_path}/vendors/common.conf
source ${base_path}/vendors/${VENDOR}.conf
set +a 


for region in ${REGIONS}; do
    main ${region}
done
