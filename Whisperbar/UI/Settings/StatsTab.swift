import SwiftUI

struct StatsTab: View {
    @State private var stats: [SessionStore.BackendStats] = []
    @State private var totalRated = 0
    @State private var revealed = false
    @State private var exportError: String?
    @AppStorage("statsRevealed") private var statsRevealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if stats.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "chart.bar",
                        description: Text("Start dictating to collect data.")
                    )
                } else {
                    // Summary
                    HStack {
                        StatCard(title: "Total Rated", value: "\(totalRated)")
                        StatCard(title: "Backends Tested", value: "\(stats.count)")
                    }

                    Divider()

                    // Per-backend
                    ForEach(stats, id: \.backend) { stat in
                        BackendStatRow(stat: stat, revealed: statsRevealed || revealed)
                    }

                    if totalRated >= 20 && !statsRevealed {
                        Button("🏆 Reveal Winner") {
                            withAnimation(.smooth(duration: 0.25)) { revealed = true }
                            statsRevealed = true
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }

                    if totalRated < 20 {
                        Text("Rate \(max(0, 20 - totalRated)) more sessions to unlock the winner reveal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Button("Export to CSV…") { exportCSV() }
                        .buttonStyle(.bordered)

                    if let err = exportError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .padding()
        }
        .onAppear { loadStats() }
    }

    private func loadStats() {
        do {
            stats = try SessionStore.shared.fetchStats()
            totalRated = try SessionStore.shared.totalRatedSessions()
        } catch {
            print("Stats load error: \(error)")
        }
    }

    private func exportCSV() {
        do {
            let csv = try SessionStore.shared.exportCSV()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "murmur-sessions.csv"
            if panel.runModal() == .OK, let url = panel.url {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            exportError = error.localizedDescription
        }
    }
}

struct BackendStatRow: View {
    let stat: SessionStore.BackendStats
    let revealed: Bool

    var displayName: String {
        if revealed {
            switch stat.backend {
            case "apple": return "Apple (on-device)"
            case "whisper": return "Whisper base.en"
            case "hybrid": return "Hybrid"
            default: return stat.backend
            }
        } else {
            return "Backend \(stat.backend.first.map { String($0).uppercased() } ?? "?")"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayName).font(.headline)
                Spacer()
                RatingBar(good: stat.goodCount, ok: stat.okCount, bad: stat.badCount,
                          total: stat.ratedSessions)
            }
            HStack(spacing: 16) {
                label("Sessions", "\(stat.totalSessions)")
                label("Rated", "\(stat.ratedSessions)")
                label("Avg Latency", "\(Int(stat.avgLatencyMs))ms")
                label("Avg Words", "\(Int(stat.avgWordCount))")
                label("Score", String(format: "%.1f/3", stat.avgRatingScore))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
    }

    private func label(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit()).fontWeight(.medium)
        }
    }
}

struct RatingBar: View {
    let good: Int
    let ok: Int
    let bad: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            if total > 0 {
                Text("👍\(good)").font(.caption)
                Text("👌\(ok)").font(.caption)
                Text("👎\(bad)").font(.caption)
            } else {
                Text("No ratings").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
    }
}
