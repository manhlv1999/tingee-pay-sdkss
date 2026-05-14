import UIKit
import TingeePaySDK
import CryptoKit

enum TingeeEnvironment {
    case sandbox
    case production
    
    var baseURL: String {
        switch self {
        case .sandbox: return "https://uat-open-api.tingee.vn"
        case .production: return "https://open-api.tingee.vn"
        }
    }
}

// MARK: - App Configuration
/// Định nghĩa cấu hình môi trường và keys.
/// Trong ứng dụng Production thực tế: KHÔNG BAO GIỜ lưu `secret` trong App để tránh rò rỉ bảo mật.
/// Toàn bộ logic tạo Signature nên được xử lý trên Backend của Merchant.
enum TingeeAppConfig {
    static let clientId = "74972a04e7dd7eeaf2c30868cdb5fd6a"
    static let secret = "htIQdfgxq114HvfBKb6gP+WXegFv377SAgktTd4V9Uw="
    static let environment: TingeeEnvironment = .sandbox
}

// MARK: - Request Model (Dành cho App Demo giả lập Backend)
struct TingeePaymentLinkRequest: Codable {
    var merchantId: Int
    var orderId: String?
    var requestId: String
    var amount: Int
    var currency: String
    var expireInMinute: Int
    var description: String
    var orderInfo: String
    var bankBin: String
    var customerInfo: String
    var vaAccountNumber: String
    var returnUrl: String
    var partnerCustomerId: String
    
    init(
        merchantId: Int,
        orderId: String?,
        requestId: String = UUID().uuidString,
        amount: Int,
        currency: String = "VND",
        expireInMinute: Int = 30,
        description: String,
        orderInfo: String,
        bankBin: String,
        customerInfo: String,
        vaAccountNumber: String,
        returnUrl: String,
        partnerCustomerId: String
    ) {
        self.merchantId = merchantId
        self.orderId = orderId
        self.requestId = requestId
        self.amount = amount
        self.currency = currency
        self.expireInMinute = expireInMinute
        self.description = description
        self.orderInfo = orderInfo
        self.bankBin = bankBin
        self.customerInfo = customerInfo
        self.vaAccountNumber = vaAccountNumber
        self.returnUrl = returnUrl
        self.partnerCustomerId = partnerCustomerId
    }
}

// MARK: - Response Model
struct TingeePaymentLinkResponse: Codable {
    let code: String?
    let message: String?
    let data: String?
}

// MARK: - Payment ViewModel
/// ViewModel đảm nhiệm xử lý logic nghiệp vụ thanh toán (tính toán amount, validate, tạo request, và mock gọi mạng).
final class PaymentViewModel {
    
    // MARK: - Outputs (Callbacks)
    var onShowError: ((String) -> Void)?
    var onPresentSDK: ((String) -> Void)?
    var onLoading: ((Bool) -> Void)?
    
