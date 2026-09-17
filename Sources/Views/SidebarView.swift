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
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.indigo, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .shadow(color: .purple.opacity(0.4), radius: 6, y: 3)
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("ClipStack")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }.padding(.horizontal, 16).padding(.top, 16)

            // Free plan badge
            if !subscription.isPro {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Free Plan").font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text("100 items max").font(.system(size: 9, design: .rounded)).foregroundColor(.secondary)
                    }
                    Spacer()
                }.padding(10).background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 16)
            }

            List(selection: $selectedItem) {
                Section {
                    sidebarRow(icon: "clock.arrow.circlepath", title: "History", color: .blue, gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).tag(SidebarItem.history)
                    sidebarRow(icon: "star.circle.fill", title: "Favorites", color: .yellow, gradient: LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)).tag(SidebarItem.favorites)
                    sidebarRow(icon: "square.stack.fill", title: "Paste Stack", color: .purple, gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)).tag(SidebarItem.pasteStack)
                }
                Section("Pinboards") {
                    ForEach(pinboards) { pinboard in
                        sidebarRow(icon: pinboard.icon, title: pinboard.name, color: Color(hex: pinboard.color), count: pinboard.items.count)
                            .tag(SidebarItem.pinboard(pinboard.id, pinboard.name))
                    }
                    Button(action: { if subscription.isPro || pinboards.count < 1 { showNewPinboard = true } else { showPaywall = true } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("New Pinboard").font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                    }
                }
                Section {
                    sidebarRow(icon: "chart.xyaxis.line", title: "Statistics", color: .green, gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)).tag(SidebarItem.statistics)
                    sidebarRow(icon: "paintbrush.pointed.fill", title: "Themes", color: .orange, gradient: LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)).tag(SidebarItem.themes)
                }
            }.listStyle(.sidebar)

            Spacer()

            // Upgrade button
            if !subscription.isPro {
                Button(action: { showPaywall = true }) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 28, height: 28)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Upgrade to Pro").font(.system(size: 12, weight: .semibold, design: .rounded))
                            Text("Unlimited everything").font(.system(size: 9, design: .rounded)).opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.6)
                    }.foregroundColor(.white).padding(12)
                        .background(
                            ZStack {
                                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                                LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .indigo.opacity(0.4), radius: 10, y: 5)
                }.buttonStyle(.plain).padding(12)
            }
        }.frame(width: 240)
            .sheet(isPresented: $showNewPinboard) { newPinboardSheet }
            .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func sidebarRow(icon: String, title: String, color: Color, gradient: LinearGradient? = nil, count: Int? = nil) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(gradient ?? LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(title).font(.system(size: 13, weight: .medium, design: .rounded))
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }.padding(.vertical, 4)
    }

    private var newPinboardSheet: some View {
        VStack(spacing: 16) {
            HStack { Image(systemName: "pin.fill").font(.title2).foregroundColor(.blue); Text("New Pinboard").font(.headline) }
            TextField("Name", text: $newPinboardName).textFieldStyle(.roundedBorder).frame(width: 260)
            HStack(spacing: 12) {
                Button("Cancel") { showNewPinboard = false }.keyboardShortcut(.cancelAction)
                Button("Create") {
                    if let container = try? ModelContainer(for: Pinboard.self) {
                        let context = ModelContext(container)
                        let pb = Pinboard(name: newPinboardName); context.insert(pb); try? context.save()
                    }
                    newPinboardName = ""; showNewPinboard = false
                }.keyboardShortcut(.defaultAction).disabled(newPinboardName.isEmpty)
            }
        }.padding(24).frame(width: 340)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
