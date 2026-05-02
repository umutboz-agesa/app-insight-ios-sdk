import UIKit

/// SDK üye (UI element) kayıt namespace'i.
///
/// Kullanım:
/// ```swift
/// // viewDidLoad'da
/// AppInsight.shared.member.setInput(katkiPayiTextField, key: "sale_saving_calculation_key")
/// ```
///
/// İleride yeni element tipleri için:
/// ```swift
/// AppInsight.shared.member.setMethod(...)
/// ```
public final class AppInsightMemberRegistry {

    private unowned let sdk: AppInsight

    init(sdk: AppInsight) {
        self.sdk = sdk
    }

    // MARK: - setInput

    /// Bir `UITextField`'ı verilen key ile SDK'ya kaydeder.
    ///
    /// Çağrıldığında:
    /// 1. Weak ref ile saklanır (VC deallocate olunca otomatik temizlenir).
    /// 2. Backend'e `member_register` WS mesajı gönderilir.
    /// 3. Portal'de bu key seçilerek `set_value` action oluşturulabilir.
    ///
    /// - Parameters:
    ///   - textField: Kayıt edilecek input alanı.
    ///   - key: Portal'de görünecek benzersiz anahtar (ör: "sale_saving_calculation_key").
    ///   - screen: Opsiyonel ekran sınıf adı; `nil` ise responder chain'den türetilir.
    public func setInput(_ textField: UITextField, key: String, screen: String? = nil) {
        let screenName = screen ?? sdk._deriveScreenName(from: textField)
        sdk._registerInput(textField, key: key, screen: screenName)
    }
}
