#!/usr/bin/env bash

umask 077
shopt -s nullglob

backup_dir=${BACKUP_DIR:-/backup}
source_dir=${SOURCE_DIR:-}
remote_name=${REMOTE_NAME:-ggdrive}
cloud_folder=${CLOUD_FOLDER:-Server_Backup_CentOS}
cloud_path="$remote_name:$cloud_folder"
staging_filter='/.cloud-backup.*/**'

error() {
    printf 'Lỗi: %s\n' "$*" >&2
    return 1
}

show_help() {
    cat <<'HELP'
Cách dùng: /root/cloud_backup.sh [--help]

Biến môi trường tùy chọn:
  SOURCE_DIR   Thư mục cần nén                  (mặc định: /home/*/Documents và /root/Documents)
  BACKUP_DIR   Thư mục lưu file backup          (mặc định: /backup)
  REMOTE_NAME  Tên remote đã cấu hình với rclone (mặc định: ggdrive)
  CLOUD_FOLDER Thư mục backup trên Google Drive (mặc định: Server_Backup_CentOS)
HELP
}

show_menu() {
    printf '\nThư mục backup: %s\nNguồn nén: %s\nGoogle Drive: %s\n' \
        "$backup_dir" "${source_dir:-/home/*/Documents và /root/Documents}" "$cloud_path"
    cat <<'MENU'
1. Xem file backup trên máy
2. Nén thư mục nguồn thành file .tar.gz
3. Tải toàn bộ backup lên Google Drive
4. Tải một file lên Google Drive
5. Xem file backup trên Google Drive
6. Xóa file backup trên máy
7. Tải toàn bộ backup từ Google Drive về máy
8. Tải một file từ Google Drive về máy
0. Thoát
MENU
}

create_archive() (
    local source physical_source timestamp stage archive_name archive
    local tar_dir=/
    local sources=() entries=()

    if [[ -n "$source_dir" ]]; then
        sources=("$source_dir")
    else
        for source in /home/*/Documents /root/Documents; do
            if [[ -d "$source" ]]; then
                sources+=("$source")
            fi
        done
        if (( ${#sources[@]} == 0 )); then
            error 'Không tìm thấy thư mục Documents trong /home hoặc /root.'
            return 1
        fi
    fi

    for source in "${sources[@]}"; do
        physical_source=$(cd -P -- "$source" && pwd -P) ||
            { error "Không mở được thư mục nguồn: $source"; return 1; }
        if [[ "$physical_source" == / || "$backup_dir/" == "$physical_source/"* ]]; then
            error "Hãy chọn thư mục backup nằm ngoài thư mục nguồn: $source"
            return 1
        fi
        if [[ -n "$source_dir" ]]; then
            source="$physical_source"
            tar_dir="${source%/*}/"
        fi
        entries+=("${source#"$tar_dir"}")
    done

    timestamp=$(date '+%Y%m%d_%H%M%S') || return 1
    stage=$(mktemp -d "$backup_dir/.cloud-backup.XXXXXXXX") || return 1
    archive_name="Documents_Backup_${timestamp}_${stage##*.}.tar.gz"
    archive="$stage/$archive_name"
    trap 'rm -f -- "$archive"; rmdir -- "$stage"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if tar -czf "$archive" -C "$tar_dir" -- "${entries[@]}" &&
        tar -tzf "$archive" >/dev/null &&
        mv -n -- "$archive" "$backup_dir/" &&
        [[ ! -e "$archive" ]]; then
        printf 'Đã tạo bản sao lưu: %s/%s\n' "$backup_dir" "$archive_name"
    else
        error 'Không tạo được bản sao lưu hoàn chỉnh.'
    fi
)

valid_filename() {
    case "$1" in
        '' | .* | */*) error 'Hãy nhập tên file hiển thị trong danh sách, không kèm đường dẫn.' ;;
        *) return 0 ;;
    esac
}

is_local_file() {
    [[ -f "$1" && ! -L "$1" ]]
}

require_cloud() {
    command -v rclone >/dev/null 2>&1 ||
        { error 'Hãy cài rclone để sử dụng Google Drive.'; return 1; }

    case "$remote_name" in
        *[!a-zA-Z0-9_.-]* | -*)
            error 'REMOTE_NAME phải là tên một remote đã cấu hình bằng rclone.'
            return 1
            ;;
    esac
    case "/$cloud_folder/" in
        *//* | */../* | */./*)
            error 'CLOUD_FOLDER phải là đường dẫn thư mục tương đối trên Google Drive.'
            return 1
            ;;
    esac
}

