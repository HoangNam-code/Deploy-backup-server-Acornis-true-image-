#!/usr/bin/env bash

set -e

if (( EUID != 0 )); then
    printf 'Hãy chạy sudo bash ./install.sh trên máy chủ CentOS.\n' >&2
    exit 1
fi

script_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source_file="$script_dir/cloud_backup.sh"
destination=/root/cloud_backup.sh
bash -n "$source_file"

if [[ -d "$destination" ]]; then
    printf 'Không thể cài đặt vì %s là thư mục.\n' "$destination" >&2
    exit 1
fi

temporary_file=$(mktemp /root/.cloud_backup.XXXXXXXX)
trap 'rm -f -- "$temporary_file"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

install -m 0700 -- "$source_file" "$temporary_file"
mv -f -- "$temporary_file" "$destination"
printf 'Đã cài đặt /root/cloud_backup.sh. Chạy sudo -H /root/cloud_backup.sh để mở menu.\n'
