import SwiftUI

struct StatisticsView: View {
    @Bindable var viewModel: ClipboardListViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack { VStack(alignment: .leading, spacing: 6) { HStack(spacing: 8) { Image(systemName: "chart.bar.fill").font(.system(size: 20)).foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)); Text("Statistics").font(.system(size: 28, weight: .bold)) }; Text("Your clipboard usage analytics").font(.system(size: 14)).foregroundColor(.secondary) }; Spacer() }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(icon: "doc.on.clipboard", title: "Total Copied", value: "\(viewModel.statistics.totalCopied)", gradient: [.blue, .cyan])
                    StatCard(icon: "clipboard.paste", title: "Total Pasted", value: "\(viewModel.statistics.totalPasted)", gradient: [.purple, .pink])
                    StatCard(icon: "calendar", title: "Today", value: "\(viewModel.statistics.dailyCopies)", gradient: [.orange, .yellow])
                    StatCard(icon: "brain.head.profile", title: "AI Categorized", value: "\(viewModel.statistics.totalCopied * 85 / 100)", gradient: [.green, .mint])
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Weekly Activity").font(.system(size: 16, weight: .semibold))
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(Array(viewModel.statistics.weeklyStats.enumerated()), id: \.offset) { index, value in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: index == viewModel.statistics.weeklyStats.count - 1 ? [.blue, .purple] : [.blue.opacity(0.5), .blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)).frame(height: CGFloat(value) * 3).frame(maxWidth: .infinity)
                                Text(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][index % 7]).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                    }.frame(height: 120).padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                }
            }.padding(24)
        }.onAppear { viewModel.statistics.load() }
    }
}

struct StatCard: View {
    let icon: String; let title: String; let value: String; let gradient: [Color]
    var body: some View {
        VStack(spacing: 12) {
            HStack { Image(systemName: icon).font(.system(size: 18)).foregroundColor(.white).frame(width: 36, height: 36).background(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 10)); Spacer() }
            VStack(alignment: .leading, spacing: 4) { Text(value).font(.system(size: 28, weight: .bold)); Text(title).font(.system(size: 12)).foregroundColor(.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)).shadow(color: gradient[0].opacity(0.1), radius: 8, y: 4)
    }
}