    // MARK: - Inputs
    func processPayment(amountText: String?) {
        let trimmedAmount = amountText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard let amount = Int(trimmedAmount), amount > 0 else {
            onShowError?("Vui lòng nhập số tiền thanh toán hợp lệ (lớn hơn 0).")
            return
        }
        
        onLoading?(true)
        
        // 1. Tạo dữ liệu Request
        let request = TingeePaymentLinkRequest(
            merchantId: 01,
            orderId: "INV\(Int(Date().timeIntervalSince1970))",
            amount: amount,
            description: "Thanh toán đơn hàng App",
            orderInfo: "Đơn hàng từ App Mobile",
            bankBin: "970436",
            customerInfo: "Nguyen Van A",
            vaAccountNumber: "VQRQAAUNF0356",
            returnUrl: "tingeemerchant://return",
            partnerCustomerId: "CUS_001"
        )
        
        // 2. Giả lập Backend gọi API lên Tingee để lấy checkoutUrl
        simulateBackendCreateLink(request: request) { [weak self] checkoutUrl in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                if let url = checkoutUrl {
                    // 3. Trả checkoutUrl về cho App để mở SDK Tingee
                    self?.onPresentSDK?(url)
                } else {
                    self?.onShowError?("Không thể tạo link thanh toán từ Backend giả lập.")
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    private func simulateBackendCreateLink(request: TingeePaymentLinkRequest, completion: @escaping (String?) -> Void) {
        let (signature, timestamp) = generateMockSignature(for: request)
        
        guard let url = URL(string: TingeeAppConfig.environment.baseURL + "/v1/payment-gateway/create-link") else {
            completion(nil)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.addValue(TingeeAppConfig.clientId, forHTTPHeaderField: "x-client-id")
        urlRequest.addValue(signature, forHTTPHeaderField: "x-signature")
        urlRequest.addValue(timestamp, forHTTPHeaderField: "x-request-timestamp")
        
        let encoder = JSONEncoder()
        if #available(iOS 13.0, macOS 10.15, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        
        let bodyData = try? encoder.encode(request)
        urlRequest.httpBody = bodyData
        
        // --- LOG REQUEST ---
        print("\n========== [BACKEND MOCK] TINGEE PAY REQUEST ==========")
        print("URL: \(urlRequest.url?.absoluteString ?? "")")
        print("Method: \(urlRequest.httpMethod ?? "")")
        print("Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let bodyData = bodyData, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        print("=======================================================\n")
        // -------------------
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            // --- LOG RESPONSE ---
            print("\n========== [BACKEND MOCK] TINGEE PAY RESPONSE ==========")
            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code: \(httpResponse.statusCode)")
            }
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print("Response Data: \(dataString)")
            }
            print("========================================================\n")
            // --------------------
            
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                let apiResponse = try JSONDecoder().decode(TingeePaymentLinkResponse.self, from: data)
                if apiResponse.code == "00" {
                    completion(apiResponse.data)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    private func generateMockSignature(for request: TingeePaymentLinkRequest) -> (signature: String, timestamp: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmssSSS"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        let timestamp = dateFormatter.string(from: Date())
        
        let encoder = JSONEncoder()
        if #available(iOS 13.0, macOS 10.15, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        
        let payloadData = (try? encoder.encode(request)) ?? Data()
        let payloadString = String(data: payloadData, encoding: .utf8) ?? ""
        
        let dataToSign = "\(timestamp):\(payloadString)"
        let keyData = Data(TingeeAppConfig.secret.utf8)
        let key = SymmetricKey(data: keyData)
        
        let signatureData = HMAC<SHA512>.authenticationCode(for: Data(dataToSign.utf8), using: key)
        let signature = Data(signatureData).map { String(format: "%02x", $0) }.joined()
        
        return (signature, timestamp)
    }
}

final class ViewController: UIViewController {
    
    // MARK: - UI Components
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let amountTextField = UITextField()
    private let payButton = UIButton(type: .system)
    
    private let statusTitleLabel = UILabel()
    private let statusValueLabel = UILabel()
    
    // MARK: - Properties
    private let viewModel = PaymentViewModel()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupBindings()
    }
    
    // MARK: - Setup UI
    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        
        // Tap to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = "Tạo Đơn Hàng"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        amountLabel.text = "Số tiền thanh toán (VND):"
        amountLabel.font = .systemFont(ofSize: 15, weight: .medium)
        amountLabel.textColor = .secondaryLabel
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        amountTextField.placeholder = "VD: 50000"
        amountTextField.keyboardType = .numberPad
        amountTextField.borderStyle = .roundedRect
        amountTextField.font = .systemFont(ofSize: 24, weight: .semibold)
        amountTextField.textAlignment = .right
        amountTextField.text = "50000"
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        
        payButton.setTitle("Thanh toán", for: .normal)
        payButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        payButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
        payButton.setTitleColor(.white, for: .normal)
        payButton.layer.cornerRadius = 12
        payButton.translatesAutoresizingMaskIntoConstraints = false
        payButton.addTarget(self, action: #selector(handlePaymentTapped), for: .touchUpInside)
        
        statusTitleLabel.text = "Trạng thái:"
        statusTitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusTitleLabel.textColor = .secondaryLabel
        statusTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        statusValueLabel.text = "Chưa thanh toán"
        statusValueLabel.font = .systemFont(ofSize: 15, weight: .bold)
        statusValueLabel.textColor = .systemGray
        statusValueLabel.numberOfLines = 0
        statusValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(amountLabel)
        cardView.addSubview(amountTextField)
        cardView.addSubview(payButton)
        cardView.addSubview(statusTitleLabel)
        cardView.addSubview(statusValueLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            amountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            amountLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            amountLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            amountTextField.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 8),
            amountTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            amountTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            amountTextField.heightAnchor.constraint(equalToConstant: 56),
            
            payButton.topAnchor.constraint(equalTo: amountTextField.bottomAnchor, constant: 32),
            payButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            payButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            payButton.heightAnchor.constraint(equalToConstant: 56),
            
            statusTitleLabel.topAnchor.constraint(equalTo: payButton.bottomAnchor, constant: 24),
            statusTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            
            statusValueLabel.topAnchor.constraint(equalTo: statusTitleLabel.topAnchor),
            statusValueLabel.leadingAnchor.constraint(equalTo: statusTitleLabel.trailingAnchor, constant: 8),
            statusValueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            statusValueLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Setup Bindings (MVVM)
    private func setupBindings() {
        viewModel.onShowError = { [weak self] errorMessage in
            let alert = UIAlertController(title: "Lỗi", message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .default))
            self?.present(alert, animated: true)
        }
        
        viewModel.onLoading = { [weak self] isLoading in
            self?.payButton.isEnabled = !isLoading
            self?.payButton.setTitle(isLoading ? "Đang xử lý..." : "Thanh toán", for: .normal)
            self?.payButton.alpha = isLoading ? 0.6 : 1.0
        }
        
        viewModel.onPresentSDK = { [weak self] checkoutUrlString in
            guard let self = self, let url = URL(string: checkoutUrlString) else { return }
            TingeePay.presentCheckout(
                from: self,
                checkoutUrl: url,
                style: .bottomSheet,
                delegate: self
            )
        }
    }
    
    // MARK: - Actions
    @objc private func handlePaymentTapped() {
        dismissKeyboard()
        viewModel.processPayment(amountText: amountTextField.text)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - TingeePayCheckoutDelegate
extension ViewController: TingeePayCheckoutDelegate {
    
    func tingeePayCheckoutDidFinish(with result: TingeePaymentResult) {
        var message = ""
        var color: UIColor = .systemGray
        
        switch result.status {
        case .success:
            message = "Thành công (Mã: \(result.orderId ?? ""))"
            color = .systemGreen
        case .failed:
            message = "Thất bại (\(result.errorMessage ?? ""))"
            color = .systemRed
        case .expired:
            message = "Đã hết hạn"
            color = .systemOrange
        case .error:
            message = "Lỗi hệ thống"
            color = .systemRed
        case .cancelled:
            message = "Đã huỷ"
            color = .systemGray
        case .unknown:
            message = "Không xác định"
            color = .systemGray
        }
        
        DispatchQueue.main.async {
            self.statusValueLabel.text = message
            self.statusValueLabel.textColor = color
        }
        
        print("✅ [Client App] Nhận kết quả từ SDK: \(message)")
        
        let alert = UIAlertController(title: "Kết quả", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    func tingeePayCheckoutDidCancel() {
        print("❌ [Client App] SDK báo: Người dùng đóng màn hình thanh toán")
    }
    
    func tingeePayCheckoutDidFail(with error: Error) {
        print("⚠️ [Client App] SDK báo lỗi nội bộ: \(error.localizedDescription)")
    }
}
