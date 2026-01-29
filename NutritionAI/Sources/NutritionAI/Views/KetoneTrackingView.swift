#if canImport(UIKit)
import SwiftUI

public struct KetoneTrackingView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    let apiService: APIService

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isKetoUser: Bool?

    // Data
    @State private var latestLog: KetoneLog?
    @State private var latestStatus: KetosisStatus?
    @State private var logs: [KetoneLog] = []
    @State private var stats: KetoneStats?

    // New entry form
    @State private var showingEntryForm = false
    @State private var ketoneLevel: String = ""
    @State private var measurementType: String = "blood"
    @State private var notes: String = ""
    @State private var isSaving = false

    public init(apiService: APIService) {
        self.apiService = apiService
    }

    public var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()

                if isKetoUser == false {
                    notKetoUserView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Ketone Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isKetoUser == true {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingEntryForm = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppGradients.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEntryForm) {
                entryFormSheet
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            await checkUserAndLoadData()
        }
    }

    private var notKetoUserView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppGradients.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                Text("🥑")
                    .font(.system(size: 50))
            }

            Text("Keto Diet Required")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))

            Text("Ketone tracking is available for users on the Keto diet. Switch your diet type to Keto to access this feature.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading && logs.isEmpty {
                    loadingView
                } else {
                    // Current status
                    if let status = latestStatus {
                        ketosisStatusCard(status)
                    }

                    // Stats
                    if let stats = stats, stats.totalDays > 0 {
                        statsCard(stats)
                    }

                    // Ketosis guide
                    ketosisGuide

                    // Recent logs
                    sectionHeader(title: "Recent Readings", icon: "list.bullet")
                    recentLogsSection
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .refreshable {
            await loadKetoneData()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func ketosisStatusCard(_ status: KetosisStatus) -> some View {
        VStack(spacing: 16) {
            Text(status.isInKetosis ? "🔥" : "⚡")
                .font(.system(size: 50))

            Text(status.level.uppercased())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ketosisColor(for: status.level))

            Text(status.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let log = latestLog {
                Text("Last reading: \(String(format: "%.1f", log.ketoneLevel)) mmol/L")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatDate(log.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ketosisColor(for: latestStatus?.level ?? "none").opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ketosisColor(for: latestStatus?.level ?? "none").opacity(0.3), lineWidth: 2)
        )
    }

    private func statsCard(_ stats: KetoneStats) -> some View {
        VStack(spacing: 16) {
            sectionHeader(title: "30-Day Statistics", icon: "chart.bar.fill")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatBox(label: "Average", value: String(format: "%.1f", stats.avgLevel), unit: "mmol/L")
                StatBox(label: "Days in Ketosis", value: "\(stats.daysInKetosis)/\(stats.totalDays)", unit: "")
                StatBox(label: "Range", value: "\(String(format: "%.1f", stats.minLevel)) - \(String(format: "%.1f", stats.maxLevel))", unit: "")
                StatBox(label: "Trend", value: stats.trend.capitalized, unit: "", trendColor: trendColor(for: stats.trend))
            }

            // Ketosis rate bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ketosis Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(stats.ketosisRate * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(stats.ketosisRate >= 0.7 ? Color.green :
                                    stats.ketosisRate >= 0.5 ? Color.yellow : Color.orange)
                            .frame(width: geometry.size.width * stats.ketosisRate, height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .glassMorphism()
    }

    private var ketosisGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Ketosis Levels Guide", icon: "info.circle.fill")

            VStack(alignment: .leading, spacing: 8) {
                KetosisLevelRow(range: "0 - 0.5", label: "Not in ketosis", color: .gray)
                KetosisLevelRow(range: "0.5 - 1.0", label: "Light ketosis", color: .yellow)
                KetosisLevelRow(range: "1.0 - 1.5", label: "Moderate ketosis", color: .green.opacity(0.7))
                KetosisLevelRow(range: "1.5 - 3.0", label: "Optimal ketosis", color: .green)
                KetosisLevelRow(range: "3.0+", label: "High (monitor closely)", color: .orange)
            }
        }
        .padding()
        .glassMorphism()
    }

    private var recentLogsSection: some View {
        VStack(spacing: 12) {
            if logs.isEmpty {
                Text("No ketone readings yet. Log your first reading!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassMorphism()
            } else {
                ForEach(logs) { log in
                    KetoneLogCard(log: log, colorScheme: colorScheme) {
                        Task { await deleteLog(log) }
                    }
                }
            }
        }
    }

    private var entryFormSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Ketone Level")) {
                    TextField("e.g., 1.5", text: $ketoneLevel)
                        .keyboardType(.decimalPad)

                    Text("Enter value in mmol/L (0 - 10)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Measurement Type")) {
                    Picker("Type", selection: $measurementType) {
                        Text("Blood (most accurate)").tag("blood")
                        Text("Breath").tag("breath")
                        Text("Urine strips").tag("urine")
                    }
                }

                Section(header: Text("Notes (Optional)")) {
                    TextField("e.g., fasting, after workout", text: $notes)
                }
            }
            .navigationTitle("Log Ketone Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEntryForm = false
                        resetForm()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveKetoneReading() }
                    }
                    .disabled(ketoneLevel.isEmpty || isSaving)
                }
            }
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppGradients.primary)
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))
            Spacer()
        }
    }

    // MARK: - Actions

    private func checkUserAndLoadData() async {
        isLoading = true

        do {
            let profileResponse = try await apiService.fetchProfile()
            let isKeto = profileResponse.profile.dietType == "keto"

            await MainActor.run {
                isKetoUser = isKeto
            }

            if isKeto {
                await loadKetoneData()
            }
        } catch let error as APIError {
            await MainActor.run {
                isKetoUser = false
                switch error {
                case .serverError(let message):
                    if !message.contains("not found") {
                        errorMessage = message
                    }
                default:
                    break
                }
            }
        } catch {
            await MainActor.run {
                isKetoUser = false
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func loadKetoneData() async {
        do {
            async let latestTask = apiService.fetchLatestKetone()
            async let recentTask = apiService.fetchRecentKetones(limit: 30)

            let (latest, recent) = try await (latestTask, recentTask)

            await MainActor.run {
                latestLog = latest.log
                latestStatus = latest.ketosisStatus
                logs = recent.logs
                stats = recent.stats
            }
        } catch let error as APIError {
            await MainActor.run {
                switch error {
                case .serverError(let message):
                    errorMessage = message
                default:
                    errorMessage = "Failed to load ketone data"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred"
            }
        }
    }

    private func saveKetoneReading() async {
        guard let level = Double(ketoneLevel) else {
            errorMessage = "Please enter a valid ketone level"
            return
        }

        isSaving = true

        do {
            let response = try await apiService.logKetone(
                level: level,
                measurementType: measurementType,
                notes: notes.isEmpty ? nil : notes
            )

            await MainActor.run {
                latestLog = response.log
                latestStatus = response.ketosisStatus
                logs.insert(response.log, at: 0)
                showingEntryForm = false
                resetForm()
                isSaving = false
            }

            // Reload stats
            await loadKetoneData()
        } catch let error as APIError {
            await MainActor.run {
                isSaving = false
                switch error {
                case .serverError(let message):
                    errorMessage = message
                default:
                    errorMessage = "Failed to save ketone reading"
                }
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "An unexpected error occurred"
            }
        }
    }

    private func deleteLog(_ log: KetoneLog) async {
        do {
            try await apiService.deleteKetoneLog(id: log.id)

            await MainActor.run {
                logs.removeAll { $0.id == log.id }
            }

            // Reload data
            await loadKetoneData()
        } catch let error as APIError {
            await MainActor.run {
                switch error {
                case .serverError(let message):
                    errorMessage = message
                default:
                    errorMessage = "Failed to delete reading"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred"
            }
        }
    }

    private func resetForm() {
        ketoneLevel = ""
        measurementType = "blood"
        notes = ""
    }

    // MARK: - Helpers

    private func ketosisColor(for level: String) -> Color {
        switch level.lowercased() {
        case "optimal": return .green
        case "moderate": return Color.green.opacity(0.7)
        case "light": return .yellow
        case "high": return .orange
        default: return .gray
        }
    }

    private func trendColor(for trend: String) -> Color? {
        switch trend.lowercased() {
        case "improving": return .green
        case "declining": return .red
        default: return nil
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

struct StatBox: View {
    let label: String
    let value: String
    let unit: String
    var trendColor: Color? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(trendColor ?? AppColors.textPrimary(for: colorScheme))
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct KetosisLevelRow: View {
    let range: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(range)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 70, alignment: .leading)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct KetoneLogCard: View {
    let log: KetoneLog
    let colorScheme: ColorScheme
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f mmol/L", log.ketoneLevel))
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(for: colorScheme))

                Text(formatDate(log.timestamp) + " • " + log.measurementType)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let notes = log.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding()
        .glassMorphism()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

#endif