copy_backup() {
    if rclone "$@" --progress --immutable --checksum; then
        printf 'Sao chép hoàn tất.\n'
    else
        error 'Sao chép gặp lỗi. Xem thông báo của rclone ở trên.'
    fi
}

upload_one() {
    local filename
    require_cloud || return 1
    ls -1 -- "$backup_dir/" || return 1
    IFS= read -r -p 'Tên file cần tải lên: ' filename || return 1
    valid_filename "$filename" || return 1
    is_local_file "$backup_dir/$filename" ||
        { error "Không tìm thấy file thường: $filename"; return 1; }

    copy_backup copyto "$backup_dir/$filename" "$cloud_path/$filename"
}

download_one() {
    local filenames filename
    require_cloud || return 1
    filenames=$(rclone lsf "$cloud_path" --files-only) || return 1
    if [[ -z "$filenames" ]]; then
        printf 'Thư mục Google Drive chưa có file ở cấp ngoài cùng.\n'
        return 0
    fi

    printf '%s\n' "$filenames"
    IFS= read -r -p 'Tên file cần tải về: ' filename || return 1
    valid_filename "$filename" || return 1
    case "$(grep -Fxc -- "$filename" <<< "$filenames")" in
        0) error "Không tìm thấy file trên Google Drive: $filename"; return 1 ;;
        1) ;;
        *) error "Google Drive có nhiều file cùng tên: $filename"; return 1 ;;
    esac
    if [[ -e "$backup_dir/$filename" || -L "$backup_dir/$filename" ]] &&
        ! is_local_file "$backup_dir/$filename"; then
        error "Đường dẫn đích đã tồn tại và không phải file thường: $filename"
        return 1
    fi

    copy_backup copyto "$cloud_path/$filename" "$backup_dir/$filename"
}

delete_local() {
    local filename path confirmation
    local files=()

    ls -1 -- "$backup_dir/" || return 1
    IFS= read -r -p 'Tên file cần xóa, hoặc ALL để chọn mọi file ở cấp ngoài cùng: ' filename || return 1
    if [[ "$filename" == ALL ]]; then
        for path in "$backup_dir/"*; do
            if is_local_file "$path"; then
                files+=("$path")
            fi
        done
    else
        valid_filename "$filename" || return 1
        path="$backup_dir/$filename"
        is_local_file "$path" || { error "Không tìm thấy file thường: $filename"; return 1; }
        files+=("$path")
    fi

    if (( ${#files[@]} == 0 )); then
        printf 'Không có file để xóa.\n'
        return 0
    fi
    printf 'Các file sẽ bị xóa:\n'
    printf '  %s\n' "${files[@]}"
    read -r -p 'Gõ XOA để xác nhận: ' confirmation || return 1
    if [[ "$confirmation" != XOA ]]; then
        printf 'Đã hủy thao tác xóa.\n'
        return 0
    fi

    if rm -- "${files[@]}"; then
        printf 'Đã xóa %s file trên máy.\n' "${#files[@]}"
    else
        error 'Có file chưa xóa được. Hãy kiểm tra lại danh sách.'
    fi
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    show_help
    exit 0
fi
if (( $# != 0 )); then
    show_help >&2
    exit 2
fi

[[ "$backup_dir" == /* ]] || backup_dir="$PWD/$backup_dir"
[[ -z "$source_dir" || "$source_dir" == /* ]] || source_dir="$PWD/$source_dir"
mkdir -p -- "$backup_dir" || exit 1
backup_dir=$(cd -P -- "$backup_dir" && pwd -P) || exit 1
if [[ "$backup_dir" == / ]]; then
    error 'Hãy chọn một thư mục riêng để lưu backup.'
    exit 1
fi

while true; do
    show_menu
    read -r -p 'Chọn chức năng [0-8]: ' choice || exit 0
    case "$choice" in
        1) ls -lh -- "$backup_dir/" ;;
        2) create_archive ;;
        3) require_cloud && copy_backup copy "$backup_dir" "$cloud_path" --exclude "$staging_filter" ;;
        4) upload_one ;;
        5) require_cloud && rclone lsf "$cloud_path" --recursive --files-only --exclude "$staging_filter" ;;
        6) delete_local ;;
        7) require_cloud && copy_backup copy "$cloud_path" "$backup_dir" --exclude "$staging_filter" ;;
        8) download_one ;;
        0) exit 0 ;;
        *) error 'Hãy nhập một số từ 0 đến 8.' ;;
    esac
done
