# Tingee SDK for iOS

> SDK chính thức tích hợp cổng thanh toán **Tingee** cho iOS

[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-orange)](https://swift.org/package-manager/)
[![iOS](https://img.shields.io/badge/iOS-14.0%2B-blue)](https://developer.apple.com/ios/)

---

## Cài đặt

### Swift Package Manager (SPM)

1. Mở dự án của bạn trên Xcode.
2. Chọn **File** > **Add Packages...** (hoặc **Add Package Dependencies...**).
3. Nhập URL của kho lưu trữ Github chứa TingeePay SDK.
4. Chọn quy tắc phiên bản (Up to Next Major Version) và nhấn **Add Package**.

---

## Cấu hình

Để SDK hoạt động trơn tru (đặc biệt là tính năng Tải mã QR), bạn **bắt buộc** phải cấu hình file `Info.plist` của ứng dụng.

Mở `Info.plist` dưới dạng Source Code và thêm cấu hình sau để xin quyền lưu mã QR vào Thư viện ảnh:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Ứng dụng cần quyền để lưu mã QR thanh toán vào thư viện ảnh của bạn.</string>
```

---

## Bắt đầu nhanh

> **⚠️ LƯU Ý BẢO MẬT:** 
> Ứng dụng Mobile **KHÔNG ĐƯỢC** lưu trữ `secretKey` hoặc tự gọi API tạo link thanh toán của Tingee. Việc tạo chữ ký (Signature) và gọi API tạo đơn hàng phải được thực hiện hoàn toàn trên Backend của bạn. Backend sau khi tạo đơn thành công sẽ trả về `checkoutUrl` cho ứng dụng Mobile.

Tại ViewController nơi bạn muốn gọi thanh toán, import SDK:

```swift
import TingeePaySDK

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

---

## Lắng nghe kết quả

Kế thừa protocol `TingeePayCheckoutDelegate` để nhận các sự kiện:

```swift
extension CheckoutViewController: TingeePayCheckoutDelegate {
    
    /// Sự kiện: Thanh toán kết thúc (Thành công, Lỗi, Hết hạn...)
    func tingeePayCheckoutDidFinish(with result: TingeePaymentResult) {
        print("Trạng thái: \(result.status.rawValue)")
        print("Mã đơn hàng: \(result.orderId ?? "")")
        
        switch result.status {
        case .success:
            print("Thanh toán thành công!")
        case .failed, .error:
            print("Lỗi thanh toán: \(result.errorMessage ?? "")")
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

## Mô hình dữ liệu

### `TingeePaymentResult`

| Thuộc tính | Kiểu | Mô tả |
|---|---|---|
| `status` | `TingeePaymentStatus` | Trạng thái cuối cùng của giao dịch. |
| `orderId` | `String?` | Mã đơn hàng (Mã mà hệ thống của bạn gửi cho Tingee). |
| `transactionId` | `String?` | Mã giao dịch phía Tingee. |
| `errorCode` | `String?` | Mã lỗi (nếu có). |
| `errorMessage` | `String?` | Thông báo lỗi chi tiết (nếu có). |

> **`TingeePaymentStatus`** bao gồm: `.success`, `.failed`, `.cancelled`, `.expired`, `.error`, `.unknown`.

---

## Xử lý sự cố

**1. Bấm "Tải mã QR" không có phản hồi:**
- Cần chắc chắn bạn đã thêm key `NSPhotoLibraryAddUsageDescription` vào `Info.plist`. Lần đầu tiên bấm tải, hệ điều hành sẽ hiển thị popup xin quyền.

**2. Test trên môi trường Sandbox:**
- SDK Mobile tự động chuyển môi trường dựa vào URL. Nếu `checkoutUrl` bắt đầu bằng URL Sandbox của Tingee, SDK sẽ tự hiểu và hiển thị giao diện Sandbox.

---

## Xem thêm

- [CHANGELOG](./CHANGELOG.md)
- [Tài liệu Tingee Open API](https://open-api.tingee.vn)
- [Tài liệu Tingee Developer](https://developers.tingee.vn)
- [Trang chủ Tingee](https://tingee.vn)
