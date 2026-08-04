import Foundation

enum Endpoints {
    static let repository = "https://github.com/salasebas/altab"
    static let website = repository
    static let issuesUrl = "\(repository)/issues"
    static let feedbackUrl = "\(issuesUrl)/new/choose"
    static let supportUrl = "https://github.com/sponsors/salasebas"
    static let domain = Bundle.main.object(forInfoDictionaryKey: "Domain") as! String
    static let apiDomain = Bundle.main.object(forInfoDictionaryKey: "ApiDomain") as! String
    static let serviceUrl = "https://\(domain)"
    static let checkoutUrl = "\(serviceUrl)/pricing"
    static let accountUrl = "\(serviceUrl)/my-account"
    static let licenseApiBaseUrl = "https://\(apiDomain)/v1/license"
}
