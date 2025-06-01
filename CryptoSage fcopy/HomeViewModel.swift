//
//  HomeViewModel.swift
//  CryptoSage
//
//  ViewModel to provide data for Home screen: portfolio, news, heatmap, market overview.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Child ViewModels
    @Published var portfolioVM: PortfolioViewModel
    @Published var newsVM      = CryptoNewsFeedViewModel()
    @Published var heatMapVM   = HeatMapViewModel()

    // Published market slices for UI sections
    @Published var liveCoins: [MarketCoin] = []
    @Published var liveWatchlist: [MarketCoin] = []
    @Published var liveTopGainers: [MarketCoin] = []
    @Published var liveTopLosers: [MarketCoin] = []
    @Published var liveTrending: [MarketCoin] = []

    // Shared Market ViewModel (injected at creation)
    let marketVM: MarketViewModel
    private var cancellables = Set<AnyCancellable>()

    init() {
        let manualService = ManualPortfolioDataService()
        let liveService   = LivePortfolioDataService()
        let priceService  = CoinGeckoPriceService()
        let repository    = PortfolioRepository(
            manualService: manualService,
            liveService:   liveService,
            priceService:  priceService
        )
        _portfolioVM = Published(initialValue: PortfolioViewModel(repository: repository))
        self.marketVM = MarketViewModel.shared

        // Bind MarketViewModel's published arrays
        marketVM.$coins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allCoins in
                guard let self = self else { return }
                self.liveCoins = allCoins
                self.computeDerivedArrays(from: allCoins)
            }
            .store(in: &cancellables)

        marketVM.$watchlistCoins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] watchlist in
                self?.liveWatchlist = watchlist
            }
            .store(in: &cancellables)

        // Load market data on startup
        Task {
            marketVM.fetchCoinMarkets()
            marketVM.fetchWatchlistMarkets()
            await newsVM.loadPreviewNews()
        }
    }

    init(marketVM: MarketViewModel) {
        let manualService = ManualPortfolioDataService()
        let liveService   = LivePortfolioDataService()
        let priceService  = CoinGeckoPriceService()
        let repository    = PortfolioRepository(
            manualService: manualService,
            liveService:   liveService,
            priceService:  priceService
        )
        _portfolioVM = Published(initialValue: PortfolioViewModel(repository: repository))
        self.marketVM = marketVM

        // Bind MarketViewModel's published arrays
        marketVM.$coins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allCoins in
                guard let self = self else { return }
                self.liveCoins = allCoins
                self.computeDerivedArrays(from: allCoins)
            }
            .store(in: &cancellables)

        marketVM.$watchlistCoins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] watchlist in
                self?.liveWatchlist = watchlist
            }
            .store(in: &cancellables)

        // Load market data on startup
        Task {
            self.marketVM.fetchCoinMarkets()
            self.marketVM.fetchWatchlistMarkets()
            await newsVM.loadPreviewNews()
        }
    }

    // MARK: - Market Data Fetching
    private func computeDerivedArrays(from allCoins: [MarketCoin]) {
        // Top Gainers: sort by 24h change descending, take top 10
        liveTopGainers = allCoins
            .sorted(by: { $0.priceChangePercentage24h > $1.priceChangePercentage24h })
            .prefix(10)
            .map { $0 }

        // Top Losers: sort by 24h change ascending, take top 10
        liveTopLosers = allCoins
            .sorted(by: { $0.priceChangePercentage24h < $1.priceChangePercentage24h })
            .prefix(10)
            .map { $0 }

        // Trending: sort by total volume descending, take top 10
        liveTrending = allCoins
            .sorted(by: { $0.totalVolume > $1.totalVolume })
            .prefix(10)
            .map { $0 }
    }

    /// If you need a manual refresh:
    func reloadHomeData() {
        marketVM.fetchCoinMarkets()
        marketVM.fetchWatchlistMarkets()
    }

    /// Heatmap data (tiles & weights)
    var heatMapTiles: [HeatMapTile] {
        heatMapVM.tiles
    }
    var heatMapWeights: [Double] {
        heatMapVM.weights()
    }
}
