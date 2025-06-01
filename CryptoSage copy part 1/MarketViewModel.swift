//
//  MarketViewModel.swift
//  CryptoSage
//
//  Created by DM on 6/1/25.
//

import Foundation
import SwiftUI
import Combine


// MARK: - MarketViewModel

final class MarketViewModel: ObservableObject {
    
    static let shared = MarketViewModel()
    
    // MARK: Published properties
    @Published private(set) var coins: [MarketCoin] = []
    @Published private(set) var watchlistCoins: [MarketCoin] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String? = nil
    
    @Published private var favoriteIDs: Set<String> = []
    
    // Disk cache URLs
    private let coinsCacheURL: URL
    private let watchlistCacheURL: URL
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        coinsCacheURL = docs.appendingPathComponent("coins_cache.json")
        watchlistCacheURL = docs.appendingPathComponent("watchlist_cache.json")
        
        // Load saved favorites
        if let saved = UserDefaults.standard.array(forKey: "FavoriteCoinIDs") as? [String] {
            favoriteIDs = Set(saved)
        }
        
        // Load any cached data immediately (no spinner for cache load)
        loadCoinsFromCache()
        loadWatchlistFromCache()
        
        // Then fetch fresh data
        fetchCoinMarkets()
        fetchWatchlistMarkets()
    }
    
    // MARK: - Public methods
    
    /// Fetch top 100 coins by market cap (with sparkline + price change %)
    func fetchCoinMarkets() {
        isLoading = true
        loadError = nil
        
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "true"),
            URLQueryItem(name: "price_change_percentage", value: "1h,24h")
        ]
        guard let url = components.url else {
            isLoading = false
            loadError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("CryptoSageApp/1.0", forHTTPHeaderField: "User-Agent")
        print("MarketViewModel: Fetching coin markets from → \(url.absoluteString)")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        URLSession.shared.dataTaskPublisher(for: request)
            // Apply timeout on a background queue
            .timeout(.seconds(15), scheduler: DispatchQueue.global())
            // Check status code
            .tryMap { data, response -> Data in
                if let http = response as? HTTPURLResponse {
                    print("MarketViewModel: HTTP status code → \(http.statusCode)")
                    guard 200..<300 ~= http.statusCode else {
                        throw URLError(.badServerResponse)
                    }
                }
                return data
            }
            // Decode JSON
            .decode(type: [MarketCoin].self, decoder: decoder)
            // Switch to main thread for UI updates
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                switch completion {
                case .finished:
                    print("MarketViewModel: Successfully fetched coin markets.")
                case .failure(let error):
                    print("MarketViewModel: Error fetching markets → \(error.localizedDescription)")
                    self.loadError = "Failed to load market data"
                    // Fallback to empty array so UI isn’t empty
                    self.coins = []
                }
            }, receiveValue: { [weak self] fetchedCoins in
                guard let self = self else { return }
                // Mark favorites
                let enriched = fetchedCoins.map { coin -> MarketCoin in
                    var c = coin
                    c.isFavorite = self.favoriteIDs.contains(coin.id)
                    return c
                }
                self.coins = enriched
                self.saveCoinsToCache(enriched)
            })
            .store(in: &cancellables)
    }
    
    /// Fetch only the coins the user has favorited (watchlist)
    func fetchWatchlistMarkets() {
        isLoading = true
        loadError = nil
        
        let ids = favoriteIDs.joined(separator: ",")
        guard !ids.isEmpty else {
            // No favorites → clear watchlist & stop loading
            watchlistCoins = []
            isLoading = false
            try? FileManager.default.removeItem(at: watchlistCacheURL)
            return
        }
        
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "ids", value: ids),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "sparkline", value: "true"),
            URLQueryItem(name: "price_change_percentage", value: "1h,24h")
        ]
        guard let url = components.url else {
            isLoading = false
            loadError = "Invalid Watchlist URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("CryptoSageApp/1.0", forHTTPHeaderField: "User-Agent")
        print("MarketViewModel: Fetching watchlist from → \(url.absoluteString)")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        URLSession.shared.dataTaskPublisher(for: request)
            .timeout(.seconds(15), scheduler: DispatchQueue.global())
            .tryMap { data, response -> Data in
                if let http = response as? HTTPURLResponse {
                    print("MarketViewModel: Watchlist HTTP status → \(http.statusCode)")
                    guard 200..<300 ~= http.statusCode else {
                        throw URLError(.badServerResponse)
                    }
                }
                return data
            }
            .decode(type: [MarketCoin].self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    print("MarketViewModel: Error fetching watchlist → \(error.localizedDescription)")
                    self.loadError = "Failed to load watchlist"
                }
            }, receiveValue: { [weak self] fetchedWatchlist in
                guard let self = self else { return }
                let enriched = fetchedWatchlist.map { coin -> MarketCoin in
                    var c = coin
                    c.isFavorite = true
                    return c
                }
                self.watchlistCoins = enriched
                self.saveWatchlistToCache(enriched)
            })
            .store(in: &cancellables)
    }
    
    /// Toggle a coin’s “favorite” status. Updates both in-memory and UserDefaults.
    func toggleFavorite(_ coin: MarketCoin) {
        if favoriteIDs.contains(coin.id) {
            favoriteIDs.remove(coin.id)
        } else {
            favoriteIDs.insert(coin.id)
        }
        // Persist to UserDefaults
        UserDefaults.standard.set(Array(favoriteIDs), forKey: "FavoriteCoinIDs")
        
        // Update coins’ isFavorite flags
        coins = coins.map { c in
            var c2 = c
            c2.isFavorite = favoriteIDs.contains(c.id)
            return c2
        }
        
        // Re-fetch watchlist (or clear it if no favorites remain)
        fetchWatchlistMarkets()
    }
    
    /// Check if a coin is currently in the favorites set
    func isFavorite(_ coin: MarketCoin) -> Bool {
        return favoriteIDs.contains(coin.id)
    }
    
    // MARK: - Disk Caching
    
    private func saveCoinsToCache(_ coins: [MarketCoin]) {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(coins)
            try data.write(to: coinsCacheURL, options: .atomic)
        } catch {
            print("MarketViewModel: Failed to write coins to cache:", error)
        }
    }
    
    private func loadCoinsFromCache() {
        guard FileManager.default.fileExists(atPath: coinsCacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: coinsCacheURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode([MarketCoin].self, from: data)
            let enriched = decoded.map { coin -> MarketCoin in
                var c = coin
                c.isFavorite = favoriteIDs.contains(coin.id)
                return c
            }
            DispatchQueue.main.async {
                self.coins = enriched
            }
        } catch {
            print("MarketViewModel: Failed to load coins from cache:", error)
        }
    }
    
    private func saveWatchlistToCache(_ coins: [MarketCoin]) {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(coins)
            try data.write(to: watchlistCacheURL, options: .atomic)
        } catch {
            print("MarketViewModel: Failed to write watchlist to cache:", error)
        }
    }
    
    private func loadWatchlistFromCache() {
        guard FileManager.default.fileExists(atPath: watchlistCacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: watchlistCacheURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode([MarketCoin].self, from: data)
            DispatchQueue.main.async {
                self.watchlistCoins = decoded
            }
        } catch {
            print("MarketViewModel: Failed to load watchlist from cache:", error)
        }
    }
}

// MARK: - Computed subsets

extension MarketViewModel {
    /// Top 10 by 24h price-change (descending)
    var topGainers: [MarketCoin] {
        coins
            .sorted(by: { ($0.priceChangePercentage24h ?? 0) > ($1.priceChangePercentage24h ?? 0) })
            .prefix(10)
            .map { $0 }
    }

    /// Top 10 by 24h price-change (ascending)
    var topLosers: [MarketCoin] {
        coins
            .sorted(by: { ($0.priceChangePercentage24h ?? 0) < ($1.priceChangePercentage24h ?? 0) })
            .prefix(10)
            .map { $0 }
    }

    /// Top 10 by total volume (descending) – “Trending”
    var trending: [MarketCoin] {
        coins
            .sorted(by: { ($0.totalVolume ?? 0) > ($1.totalVolume ?? 0) })
            .prefix(10)
            .map { $0 }
    }
}
