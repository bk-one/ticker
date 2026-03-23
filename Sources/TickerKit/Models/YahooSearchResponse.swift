import Foundation

struct YahooSearchEnvelope: Decodable {
    let quotes: [YahooSearchQuotePayload]
}

struct YahooSearchQuotePayload: Decodable {
    let symbol: String?
    let shortName: String?
    let longName: String?
    let quoteType: String?
    let typeDisplayName: String?
    let exchangeCode: String?
    let exchangeDisplayName: String?
    let isYahooFinance: Bool?

    enum CodingKeys: String, CodingKey {
        case symbol
        case shortName = "shortname"
        case longName = "longname"
        case quoteType
        case typeDisplayName = "typeDisp"
        case exchangeCode = "exchange"
        case exchangeDisplayName = "exchDisp"
        case isYahooFinance
    }
}
