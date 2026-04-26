import Foundation

/// Insight aksiyonu `redirect` tipinde olduğunda SDK'nın çağırdığı delegate.
///
/// Kullanım (AppDelegate veya root coordinator'da):
/// ```swift
/// AppInsight.shared.redirectionDelegate = self
/// ```
///
/// Implementasyon örneği:
/// ```swift
/// extension HomeViewController: AppInsightRedirectionDelegate {
///     func appInsight(didRequestRedirectionTo pageCode: Int, params: [String: Any]) {
///         guard let page = RedirectionPageModel(rawValue: pageCode) else { return }
///         startRedirection(for: page)
///     }
/// }
/// ```
public protocol AppInsightRedirectionDelegate: AnyObject {
    /// `redirect` aksiyonlu bir insight'a kullanıcı tıkladığında çağrılır.
    /// - Parameters:
    ///   - pageCode: Portal'da tanımlanan sayfa kodu (RedirectionPageModel raw value).
    ///   - params:   Sayfaya özgü parametreler (ör: `["contractCode": "12345"]`).
    func appInsight(didRequestRedirectionTo pageCode: Int, params: [String: Any])
}
