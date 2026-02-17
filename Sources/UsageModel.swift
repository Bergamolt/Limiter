import Foundation

// ============================================================================
// Data Model
// ============================================================================

struct UsageSection: Identifiable {
    let id = UUID()
    let name: String
    let percent: Int
    let resetInfo: String
    let group: SectionGroup
}

enum SectionGroup: Int {
    case daily = 0
    case weekly = 1
    case extra = 2
}

// ============================================================================
// Usage Monitor
// ============================================================================

@Observable
@MainActor
final class UsageMonitor {
    var sections: [UsageSection] = []
    var isLoading = false
    var lastUpdated: Date?
    var error: String?

    private var timer: Timer?
    private let updateInterval: TimeInterval = 300
    private let retryBaseInterval: TimeInterval = 10
    private var consecutiveErrors = 0

    private var started = false

    func startMonitoring() {
        guard !started else { return }
        started = true
        fetch()
    }

    func fetch() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task.detached {
            do {
                let token = try Self.readOAuthToken()
                let raw = try await Self.fetchUsageRaw(token: token)
                let parsed = Self.buildSections(from: raw)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.sections = parsed
                    self.lastUpdated = Date()
                    self.isLoading = false
                    self.consecutiveErrors = 0
                    self.scheduleNext()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.error = error.localizedDescription
                    self.isLoading = false
                    self.consecutiveErrors += 1
                    self.scheduleNext()
                }
            }
        }
    }

    private func scheduleNext() {
        timer?.invalidate()
        let delay: TimeInterval
        if consecutiveErrors > 0 {
            delay = min(retryBaseInterval * pow(2, Double(consecutiveErrors - 1)), updateInterval)
        } else {
            delay = updateInterval
        }
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fetch()
            }
        }
    }

    // ============================================================================
    // Keychain
    // ============================================================================

    nonisolated private static func readOAuthToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !json.isEmpty else {
            throw LimiterError.noCredentials
        }

        guard let jsonData = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = dict["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw LimiterError.noCredentials
        }

        return token
    }

    // ============================================================================
    // API Call
    // ============================================================================

    nonisolated private static func fetchUsageRaw(token: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LimiterError.apiFailed(code)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LimiterError.apiFailed(0)
        }

        return json
    }

    // ============================================================================
    // Build Sections
    // ============================================================================

    // Known bucket keys → display names and groups
    nonisolated private static let bucketConfig: [(key: String, name: String, group: SectionGroup)] = [
        ("five_hour", "Session", .daily),
        ("extra_usage", "Extra usage", .extra),
        ("seven_day", "All models", .weekly),
        ("seven_day_sonnet", "Sonnet", .weekly),
        ("sonnet_seven_day", "Sonnet", .weekly),
        ("seven_day_haiku", "Haiku", .weekly),
        ("haiku_seven_day", "Haiku", .weekly),
        ("seven_day_opus", "Opus", .weekly),
        ("opus_seven_day", "Opus", .weekly),
    ]

    nonisolated private static func buildSections(from json: [String: Any]) -> [UsageSection] {
        var sections: [UsageSection] = []

        // Parse known buckets first
        var handledKeys = Set<String>()
        for config in bucketConfig {
            if let bucket = json[config.key] as? [String: Any] {
                handledKeys.insert(config.key)
                if let section = parseSection(name: config.name, group: config.group, bucket: bucket) {
                    sections.append(section)
                }
            }
        }

        // Parse any unknown buckets that look like usage data
        for (key, value) in json where !handledKeys.contains(key) {
            guard let bucket = value as? [String: Any],
                  bucket["utilization"] != nil else { continue }

            let name = key
                .replacingOccurrences(of: "_", with: " ")
                .capitalized

            let group: SectionGroup = key.contains("seven_day") ? .weekly : .daily
            if let section = parseSection(name: name, group: group, bucket: bucket) {
                sections.append(section)
            }
        }

        return sections
    }

    nonisolated private static func parseSection(
        name: String,
        group: SectionGroup,
        bucket: [String: Any]
    ) -> UsageSection? {
        let utilization = bucket["utilization"] as? Double ?? 0
        let resetsAt = bucket["resets_at"] as? String
        let percent = Int(utilization)
        let reset = formatReset(resetsAt)

        return UsageSection(
            name: name,
            percent: percent,
            resetInfo: reset,
            group: group
        )
    }

    nonisolated private static func formatReset(_ isoString: String?) -> String {
        guard let isoString, !isoString.isEmpty else { return "" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }

        guard let resetDate = date else { return "" }

        let now = Date()
        let diff = resetDate.timeIntervalSince(now)

        if diff <= 0 { return "Reset now" }

        let hours = Int(diff) / 3600
        let mins = (Int(diff) % 3600) / 60

        if hours >= 24 {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE h:mm a"
            return "Resets \(fmt.string(from: resetDate))"
        } else if hours > 0 {
            return "Resets in \(hours)h \(mins)m"
        } else {
            return "Resets in \(mins)m"
        }
    }
}

// ============================================================================
// Errors
// ============================================================================

enum LimiterError: LocalizedError {
    case noCredentials
    case apiFailed(Int)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No Claude credentials in keychain"
        case .apiFailed(let code): return "API error: \(code)"
        }
    }
}
