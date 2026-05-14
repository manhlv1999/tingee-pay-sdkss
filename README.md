# TingeePay SDK for iOS

TingeePay SDK là thư viện chính thức giúp tích hợp cổng thanh toán Tingee vào ứng dụng iOS một cách nhanh chóng, an toàn và mang lại trải nghiệm Native tốt nhất cho người dùng.

SDK hỗ trợ:
- Mở trang thanh toán (Quick Checkout) nhanh chóng.
- Hỗ trợ giao diện `fullScreen` hoặc `bottomSheet` (kéo thả mượt mà trên iOS 15+).
- Tự động bắt Deep Link/Universal Link để chuyển hướng sang các ứng dụng Ngân hàng/Ví điện tử.
- Xử lý mượt mà sự kiện tải mã QR Code về Thư viện ảnh (Camera Roll).
- Giao tiếp thời gian thực với Web Bridge để nhận kết quả thanh toán ngay lập tức.

---

## 1. Yêu cầu hệ thống (Requirements)

- iOS 14.0 trở lên.
- Swift 5.0+.
- Xcode 14.0+.

---

## 2. Cài đặt (Installation)

TingeePay SDK được phân phối qua **Swift Package Manager (SPM)**.

1. Mở dự án của bạn trên Xcode.
2. Chọn **File** > **Add Packages...** (hoặc **Add Package Dependencies...**).
3. Nhập URL của kho lưu trữ Github chứa TingeePay SDK.
4. Chọn quy tắc phiên bản (Up to Next Major Version) và nhấn **Add Package**.

---

## 3. Cấu hình dự án (Configuration)

Để SDK hoạt động trơn tru (đặc biệt là tính năng Tải mã QR), bạn **bắt buộc** phải cấu hình file `Info.plist` của ứng dụng.

Mở `Info.plist` dưới dạng Source Code và thêm cấu hình sau:

### Xin quyền lưu mã QR vào Thư viện ảnh
Khi người dùng bấm "Tải mã QR", SDK sẽ lưu ảnh thẳng vào máy. Bạn cần xin quyền:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Ứng dụng cần quyền để lưu mã QR thanh toán vào thư viện ảnh của bạn.</string>
```

---

## 4. Hướng dẫn tích hợp (Usage)

Quá trình tích hợp diễn ra theo 2 bước chính:
1. **Phía Server (Backend):** Gọi API Tingee để tạo link thanh toán (`checkoutUrl`).
2. **Phía Mobile (App):** Nhận `checkoutUrl` từ Backend, gọi SDK để hiển thị giao diện và lắng nghe kết quả.

> **⚠️ LƯU Ý BẢO MẬT:** 
> Ứng dụng Mobile **KHÔNG ĐƯỢC** lưu trữ `secretKey` hoặc tự gọi API tạo link thanh toán của Tingee. Việc tạo chữ ký (Signature) và gọi API tạo đơn hàng phải được thực hiện hoàn toàn trên Backend của bạn. Backend sau khi tạo đơn thành công sẽ trả về `checkoutUrl` cho ứng dụng Mobile.

### Bước 1: Import thư viện

Tại ViewController nơi bạn muốn gọi thanh toán, import SDK:

```swift
import TingeePaySDK
```

### Bước 2: Gọi SDK hiển thị giao diện thanh toán

Khi bạn đã lấy được `checkoutUrl` từ Backend của bạn, hãy sử dụng hàm `TingeePay.presentCheckout` để mở giao diện:

```swift
class CheckoutViewController: UIViewController {

    func openPayment(checkoutUrlString: String) {
        guard let checkoutUrl = URL(string: checkoutUrlString) else { return }
        
        // Gọi SDK để hiển thị thanh toán
        TingeePay.presentCheckout(
            from: self, 
            checkoutUrl: checkoutUrl, 
            style: .bottomSheet, // Hoặc .fullScreen
            delegate: self
        )
    }
}
```

**Các tham số của `presentCheckout`:**
- `from`: ViewController hiện tại đang dùng để đẩy màn hình SDK lên.
- `checkoutUrl`: URL thanh toán Tingee được sinh ra từ Backend của bạn.
- `style`: Kiểu hiển thị màn hình thanh toán. Hỗ trợ 2 kiểu:
  - `.fullScreen`: Trải dài toàn màn hình thiết bị.
  - `.bottomSheet`: Hiển thị dạng cửa sổ kéo từ dưới lên (Hỗ trợ 2 nấc kéo thả trên iOS 15+).
- `delegate`: Lớp nhận các callback kết quả thanh toán.

### Bước 3: Lắng nghe kết quả thanh toán

Kế thừa protocol `TingeePayCheckoutDelegate` để nhận các sự kiện:

```swift
extension CheckoutViewController: TingeePayCheckoutDelegate {
    
