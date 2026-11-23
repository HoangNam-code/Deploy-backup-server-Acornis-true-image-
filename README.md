# HƯỚNG DẪN TOÀN DIỆN TỪ A-Z: SAO LƯU & PHỤC HỒI HỆ THỐNG CENTOS BẰNG ACRONIS TRUE IMAGE 2021 KẾT HỢP TỰ ĐỘNG ĐỒNG BỘ LÊN GOOGLE DRIVE

---

## PHẦN 1: TỔNG QUAN MÔ HÌNH TRIỂN KHAI

* **Phần mềm ảo hóa:** VMware Workstation Pro
* **Công cụ sao lưu:** Đĩa cứu hộ `AcronisTrueImage2021.iso` (Bootable Media)
* **Máy 1 (Máy chủ chứa bản Backup - Backup Server):**
  * **Hệ điều hành:** CentOS Stream / CentOS 7 (có giao diện GNOME Desktop)
  * **Dung lượng ổ cứng khuyến nghị:** 30 GB – 40 GB (hoặc gắn thêm ổ cứng phụ để tránh đầy 100% dung lượng khi chứa file `.tibx`)
  * **Chế độ mạng:** NAT (ví dụ IP nhận được: `192.168.109.129/24`)
  * **Vai trò:** Chạy dịch vụ chia sẻ mạng Samba (thư mục `/backup`) để nhận file backup từ máy Client, đồng thời chạy công cụ `rclone` + `cloud_backup.sh` để đẩy/tải file backup lên Google Drive (`<your-email>@gmail.com`).
* **Máy 2 (Máy trạm cần bảo vệ - Client):**
  * **Hệ điều hành:** CentOS Stream / CentOS 7
  * **Chế độ mạng:** NAT (cùng dải mạng với Máy 1, ví dụ IP: `192.168.109.138/24`)
  * **Vai trò:** Máy chứa dữ liệu thực tế (ví dụ 20 file `.txt` trong thư mục `Documents`) và hệ điều hành cần được chụp ảnh ổ đĩa hoặc sao lưu qua mạng sang Máy 1.

---

## PHẦN 2: KHỞI TẠO 2 MÁY ẢO TỪ ĐẦU (TRÊN VMWARE WORKSTATION)

### 1. Tạo và cài đặt Máy 1 (Máy chứa Backup)

1. Mở **VMware Workstation** -> chọn **File** -> **New Virtual Machine...** -> chọn **Custom (advanced)** -> **Next**.
2. Tại bước *Guest Operating System Installation*: Chọn **I will install the operating system later** -> **Next**.
3. Chọn hệ điều hành **Linux** -> Version: **CentOS 7 64-bit** (hoặc **CentOS 8 / Stream 64-bit**) -> **Next**.
4. Đặt tên máy ảo là `Backup_Server` -> chọn vị trí lưu trên ổ cứng máy thật còn trống tối thiểu 30 GB – 40 GB -> **Next**.
5. Cấu hình phần cứng:
   * **Processor:** 1 hoặc 2 cores.
   * **Memory (RAM):** 2048 MB (2 GB).
   * **Network Type:** Chọn **NAT** (để cả 2 máy vừa thông nhau trong mạng nội bộ vừa có Internet để tải gói Samba, Rclone và kết nối Google Drive).
   * **Virtual Disk:** Tạo ổ cứng mới dung lượng **40 GB** (để thoải mái chứa các bản chụp ảnh hệ thống `.tibx` mà không bị lỗi *no space left on device*).
6. Gắn file ISO cài đặt CentOS vào mục **CD/DVD (SATA/IDE)** -> tích chọn **Connect at power on** -> bật máy và cài đặt CentOS với tùy chọn **Server with GUI** (hoặc **GNOME Desktop**), đặt mật khẩu `root` và tạo user cá nhân.

### 2. Tạo Máy 2 (Máy Client) nhanh bằng tính năng Clone (hoặc cài mới tương tự)

1. Để tiết kiệm thời gian, sau khi cài xong Máy 1 (khi chưa cấu hình gì), bạn tắt nguồn Máy 1 (`poweroff`).
2. Trên VMware Workstation, nhấp chuột phải vào Máy 1 -> chọn **Manage** -> **Clone...** -> **Next** -> chọn **Create a full clone** -> đặt tên là `Client` -> nhấn **Finish**.
3. Bật cả 2 máy ảo lên, mở **Terminal** trên từng máy và gõ lệnh kiểm tra địa chỉ IP:
   ```bash
   ip a