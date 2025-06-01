//
//  AIInsightsViewModel.swift
//  CryptoSage
//
//  Created by DM on 5/31/25.
//

import SwiftUI
import Combine

final class AIInsightsViewModel: ObservableObject {
    // MARK: - Published properties for each section
    @Published var summaryMetrics: [SummaryMetric] = []
    @Published var performanceData: [PerformancePoint] = []
    @Published var contributors: [Contributor] = []
    @Published var tradeQualityData: TradeQualityData?
    @Published var diversificationData: DiversificationData?
    @Published var momentumData: MomentumData?
    @Published var feeData: FeeData?

    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil

    // Section‐expanded state (optional)
    @Published var isPerformanceExpanded = false
    @Published var isQualityExpanded = false
    @Published var isDiversificationExpanded = false
    @Published var isMomentumExpanded = false
    @Published var isFeeExpanded = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchAllInsights()
    }

    func fetchAllInsights() {
        isLoading = true
        errorMessage = nil

        // Example: Simulate a network/AI call with a 1-second delay
        Just(())
            .delay(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                // 1) Summary metrics
                self.summaryMetrics = [
                    SummaryMetric(iconName: "chart.line.uptrend.xyaxis", valueText: "8%",   title: "vs BTC"),
                    SummaryMetric(iconName: "shield.fill",               valueText: "7/10", title: "Risk Score"),
                    SummaryMetric(iconName: "rosette",                   valueText: "75%",  title: "Win Rate")
                ]

                // 2) Performance points (last 30 days, reversed so oldest is first)
                self.performanceData = (0..<30).map { i in
                    PerformancePoint(
                        date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                        value: Double.random(in: 90_000 ... 110_000)
                    )
                }
                .reversed()

                // 3) Contributors (replace with real AI-computed values later)
                self.contributors = [
                    Contributor(name: "BTC", contributionPct: 0.40),
                    Contributor(name: "ETH", contributionPct: 0.30),
                    Contributor(name: "SOL", contributionPct: 0.15),
                    Contributor(name: "ADA", contributionPct: 0.15)
                ]

                // 4) Trade quality data
                self.tradeQualityData = TradeQualityData(
                    bestTrade: Trade(symbol: "SOL", profitPct: 12.3),
                    worstTrade: Trade(symbol: "DOGE", profitPct: -8.5),
                    distributionBuckets: [0, 0, 1, 3, 5, 2, 1]
                )

                // 5) Diversification data (example weights)
                self.diversificationData = DiversificationData(
                    assetWeights: [
                        AssetWeight(symbol: "BTC", weight: 0.50),
                        AssetWeight(symbol: "ETH", weight: 0.30),
                        AssetWeight(symbol: "SOL", weight: 0.20)
                    ]
                )

                // 6) Momentum strategies
                self.momentumData = MomentumData(
                    strategies: [
                        StrategyMomentum(symbol: "Trend Follow",    score: 0.70),
                        StrategyMomentum(symbol: "Mean Reversion",  score: 0.40),
                        StrategyMomentum(symbol: "Breakout",        score: 0.60)
                    ]
                )

                // 7) Fee breakdown
                self.feeData = FeeData(
                    fees: [
                        FeeItem(symbol: "Network Fees", feePct: 0.015),
                        FeeItem(symbol: "Slippage",      feePct: 0.005)
                    ]
                )

                self.isLoading = false
            }
            .store(in: &cancellables)
    }
}
