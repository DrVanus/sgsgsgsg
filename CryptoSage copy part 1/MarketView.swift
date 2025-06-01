import SwiftUI

struct MarketView: View {
    @EnvironmentObject var marketVM: MarketViewModel

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    // Table column headers
                    columnHeader

                    // Content
                    if marketVM.isLoading {
                        loadingView
                    } else if let errorMsg = marketVM.loadError {
                        VStack {
                            Text(errorMsg)
                                .foregroundColor(.white)
                                .padding(.top, 40)
                            Button("Retry") {
                                marketVM.fetchCoinMarkets()
                                marketVM.fetchWatchlistMarkets()
                            }
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if marketVM.coins.isEmpty {
                        emptyOrErrorView
                    } else {
                        coinList
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            Task {
                marketVM.fetchCoinMarkets()
                marketVM.fetchWatchlistMarkets()
            }
        }
    }

    // MARK: - Subviews

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("Coin")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 140, alignment: .leading)
            Text("7D")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 40, alignment: .trailing)
            Text("Price")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 70, alignment: .trailing)
            Text("24h")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 50, alignment: .trailing)
            Text("Vol")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 70, alignment: .trailing)
            Text("Fav")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 40, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
    }

    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Shows either an error view with retry button or a placeholder text.
    private var emptyOrErrorView: some View {
        return AnyView(
            Text("No coins available.")
                .foregroundColor(.gray)
                .padding(.top, 40)
        )
    }

    private var coinList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(marketVM.coins, id: \.id) { coin in
                    NavigationLink(destination: CoinDetailView(coin: coin)) {
                        CoinRowView(coin: coin)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 16)
                } // end of ForEach
            }
            .padding(.bottom, 12)
        }
        .refreshable {
            marketVM.fetchCoinMarkets()
        }
    }

    // MARK: - Helpers

    private func headerButton(_ label: String, _ field: SortField) -> some View {
        // Button {
        //     // marketVM.toggleSort(for: field)
        // } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                // if marketVM.sortField == field {
                //     Image(systemName: marketVM.sortDirection == .asc ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                //         .font(.system(size: 8, weight: .bold))
                //         .foregroundColor(.white.opacity(0.8))
                // }
            }
        // }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
    }
}

#if DEBUG
struct MarketView_Previews: PreviewProvider {
    static var marketVM = MarketViewModel.shared
    static var previews: some View {
        MarketView()
            .environmentObject(marketVM)
    }
}
#endif

// Restore volume formatting helper
extension Double {
    func formattedWithAbbreviations() -> String {
        let absValue = abs(self)
        switch absValue {
        case 1_000_000_000_000...:
            return String(format: "%.1fT", self / 1_000_000_000_000)
        case 1_000_000_000...:
            return String(format: "%.1fB", self / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", self / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", self / 1_000)
        default:
            return String(format: "%.0f", self)
        }
    }
}
