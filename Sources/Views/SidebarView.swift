import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    var pinboards: [Pinboard] = []
    @State private var showNewPinboard = false
    @State private var newPinboardName = ""
    @State private var showPaywall = false
    let subscription = SubscriptionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("ClipStack")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("Clipboard Manager")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)

            // Free plan badge
            if !subscription.isPro {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(hex: "f59e0b"), Color(hex: "d97706")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Free Plan")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text("100 items max")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 14)
                .padding(.top, 16)
            }

            // Navigation
            List(selection: $selectedItem) {
                Section {
                    sidebarRow(icon: "clock.arrow.circlepath", title: "History", color: Color(hex: "3b82f6"), isSelected: selectedItem == .history)
                        .tag(SidebarItem.history)
                    sidebarRow(icon: "star.fill", title: "Favorites", color: Color(hex: "f59e0b"), isSelected: selectedItem == .favorites)
                        .tag(SidebarItem.favorites)
                    sidebarRow(icon: "square.stack.fill", title: "Paste Stack", color: Color(hex: "8b5cf6"), isSelected: selectedItem == .pasteStack)
                        .tag(SidebarItem.pasteStack)
                }

                Section("Pinboards") {
                    ForEach(pinboards) { pinboard in
                        sidebarRow(icon: pinboard.icon, title: pinboard.name, color: Color(hex: pinboard.color), isSelected: false, count: pinboard.items.count)
                            .tag(SidebarItem.pinboard(pinboard.id, pinboard.name))
                    }
                    Button(action: { if subscription.isPro || pinboards.count < 1 { showNewPinboard = true } else { showPaywall = true } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "3b82f6"))
                            Text("New Pinboard")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    sidebarRow(icon: "chart.xyaxis.line", title: "Statistics", color: Color(hex: "10b981"), isSelected: selectedItem == .statistics)
                        .tag(SidebarItem.statistics)
                    sidebarRow(icon: "paintbrush.pointed.fill", title: "Themes", color: Color(hex: "f43f5e"), isSelected: selectedItem == .themes)
                        .tag(SidebarItem.themes)
                }
            }
            .listStyle(.sidebar)

            Spacer()

            // Upgrade button
            if !subscription.isPro {
                Button(action: { showPaywall = true }) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 28, height: 28)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Upgrade to Pro")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Text("Unlimited everything")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        LinearGradient(colors: [Color(hex: "1a1a2e"), Color(hex: "0f172a")], startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .padding(14)
            }
        }
        .frame(width: 250)
        .sheet(isPresented: $showNewPinboard) { newPinboardSheet }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func sidebarRow(icon: String, title: String, color: Color, isSelected: Bool, count: Int? = nil) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.15) : color.opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? color : color.opacity(0.7))
            }

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundColor(isSelected ? Color(hex: "1a1a2e") : .secondary)

            Spacer()

            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
    }

    private var newPinboardSheet: some View {
        VStack(spacing: 20) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color(hex: "3b82f6"), Color(hex: "8b5cf6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "pin.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("New Pinboard")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            TextField("Name", text: $newPinboardName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .rounded))
                .frame(width: 280)
            HStack(spacing: 12) {
                Button("Cancel") { showNewPinboard = false }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    if let container = try? ModelContainer(for: Pinboard.self) {
                        let context = ModelContext(container)
                        let pb = Pinboard(name: newPinboardName)
                        context.insert(pb)
                        try? context.save()
                    }
                    newPinboardName = ""
                    showNewPinboard = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPinboardName.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 360)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
