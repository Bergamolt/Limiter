import SwiftUI
import ServiceManagement

@main
struct LimiterApp: App {
    @State private var monitor = UsageMonitor()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
                .onAppear {
                    monitor.startMonitoring()
                }
        } label: {
            Image(systemName: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(iconColor)
        }
        .menuBarExtraStyle(.window)
    }

    private var iconColor: Color {
        let percent = monitor.sections.map(\.percent).max() ?? 0
        if percent < 50 { return .green }
        if percent < 80 { return .yellow }
        return .red
    }
}
