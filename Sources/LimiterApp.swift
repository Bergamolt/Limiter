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
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    var monitor: UsageMonitor

    var body: some View {
        let percent = monitor.sections.map(\.percent).max() ?? 0
        let color: Color = percent < 50 ? .green : percent < 80 ? .yellow : .red
        Image(systemName: "circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(color)
    }
}
