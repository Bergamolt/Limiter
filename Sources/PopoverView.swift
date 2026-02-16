import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @Bindable var monitor: UsageMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 8)
            content
            footer
        }
        .padding()
        .frame(width: 280)
    }

    // ============================================================================
    // Header
    // ============================================================================

    private var header: some View {
        HStack {
            Text("Limiter")
                .font(.headline)
            Spacer()
            Button(action: { monitor.fetch() }) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(monitor.isLoading ? 360 : 0))
                    .animation(
                        monitor.isLoading
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: monitor.isLoading
                    )
            }
            .buttonStyle(.plain)
            .disabled(monitor.isLoading)
        }
    }

    // ============================================================================
    // Content
    // ============================================================================

    @ViewBuilder
    private var content: some View {
        if monitor.isLoading && monitor.sections.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        } else if let error = monitor.error {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else if monitor.sections.isEmpty {
            Text("No usage data yet")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            let daily = monitor.sections.filter { $0.group == .daily }
            let weekly = monitor.sections.filter { $0.group == .weekly }
            let extra = monitor.sections.filter { $0.group == .extra }

            if !daily.isEmpty {
                ForEach(daily) { section in
                    SectionView(section: section)
                }
            }

            if !weekly.isEmpty {
                if !daily.isEmpty {
                    Divider().padding(.vertical, 4)
                }
                ForEach(weekly) { section in
                    SectionView(section: section)
                }
            }

            if !extra.isEmpty {
                Divider().padding(.vertical, 4)
                ForEach(extra) { section in
                    SectionView(section: section)
                }
            }
        }
    }

    // ============================================================================
    // Footer
    // ============================================================================

    private var footer: some View {
        VStack(spacing: 8) {
            if let lastUpdated = monitor.lastUpdated {
                Divider().padding(.top, 8)
                HStack {
                    Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }

            Divider()

            HStack {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Spacer()

                Button(action: {
                    launchAtLogin.toggle()
                    do {
                        if launchAtLogin {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Launch at Login")
                        Image(systemName: launchAtLogin ? "checkmark.square.fill" : "square")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
            .onAppear {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}

// ============================================================================
// Section View
// ============================================================================

struct SectionView: View {
    let section: UsageSection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(section.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(section.percent)%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(section.percent), total: 100)
                .tint(colorForPercent(section.percent))

            if !section.resetInfo.isEmpty {
                Text(section.resetInfo)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 6)
    }

    private func colorForPercent(_ percent: Int) -> Color {
        if percent < 50 { return .green }
        if percent < 80 { return .yellow }
        return .red
    }
}
