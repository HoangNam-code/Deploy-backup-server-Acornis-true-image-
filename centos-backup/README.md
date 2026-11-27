# Sao lưu dữ liệu và Google Drive

`cloud_backup.sh` triển khai menu ở Phần 6 của tài liệu hướng dẫn CentOS. Bạn có thể nén một thư mục thành `.tar.gz` hoặc tải lên và tải về những bản sao lưu có sẵn, kể cả ảnh đĩa `.tibx` do Acronis tạo.

## Tải từ GitHub

**Tải ZIP**

1. Mở [repository trên GitHub](https://github.com/HoangNam-code/Deploy-backup-server-Acornis-true-image-) và chọn **Code → Download ZIP**. [Hướng dẫn tải file từ GitHub](https://docs.github.com/en/repositories/working-with-files/using-files/downloading-files-from-github)
2. Chép file ZIP sang **Máy 1 (Backup Server)** nếu bạn tải trên máy khác, rồi giải nén.
3. Mở Terminal trong thư mục chứa `install.sh` và `cloud_backup.sh`. Nếu hai file nằm trong thư mục con `centos-backup`, hãy mở Terminal tại thư mục đó.

**Tải bằng Git**

Nếu Máy 1 đã có Git, mở Terminal trên máy đó và chạy các lệnh dưới đây.

```bash
git clone https://github.com/HoangNam-code/Deploy-backup-server-Acornis-true-image-
cd Deploy-backup-server-Acornis-true-image-
```

Nếu `install.sh` và `cloud_backup.sh` nằm trong thư mục con `centos-backup`, chạy thêm `cd centos-backup`.

## Cài đặt và mở menu trên CentOS

Từ thư mục chứa hai file script, chạy bằng tài khoản có quyền `sudo`:

```bash
sudo bash ./install.sh
sudo -H /root/cloud_backup.sh
```

Nếu đã đăng nhập bằng `root`, dùng `bash ./install.sh` và `/root/cloud_backup.sh`. Script tạo thư mục `/backup` khi chạy nếu thư mục này chưa có. Chọn **2** để nén các thư mục `Documents` hiện có trong `/home/*` và `/root` trên máy đang chạy, rồi chọn **1** để kiểm tra.

Để nén một thư mục cụ thể, dùng đường dẫn tuyệt đối đến thư mục đó trên máy chủ:

```bash
sudo -H env SOURCE_DIR="/home/nguoidung/Documents" /root/cloud_backup.sh
```

| Biến | Mặc định | Công dụng |
| --- | --- | --- |
| `SOURCE_DIR` | `/home/*/Documents` và `/root/Documents` | Thư mục dữ liệu trên máy đang chạy script |
| `BACKUP_DIR` | `/backup` | Thư mục riêng để lưu backup; script tự tạo nếu có quyền |
| `REMOTE_NAME` | `ggdrive` | Tên remote rclone, dùng chữ cái ASCII, chữ số, dấu chấm, gạch dưới hoặc gạch ngang |
| `CLOUD_FOLDER` | `Server_Backup_CentOS` | Thư mục backup trong Google Drive, tính từ gốc của remote |

`BACKUP_DIR` phải nằm ngoài thư mục nguồn. Với Samba, cấp quyền cho tài khoản chạy script và tài khoản dùng để mở ảnh đĩa qua SMB. Script tạo file mới với quyền riêng tư mặc định.

## Kết nối Google Drive trên Máy 1

1. Cài [rclone](https://rclone.org/install/) và chạy `sudo -H rclone config` để lưu cấu hình cho tài khoản `root`.
2. Tạo remote kiểu Google Drive (`drive`) tên `ggdrive`, hoặc dùng một remote đã cấu hình và đặt `REMOTE_NAME` tương ứng. Với remote mới, hãy chuẩn bị OAuth client ID và client secret theo [hướng dẫn Google Drive của rclone](https://rclone.org/drive/#making-your-own-client_id).
3. Đăng nhập Google và cấp quyền cho remote. Nếu máy chủ không có trình duyệt, làm theo [hướng dẫn xác thực từ máy khác](https://rclone.org/remote_setup/).
4. Chạy `sudo -H rclone about ggdrive:` để kiểm tra kết nối, rồi mở menu bằng `sudo -H /root/cloud_backup.sh`.

Ví dụ chạy với một remote đã cấu hình và thư mục Drive riêng:

```bash
sudo -H env REMOTE_NAME=drive_cong_viec CLOUD_FOLDER="Backup/CentOS-01" \
  /root/cloud_backup.sh
```

## Các chức năng

| Phím | Thao tác |
| --- | --- |
| 1 | Xem file và thư mục backup trên máy |
| 2 | Tạo và kiểm tra file `Documents_Backup_*.tar.gz` |
| 3 | Tải toàn bộ nội dung thư mục backup lên Drive, kể cả thư mục con |
| 4 | Tải một file ở cấp ngoài cùng lên Drive |
| 5 | Liệt kê file trên Drive, kể cả trong thư mục con |
| 6 | Xóa file cục bộ. Gõ tên file hoặc `ALL` để chọn các file thường không ẩn ở cấp ngoài cùng, rồi gõ `XOA` để xác nhận |
| 7 | Tải toàn bộ nội dung thư mục Drive đã cấu hình về máy, kể cả thư mục con |
| 8 | Tải một file ở cấp ngoài cùng trên Drive về máy |
| 0 | Thoát |

Các mục **1, 2 và 6** dùng được khi chưa cài rclone. Khi sao chép, file giống nhau được bỏ qua và file trùng tên khác nội dung sẽ báo lỗi. Việc tải lên và tải về giữ lại các file riêng đã có ở đích. Với ảnh `.tibx` ghi qua Samba, đợi Acronis ghi xong trước khi tải lên.

## Khôi phục

- **File `.tar.gz`**: Nếu bản nén ở trên Drive, dùng mục **8** để tải về. Liệt kê nội dung rồi giải nén vào một thư mục riêng. Thay đường dẫn trong ví dụ bằng tên bản backup cần khôi phục.

  ```bash
  archive="/backup/ten-ban-backup.tar.gz"
  restore_dir=$(mktemp -d "$HOME/khoi-phuc.XXXXXXXX") &&
    tar -tzf "$archive" &&
    tar -xzf "$archive" -C "$restore_dir" &&
    printf '%s\n' "$restore_dir"
  ```

- **Ảnh đĩa `.tibx`**: Tải file về thư mục chia sẻ Samba nếu cần. Khởi động máy cần khôi phục từ Acronis Rescue Media, mở **Recovery → Disk and Partition Recovery** và chọn ảnh đĩa trên thư mục chia sẻ.
