import SwiftUI
// MARK: - Price Alert Model

struct PriceAlert: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let threshold: Double
    let isAbove: Bool
    let enablePush: Bool
    let enableEmail: Bool
    let enableTelegram: Bool

    init(id: UUID = UUID(),
         symbol: String,
         threshold: Double,
         isAbove: Bool,
         enablePush: Bool,
         enableEmail: Bool,
         enableTelegram: Bool) {
        self.id = id
        self.symbol = symbol
        self.threshold = threshold
        self.isAbove = isAbove
        self.enablePush = enablePush
        self.enableEmail = enableEmail
        self.enableTelegram = enableTelegram
    }
}

// MARK: - AI Insight Models

/// Represents a contributor (e.g., top-performing holding or asset) for performance attribution.
struct Contributor: Identifiable {
    let id: UUID = UUID()
    let name: String         // e.g., "BTC"
    let contributionPct: Double  // e.g., 0.25 for 25%
}

/// Represents a single trade for quality analysis.
struct Trade {
    let symbol: String
    let profitPct: Double
}

/// Captures best and worst trade information plus P/L distribution for trade quality analysis.
struct TradeQualityData {
    let bestTrade: Trade
    let worstTrade: Trade
    let distributionBuckets: [Int]
}

/// Represents a single asset and its weight for diversification.
struct AssetWeight {
    let symbol: String
    let weight: Double
}

/// Represents diversification breakdown for portfolio risk analysis.
struct DiversificationData {
    let assetWeights: [AssetWeight]
}

/// Represents a strategy's momentum score.
struct StrategyMomentum {
    let symbol: String
    let score: Double
}

/// Contains momentum scores for various assets.
struct MomentumData {
    let strategies: [StrategyMomentum]
}

/// Represents a fee item for an asset or trade category.
struct FeeItem {
    let symbol: String
    let feePct: Double
}

/// Fee-related data for each asset or trade category.
struct FeeData {
    let fees: [FeeItem]
}


import Foundation

// MARK: - Coin Models

struct CoinGeckoCoin: Identifiable, Codable {
    let id: String
    let symbol: String
    let name: String?
    let image: String?
    let current_price: Double?
    
    let market_cap: Double?
    let market_cap_rank: Int?
    let total_volume: Double?
    let high_24h: Double?
    let low_24h: Double?
    let price_change_24h: Double?
    let price_change_percentage_24h: Double?
    let price_change_percentage_1h_in_currency: Double?
    
    let fully_diluted_valuation: Double?
    let circulating_supply: Double?
    let total_supply: Double?
    let ath: Double?
    let ath_change_percentage: Double?
    let ath_date: String?
    let atl: Double?
    let atl_change_percentage: Double?
    let atl_date: String?
    let last_updated: String?
    
    // For trending endpoint
    let coin_id: Int?
    let thumb: String?
    let small: String?
    let large: String?
    let slug: String?
}

struct TrendingResponse: Codable {
    let coins: [TrendingCoinItem]
}

struct TrendingCoinItem: Codable {
    let item: CoinGeckoCoin
}

// MARK: - Chat Message Model

/// Represents a single chat message from either the user or the AI.
struct ChatMessage: Identifiable, Codable {
    var id: UUID = UUID()
    var sender: String   // "user" or "ai"
    var text: String
    var timestamp: Date = Date()
    var isError: Bool = false
}

// MARK: - Portfolio Models

/// Represents a cryptocurrency holding in the portfolio.
struct Holding: Identifiable, Codable, Equatable {  // Conforms to Equatable
    var id: UUID = UUID()
    var coinName: String
    var coinSymbol: String
    var quantity: Double
    var currentPrice: Double
    var costBasis: Double
    var imageUrl: String?
    var isFavorite: Bool
    var dailyChange: Double
    /// Percentage change over the last 24 hours.
    var dailyChangePercent: Double {
        dailyChange
    }
    var purchaseDate: Date

    /// The current value of this holding.
    var currentValue: Double {
        return quantity * currentPrice
    }
    
    /// The profit or loss for this holding.
    var profitLoss: Double {
        return (currentPrice - costBasis) * quantity
    }
}

/// Unified Transaction model used in the app to represent both manual and exchange transactions.
struct Transaction: Identifiable, Codable {
    /// Unique identifier for the transaction.
    let id: UUID
    /// The symbol of the cryptocurrency (e.g., "BTC").
    let coinSymbol: String
    /// The quantity of cryptocurrency transacted.
    let quantity: Double
    /// The price per coin at the time of the transaction.
    let pricePerUnit: Double
    /// The date when the transaction occurred.
    let date: Date
    /// Indicates whether this is a buy transaction (true) or a sell (false).
    let isBuy: Bool
    /// Flag indicating if this transaction was manually entered (true) or synced from an exchange/wallet (false).
    let isManual: Bool
    
    /// Initializes a new Transaction.
    /// - Parameters:
    ///   - id: A unique identifier (defaults to a new UUID).
    ///   - coinSymbol: The cryptocurrency symbol.
    ///   - quantity: The quantity of cryptocurrency transacted.
    ///   - pricePerUnit: The price per coin at the time of the transaction.
    ///   - date: The transaction date.
    ///   - isBuy: True for a buy transaction, false for a sell.
    ///   - isManual: True if the transaction is user-entered, false if it’s synced (defaults to true).
    init(id: UUID = UUID(), coinSymbol: String, quantity: Double, pricePerUnit: Double, date: Date, isBuy: Bool, isManual: Bool = true) {
        self.id = id
        self.coinSymbol = coinSymbol
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.date = date
        self.isBuy = isBuy
        self.isManual = isManual
    }
}

extension CoinGeckoCoin {
    /// Returns the 1H percentage change, defaulting to 0.0 if nil
    var change1h: Double {
        return price_change_percentage_1h_in_currency ?? 0.0
    }
    
    /// Returns the 24H percentage change, defaulting to 0.0 if nil
    var change24h: Double {
        return price_change_percentage_24h ?? 0.0
    }
}

// MARK: - Allocation Slice Model

/// Represents a single slice of the portfolio pie chart.
struct AllocationSlice: Identifiable {
    /// Unique identifier for SwiftUI lists.
    let id: UUID = UUID()
    /// Symbol for the coin (e.g., "BTC").
    let symbol: String
    /// Percentage of the total portfolio (0.0–1.0).
    let percent: Double
    /// Display color for this slice.
    let color: Color

    /// Initialize with symbol, percent, and color.
    init(symbol: String, percent: Double, color: Color) {
        self.symbol = symbol
        self.percent = percent
        self.color = color
    }
}

import Foundation

/// Represents a single data point for performance over time.
struct PerformancePoint: Identifiable {
    let id: Date
    let date: Date
    let value: Double

    init(date: Date, value: Double) {
        self.id = date
        self.date = date
        self.value = value
    }
}