    /// Sự kiện: Thanh toán kết thúc (Thành công, Lỗi, Hết hạn...)
    func tingeePayCheckoutDidFinish(with result: TingeePaymentResult) {
        print("Trạng thái: \(result.status.rawValue)")
        print("Mã đơn hàng: \(result.orderId ?? "")")
        print("Mã giao dịch: \(result.transactionId ?? "")")
        
        switch result.status {
        case .success:
            print("Thanh toán thành công! Chuyển sang màn hình hoàn tất.")
        case .failed, .error:
            print("Lỗi thanh toán: \(result.errorMessage ?? "Không rõ") (Mã lỗi: \(result.errorCode ?? ""))")
        case .cancelled:
            print("Giao dịch đã bị huỷ.")
        case .expired:
            print("Đơn hàng đã hết hạn thanh toán.")
        case .unknown:
            print("Trạng thái không xác định.")
        }
    }
    
    /// Sự kiện: Người dùng chủ động bấm Đóng / Huỷ hoặc vuốt tắt màn hình thanh toán
    func tingeePayCheckoutDidCancel() {
        print("Người dùng đã thoát màn hình thanh toán.")
    }
    
    /// Sự kiện: Lỗi phát sinh trong quá trình tải SDK (Ví dụ: Mất mạng, sai URL...)
    func tingeePayCheckoutDidFail(with error: Error) {
        print("Lỗi khởi tạo màn hình thanh toán: \(error.localizedDescription)")
    }
}
```

---

## 5. Mô hình dữ liệu (Data Models)

### `TingeePaymentResult`
Đối tượng được SDK trả về khi hàm `tingeePayCheckoutDidFinish` được gọi:

| Thuộc tính | Kiểu dữ liệu | Mô tả |
| :--- | :--- | :--- |
| `status` | `TingeePaymentStatus` | Trạng thái cuối cùng của giao dịch. |
| `orderId` | `String?` | Mã đơn hàng (Mã mà hệ thống của bạn gửi cho Tingee). |
| `transactionId` | `String?` | Mã giao dịch phía Tingee. |
| `errorCode` | `String?` | Mã lỗi (nếu có). |
| `errorMessage` | `String?` | Thông báo lỗi chi tiết (nếu có). |

### `TingeePaymentStatus`
Enum đại diện cho các trạng thái giao dịch:
- `.success`: Giao dịch thanh toán thành công.
- `.failed`: Thanh toán thất bại.
- `.cancelled`: Giao dịch bị huỷ bỏ.
- `.expired`: Giao dịch hết hạn.
- `.error`: Lỗi hệ thống.
- `.unknown`: Trạng thái không xác định.

---

## 6. Xử lý sự cố thường gặp (Troubleshooting)

**1. Bấm "Tải mã QR" không có phản hồi:**
- Cần chắc chắn bạn đã thêm key `NSPhotoLibraryAddUsageDescription` vào `Info.plist`. Lần đầu tiên bấm tải, hệ điều hành sẽ hiển thị popup xin quyền. Nếu người dùng chọn "Từ chối", họ sẽ phải vào Cài đặt (Settings) của máy để cấp lại quyền cho ứng dụng.

**2. Làm thế nào để test trên môi trường Sandbox?**
- Đối với SDK Mobile, môi trường Sandbox hay Production phụ thuộc hoàn toàn vào `checkoutUrl` mà bạn truyền vào `presentCheckout`. 
- Nếu `checkoutUrl` bắt đầu bằng URL Sandbox của Tingee (vd: `https://uat-open-api.tingee.vn/...`), SDK sẽ tự hiểu và hiển thị giao diện Sandbox.

---
© 2026 Tingee. All rights reserved.
