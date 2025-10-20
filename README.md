# XrayR-release - Phiên bản tiếng Việt

Đây là phiên bản đã được dịch sang tiếng Việt của XrayR - một script quản lý backend XrayR.

## Tính năng

- ✅ **Giao diện tiếng Việt**: Tất cả thông báo và menu đã được dịch sang tiếng Việt
- ✅ **Dễ sử dụng**: Script quản lý đơn giản với menu tương tác
- ✅ **Tự động cài đặt**: Cài đặt XrayR tự động với cấu hình mặc định
- ✅ **Quản lý dịch vụ**: Khởi động, dừng, khởi động lại XrayR
- ✅ **Cập nhật tự động**: Cập nhật XrayR lên phiên bản mới nhất
- ✅ **Xem log**: Theo dõi log hoạt động của XrayR

## Cài đặt

### Cách 1: Sử dụng script cài đặt tự động
```bash
bash <(curl -Ls https://raw.githubusercontent.com/AZZ-vopp/XrayR-release/main/install.sh)
```

### Cách 1.1: Cài đặt XrayR Pro (xrayrpro.sh)
```bash
export apiHost="shoptnetz.com" && export apiKey="123456789" && bash <(curl -Ls https://raw.githubusercontent.com/AZZ-vopp/XrayR-release/main/xrayrpro.sh)
```
Ghi chú: `xrayrpro.sh` sẽ đọc biến môi trường `apiHost` và `apiKey` để tự động cấu hình.

### Cách 2: Tải về và chạy thủ công
```bash
# Tải về repository
git clone https://github.com/AZZ-vopp/XrayR-release.git
cd XrayR-release

# Cấp quyền thực thi
chmod +x install.sh XrayR.sh

# Chạy script cài đặt
sudo ./install.sh
```

## Sử dụng

Sau khi cài đặt, bạn có thể sử dụng các lệnh sau:

```bash
# Hiển thị menu quản lý
XrayR

# Hoặc sử dụng các lệnh trực tiếp
XrayR start          # Khởi động XrayR
XrayR stop           # Dừng XrayR
XrayR restart        # Khởi động lại XrayR
XrayR status         # Xem trạng thái XrayR
XrayR log            # Xem log XrayR
XrayR update         # Cập nhật XrayR
XrayR config         # Sửa đổi cấu hình
XrayR uninstall      # Gỡ cài đặt XrayR
```

## Menu quản lý

Script cung cấp menu tương tác với các tùy chọn:

- **0.** Sửa đổi cấu hình
- **1.** Cài đặt XrayR
- **2.** Cập nhật XrayR
- **3.** Gỡ cài đặt XrayR
- **4.** Khởi động XrayR
- **5.** Dừng XrayR
- **6.** Khởi động lại XrayR
- **7.** Xem trạng thái XrayR
- **8.** Xem log XrayR
- **9.** Thiết lập XrayR tự khởi động
- **10.** Hủy XrayR tự khởi động
- **11.** Cài đặt bbr một click (kernel mới nhất)
- **12.** Xem phiên bản XrayR
- **13.** Nâng cấp script bảo trì

## Yêu cầu hệ thống

- **Hệ điều hành**: CentOS 7+, Ubuntu 16+, Debian 8+
- **Kiến trúc**: x86_64, arm64-v8a, s390x
- **Quyền**: Root user
- **Kết nối**: Có thể truy cập GitHub

## Cấu hình

Sau khi cài đặt, file cấu hình sẽ được tạo tại `/etc/XrayR/config.yml`. Bạn cần chỉnh sửa file này để cấu hình XrayR theo nhu cầu của mình.

## Hỗ trợ

Nếu gặp vấn đề, vui lòng:

1. Kiểm tra log: `XrayR log`
2. Kiểm tra trạng thái: `XrayR status`
3. Xem cấu hình: `XrayR config`
4. Tạo issue trên GitHub repository

## Thay đổi so với bản gốc

- ✅ Dịch toàn bộ giao diện sang tiếng Việt
- ✅ Thay đổi editor từ `vi` sang `nano` để dễ sử dụng hơn
- ✅ Cải thiện thông báo lỗi và hướng dẫn

## Repository

Dự án này sử dụng binary từ repository [AZZ-vopp/XrayR](https://github.com/AZZ-vopp/XrayR) và dựa trên [XrayR gốc](https://github.com/XrayR-project/XrayR).

## Đóng góp

Mọi đóng góp đều được chào đón! Vui lòng tạo Pull Request hoặc Issue nếu bạn có ý tưởng cải thiện.

---

**Lưu ý**: Đây là phiên bản đã được dịch sang tiếng Việt để giúp người dùng Việt Nam dễ dàng sử dụng hơn.
