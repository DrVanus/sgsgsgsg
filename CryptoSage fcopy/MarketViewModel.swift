//
//  MarketViewModel.swift
//  CryptoSage
//
//  Created by DM on 6/1/25.
//  Completely rewritten to match CoinRowView.swift’s expectations.
//

import Foundation
import SwiftUI
import Combine


// MARK: - MarketViewModel
final class MarketViewModel: ObservableObject {
    
    static let shared = MarketViewModel()
    
    // Published arrays
    @Published private(set) var coins: [MarketCoin] = []
    @Published private(set) var watchlistCoins: [MarketCoin] = []
    
    // A set of favorite coin-IDs (persisted in UserDefaults)
    @Published private var favoriteIDs: Set<String> = []
    
    // Disk‐cache URLs
    private let coinsCacheURL: URL
    private let watchlistCacheURL: URL
    
    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Build “Documents/coins_cache.json” and “Documents/watchlist_cache.json”
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        coinsCacheURL = docs.appendingPathComponent("coins_cache.json")
        watchlistCacheURL = docs.appendingPathComponent("watchlist_cache.json")
        
        // Load favorites from UserDefaults (if any)
        if let saved = UserDefaults.standard.array(forKey: "FavoriteCoinIDs") as? [String] {
            favoriteIDs = Set(saved)
        }
        
        // Try loading from disk right away (so UI can show cached data instantly)
        loadCoinsFromCache()
        loadWatchlistFromCache()
        
        // Immediately fetch fresh data
        fetchCoinMarkets()
        fetchWatchlistMarkets()
    }
    
    // MARK: - Public API
    
    /// Call to reload all coins (top 100 by market cap, with sparkline)
    func fetchCoinMarkets() {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let urlString = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=true&price_change_percentage=1h,24h"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [MarketCoin].self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    // On failure, do nothing – we've already loaded from cache in init
                    print("MarketViewModel: Failed to fetchCoinMarkets(); using cached data.")
                }
            }, receiveValue: { [weak self] fetchedCoins in
                guard let self = self else { return }
                // Inject favorites into the coins array
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
    
    /// Call to reload just the watchlist coins (you’ll pass it a comma-separated list of IDs)
    func fetchWatchlistMarkets() {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let ids = favoriteIDs.joined(separator: ",")
        guard !ids.isEmpty else {
            // No favorites → empty watchlist
            self.watchlistCoins = []
            // Also clear out any stale watchlist cache
            try? FileManager.default.removeItem(at: watchlistCacheURL)
            return
        }
        
        let urlString = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=\(ids)&order=market_cap_desc&sparkline=true&price_change_percentage=1h,24h"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [MarketCoin].self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    print("MarketViewModel: Failed to fetchWatchlistMarkets(); using cached watchlist.")
                }
            }, receiveValue: { [weak self] fetched in
                guard let self = self else { return }
                let enriched = fetched.map { coin -> MarketCoin in
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
            // Re‐inject favorites into the cached coins
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
            .sorted(by: { $0.priceChangePercentage24h > $1.priceChangePercentage24h })
            .prefix(10)
            .map { $0 }
    }

    /// Top 10 by 24h price-change (ascending)
    var topLosers: [MarketCoin] {
        coins
            .sorted(by: { $0.priceChangePercentage24h < $1.priceChangePercentage24h })
            .prefix(10)
            .map { $0 }
    }

    /// Top 10 by total volume (descending) – “Trending”
    var trending: [MarketCoin] {
        coins
            .sorted(by: { $0.totalVolume > $1.totalVolume })
            .prefix(10)
            .map { $0 }
    }
}
