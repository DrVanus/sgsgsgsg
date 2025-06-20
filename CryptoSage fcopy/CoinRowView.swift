//
//  CoinRowView.swift
//  CryptoSage
//
//  Created by DM on 5/25/25.
//


import SwiftUI

/// A reusable row view for displaying a single coin in a list.
struct CoinRowView: View {
    let coin: MarketCoin
    @EnvironmentObject var marketVM: MarketViewModel

    // Constants for layout
    private let starWidth: CGFloat      = 30

    private var formattedPrice: String {
        if coin.currentPrice >= 1_000 {
            let intPrice = Int(coin.currentPrice.rounded())
            return "$" + NumberFormatter.localizedString(from: NSNumber(value: intPrice), number: .decimal)
        } else {
            return String(format: "$%.2f", coin.currentPrice)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // 1) Coin icon + symbol/name (flexible width)
            HStack(spacing: 8) {
                CoinImageView(symbol: coin.symbol, urlStr: coin.image, size: 32)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.symbol.uppercased())
                        .font(.subheadline).bold()
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(coin.name)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .layoutPriority(2)
            }
            .padding(.leading, 12)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            // 2) Sparkline column
            Group {
                if let prices = coin.sparkline7d?.price, prices.count > 1 {
                    SparklineView(
                        data: prices,
                        isPositive: (coin.priceChangePercentage24hInCurrency ?? 0) >= 0
                    )
                    .frame(minWidth: 40, maxWidth: 80, minHeight: 30, maxHeight: 30)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(minWidth: 40, maxWidth: 80, minHeight: 30, maxHeight: 30)
                }
            }
            .padding(.horizontal, 4)

            // 3) Price column
            Text(formattedPrice)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .frame(minWidth: 60, alignment: .trailing)

            // 4) 24h change column
            let change24h = coin.priceChangePercentage24hInCurrency ?? 0
            Text(String(format: "%@%.2f%%", change24h >= 0 ? "+" : "", change24h))
                .font(.caption)
                .foregroundColor(change24h >= 0 ? .green : .red)
                .animation(.easeInOut, value: change24h)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .frame(minWidth: 50, alignment: .trailing)
                .padding(.horizontal, 4)

            // 5) Volume column
            Text(coin.totalVolume.formattedWithAbbreviations())
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .frame(minWidth: 60, alignment: .trailing)
                .padding(.horizontal, 4)

            // 6) Favorite star column
            Button {
                marketVM.toggleFavorite(coin)
            } label: {
                Image(systemName: marketVM.isFavorite(coin) ? "star.fill" : "star")
                    .foregroundColor(marketVM.isFavorite(coin) ? .yellow : .white.opacity(0.6))
            }
            .frame(width: starWidth, height: 32)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .background(Color.black)
    }
}

// MARK: - Previews and Sample Data

extension MarketCoin {
    static var sample: MarketCoin {
        MarketCoin(
            id: "bitcoin",
            symbol: "btc",
            name: "Bitcoin",
            image: "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
            price: 50000,
            dailyChange: 2.0,
            volume: 35_000_000_000,
            marketCap: 900_000_000_000,
            isFavorite: true
        )
    }
}

#if DEBUG
struct CoinRowView_Previews: PreviewProvider {
    static var previews: some View {
        CoinRowView(coin: .sample)
            .environmentObject(MarketViewModel.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.black)
    }
}
#endif
  
