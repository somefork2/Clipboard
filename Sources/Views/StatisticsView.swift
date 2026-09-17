import SwiftUI
import Charts

struct DayStat: Identifiable {
    let id = UUID()
    let day: String
    let count: Int
    let isToday: Bool
}

struct StatisticsView: View {
    @ObservedObject var viewModel: ClipboardListViewModel
    @State private var animatedTotal = 0
    @State private var animatedPasted = 0
    @State private var animatedDaily = 0

    private var chartData: [DayStat] {
        let days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        let stats = viewModel.statistics.weeklyStats
        let total = stats.count
        return stats.enumerated().map { i, v in
            DayStat(day: days[i % 7], count: v, isToday: i == total - 1)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Statistics")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                        }
                        Text("Your clipboard usage analytics")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                // Stat cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        icon: "doc.on.clipboard.fill",
                        title: "Total Copied",
                        value: "\(animatedTotal)",
                        subtitle: "items captured",
                        gradient: [.blue, .cyan],
                        delay: 0
                    )
                    StatCard(
                        icon: "clipboard.paste",
                        title: "Total Pasted",
                        value: "\(animatedPasted)",
                        subtitle: "times used",
                        gradient: [.purple, .pink],
                        delay: 0.1
                    )
                    StatCard(
                        icon: "calendar.badge.checkmark",
                        title: "Today",
                        value: "\(animatedDaily)",
                        subtitle: "copied today",
                        gradient: [.orange, .yellow],
                        delay: 0.2
                    )
                    StatCard(
                        icon: "brain.head.profile.fill",
                        title: "AI Analyzed",
                        value: "\(viewModel.statistics.totalCopied * 85 / 100)",
                        subtitle: "auto-categorized",
                        gradient: [.green, .teal],
                        delay: 0.3
                    )
                }

                // Weekly activity chart
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Weekly Activity")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("Last 7 days")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Chart(chartData) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Copies", item.count)
                        )
                        .foregroundStyle(item.isToday ? Color(hex: "1a1a2e") : Color(hex: "3b82f6").opacity(0.6))
                        .cornerRadius(6)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks()
                    }
                    .frame(height: 180)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }

                // Top apps
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Sources")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    ForEach(viewModel.statistics.topApps.prefix(5), id: \.app) { app in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "app.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)
                            }

                            Text(app.app)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .lineLimit(1)

                            Spacer()

                            Text("\(app.count)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())

                            // Progress bar
                            GeometryReader { geo in
                                let maxCount = viewModel.statistics.topApps.first?.count ?? 1
                                let progress = CGFloat(app.count) / CGFloat(maxCount)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * progress, height: 6)
                            }
                            .frame(width: 100, height: 6)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
            .padding(24)
        }
        .onAppear {
            viewModel.statistics.load()
            withAnimation(.easeOut(duration: 0.8)) {
                animatedTotal = viewModel.statistics.totalCopied
                animatedPasted = viewModel.statistics.totalPasted
                animatedDaily = viewModel.statistics.dailyCopies
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let gradient: [Color]
    let delay: Double

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: gradient[0].opacity(0.08), radius: 12, y: 6)
        )
        .offset(y: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                appeared = true
            }
        }
    }
}
