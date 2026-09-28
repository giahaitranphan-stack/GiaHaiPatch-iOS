# GiaHaiPatch iOS

Patch manager cho iOS, theo hướng quản lý gói giống 3105:

- Import `.3105`/ZIP/data.
- Hỗ trợ gói có mật khẩu AES-GCM của GiaHaiPatch.
- Khi import gói có mật khẩu, app tự hiện màn hình nhập mật khẩu.
- Tạo patch mới với tên và Bundle ID.
- Hiển thị cây file trong workspace.
- Thêm/thay file và xóa file.
- Export lại thành `.3105`, có thể đặt mật khẩu.
- App icon và launch screen.
- Có GitHub Actions để build IPA unsigned trên macOS runner; sau đó IPA có thể được ký bằng eSign.

## Lưu ý về định dạng

Định dạng `.3105` của project này là gói ZIP/custom encryption do GiaHaiPatch quản lý. Không nên gọi đây là định dạng nội bộ độc quyền của một ứng dụng khác nếu chưa có đặc tả/kiểm thử tương thích. Nếu cần tương thích byte-for-byte với một phiên bản 3105 cụ thể, cần có mẫu gói và đặc tả tương ứng để kiểm tra.

## Build trên Windows bằng GitHub Actions

1. Tạo repository GitHub.
2. Upload toàn bộ nội dung thư mục này, trong đó `.github/workflows/build-ipa.yml` phải nằm đúng vị trí.
3. Vào tab **Actions** → **Build GiaHaiPatch IPA** → **Run workflow**.
4. Chờ job hoàn tất.
5. Mở phần **Artifacts** của workflow và tải `GiaHaiPatch-IPA`.
6. Bên trong có `GiaHaiPatch.ipa` unsigned để đưa sang iPhone và ký bằng eSign.

Không cần đặt certificate Apple vào repository cho workflow này; workflow chỉ tạo IPA unsigned.
