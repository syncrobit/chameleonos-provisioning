#!/bin/bash

BUCKET="syncrobit-firmware"
S3CMD="s3cmd -c ${HOME}/.s3cfg-chameleon"

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
    # $1 - prefix
    # $2 - file
    
    ${S3CMD} put --acl-public --guess-mime-type $2 s3://${BUCKET}/$1/$(basename $2)
}

function s3delete() {
    # $1 - prefix
    # $2 - file

    ${S3CMD} del s3://${BUCKET}/$1/$2
}

function s3copy() {
    # $1 - prefix
    # $2 - src_file
    # $3 - dst_file

    ${S3CMD} cp s3://${BUCKET}/$1/$2 s3://${BUCKET}/$1/$3
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
            s3upload ${THINGOS_PREFIX} ${image_path}
            latest_file="latest.json"
            make_latest "/${THINGOS_PREFIX}/${image_name}" ${version} > /tmp/${latest_file}
            s3upload ${THINGOS_PREFIX} /tmp/${latest_file}
            ;;

        unrelease)
            latest_file="latest"
            latest_file+=".json"
            s3delete ${THINGOS_PREFIX} ${latest_file}
            ;;
        
        promote)
            if [[ "${os_prefix}" != "${THINGOS_PREFIX}" ]]; then
                echo "Invalid OS image prefix: ${os_prefix}"
                exit 1
            fi
            latest_file="latest.json"
            make_latest "/${THINGOS_PREFIX}/${image_name}" ${version} > /tmp/${latest_file}
            s3upload ${THINGOS_PREFIX} /tmp/${latest_file}
            ;;

        upload)
            if [[ "${os_prefix}" != "${THINGOS_PREFIX}" ]]; then
                echo "Invalid OS image prefix: ${os_prefix}"
                exit 1
            fi
            s3upload ${THINGOS_PREFIX} ${image_path}
            ;;
    esac
}

if [[ -z "${VENDOR}" ]]; then
    echo "Variable VENDOR is unset"
    exit 1
fi

set -a
source ${base_path}/vendors/${VENDOR}.conf
set +a 

main
