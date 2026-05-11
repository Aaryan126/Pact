import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(AppModel.self) private var model
    let openSession: (UUID) -> Void
    @State private var cameraMessage: String?
    @State private var isHistoryPresented = false
    @State private var isSettingsPresented = false
    @State private var lifetimeExportErrorMessage: String?

    var body: some View {
        @Bindable var model = model

        ZStack {
            HomeTheme.windowBackground
                .ignoresSafeArea()

            HomeScreenGlow()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 21) {
                    Spacer()

                    Button {
                        isHistoryPresented.toggle()
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HomeTheme.primaryText)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 18)
                            .frame(height: 39)
                    }
                    .buttonStyle(.plain)
                    .background(HomeTheme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(HomeTheme.controlStroke, lineWidth: 1)
                    }
                    .popover(isPresented: $isHistoryPresented, arrowEdge: .top) {
                        HomeHistoryPopover(
                            sessions: model.sessions,
                            openSession: openSession,
                            deleteAllSessions: model.deleteAllSessions,
                            isPresented: $isHistoryPresented
                        )
                    }

                    Button {
                        isSettingsPresented.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(HomeTheme.primaryText)
                            .frame(width: 38, height: 39)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    .popover(isPresented: $isSettingsPresented, arrowEdge: .top) {
                        HomeSettingsPopover(
                            appearanceMode: $model.appearanceMode,
                            hasLifetimeSummary: !model.sessions.isEmpty,
                            onExportLifetimeSummary: exportLifetimeSummary
                        )
                    }
                }
                .padding(.top, 33)
                .padding(.trailing, 36)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .zIndex(2)

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: max(92, geometry.size.height * 0.158))

                    AppMark()

                    Text("Start session")
                        .font(.system(size: 38, weight: .semibold, design: .default))
                        .foregroundStyle(HomeTheme.primaryText)
                        .padding(.top, 34)

                    Text("Clarity observes silently and\nsummarizes focused time after you\nend the session.")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(HomeTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 374)
                        .padding(.top, 22)

                    Spacer()
                        .frame(height: max(44, geometry.size.height * 0.074))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Length")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HomeTheme.primaryText)

                        SessionLengthSegmentedControl(selection: $model.selectedLength)
                            .frame(height: 46)
                    }
                    .frame(width: 414, alignment: .leading)

                    Button {
                        Task {
                            let status = await CameraPermission.request()
                            guard status == .authorized else {
                                cameraMessage = "Camera permission is required before starting."
                                return
                            }
                            model.startSession()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Start")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 414, height: 46)
                        .background(HomeTheme.primaryButtonFill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 32)

                    if let error = model.engineError ?? cameraMessage {
                        Text(error)
                            .foregroundStyle(Color(red: 1.0, green: 0.28, blue: 0.30))
                            .font(.system(size: 12, weight: .medium))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 414)
                            .padding(.top, 14)
                    }

                    Spacer(minLength: 28)

                    HStack(spacing: 12) {
                        Image(systemName: "shield")
                            .font(.system(size: 15, weight: .medium))

                        Text("Your data stays on your device. Private and secure.")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(HomeTheme.secondaryText)

                    Spacer()
                        .frame(height: max(38, geometry.size.height * 0.056))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { lifetimeExportErrorMessage != nil },
                set: { if !$0 { lifetimeExportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                lifetimeExportErrorMessage = nil
            }
        } message: {
            Text(lifetimeExportErrorMessage ?? "Unable to write the spreadsheet.")
        }
        .navigationTitle("")
    }

    private func exportLifetimeSummary() {
        let panel = NSSavePanel()
        panel.title = "Export Lifetime Summary"
        panel.prompt = "Export"
        panel.nameFieldStringValue = defaultLifetimeExportFilename()
        panel.allowedContentTypes = [spreadsheetContentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let exportURL = url.pathExtension.isEmpty ? url.appendingPathExtension("xlsx") : url

        do {
            let workbook = try LifetimeSummaryXLSXExporter.xlsx(for: model.sessions)
            try workbook.write(to: exportURL, options: [.atomic])
        } catch {
            lifetimeExportErrorMessage = "Could not export lifetime summary: \(error.localizedDescription)"
        }
    }

    private func defaultLifetimeExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return "Clarity Lifetime Summary \(formatter.string(from: Date())).xlsx"
    }

    private var spreadsheetContentType: UTType {
        UTType(filenameExtension: "xlsx") ?? UTType(exportedAs: "org.openxmlformats.spreadsheetml.sheet")
    }
}

private struct AppMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(HomeTheme.logoOuterBlue, lineWidth: 12)
                .frame(width: 112, height: 112)

            Circle()
                .stroke(HomeTheme.logoInnerBlue, lineWidth: 10)
                .frame(width: 84, height: 84)
        }
        .frame(width: 118, height: 118)
        .shadow(color: HomeTheme.logoGlow, radius: 24, x: 0, y: 0)
    }
}

private struct HomeScreenGlow: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    HomeTheme.upperGlow,
                    .clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 640
            )

            RadialGradient(
                colors: [
                    HomeTheme.centerGlow,
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 520
            )
        }
        .allowsHitTesting(false)
    }
}

private struct HomeHistoryPopover: View {
    let sessions: [FocusSession]
    let openSession: (UUID) -> Void
    let deleteAllSessions: () -> Void
    @Binding var isPresented: Bool
    @State private var isConfirmingDeleteAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HomeTheme.primaryText)

                Spacer()

                if !sessions.isEmpty {
                    Button {
                        isConfirmingDeleteAll = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HomeTheme.secondaryText)
                    .help("Delete all local session history")
                }
            }

            if sessions.isEmpty {
                Text("Past sessions will appear here.")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sessions) { session in
                            Button {
                                isPresented = false
                                openSession(session.id)
                            } label: {
                                HomeHistoryPopoverRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxHeight: 286)
                .scrollIndicators(.hidden)
            }
        }
        .padding(18)
        .frame(width: 358)
        .background(HomeTheme.popoverBackground)
        .alert("Delete all session history?", isPresented: $isConfirmingDeleteAll) {
            Button("Delete", role: .destructive) {
                deleteAllSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes local Clarity session records from this Mac.")
        }
    }
}

private struct HomeHistoryPopoverRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(HomeTheme.subtleBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(HomeTheme.border, lineWidth: 1)
                    }

                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(HomeTheme.primaryBlue)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(HomeTheme.primaryText)
                    .lineLimit(1)

                Text("\(formatWholePercent(session.screenFocusedRatio)) focused")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(formatMinutes(session.duration))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(HomeTheme.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background(HomeTheme.historyRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(HomeTheme.border, lineWidth: 1)
        }
    }
}

private struct HomeSettingsPopover: View {
    @Binding var appearanceMode: AppAppearanceMode
    let hasLifetimeSummary: Bool
    let onExportLifetimeSummary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeTheme.primaryText)

                AppearanceModePicker(selection: $appearanceMode)
                    .frame(width: 196, height: 32)
            }

            Rectangle()
                .fill(HomeTheme.divider)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Text("Data")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeTheme.primaryText)

                Button(action: onExportLifetimeSummary) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 16)

                        Text("Export lifetime summary")
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(HomeTheme.primaryText)
                    .padding(.horizontal, 10)
                    .frame(width: 196, height: 34, alignment: .leading)
                    .background(HomeTheme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(HomeTheme.controlStroke, lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!hasLifetimeSummary)
                .opacity(hasLifetimeSummary ? 1 : 0.48)
                .help(hasLifetimeSummary ? "Export lifetime summary as XLSX" : "No sessions to export")
            }
        }
        .padding(16)
        .frame(width: 228)
        .background(HomeTheme.popoverBackground)
    }
}

struct AppearanceModePicker: View {
    @Binding var selection: AppAppearanceMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppAppearanceMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selection == mode ? .white : HomeTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if selection == mode {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(HomeTheme.primaryBlue)
                            .padding(2)
                    }
                }
            }
        }
        .background(HomeTheme.segmentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(HomeTheme.border, lineWidth: 1)
        }
        .accessibilityLabel("Appearance")
    }
}

private struct SessionLengthSegmentedControl: View {
    @Binding var selection: SessionLength

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(SessionLength.allCases.enumerated()), id: \.element.id) { index, length in
                Button {
                    selection = length
                } label: {
                    Text(length.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selection == length ? .white : HomeTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if selection == length {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(HomeTheme.primaryBlue)
                            .padding(2)
                    }
                }

                if index < SessionLength.allCases.count - 1 {
                    Rectangle()
                        .fill(HomeTheme.segmentDivider)
                        .frame(width: 1, height: 24)
                }
            }
        }
        .background(HomeTheme.segmentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(HomeTheme.border, lineWidth: 1)
        }
    }
}

enum HomeTheme {
    static let chromeBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.970, green: 0.975, blue: 0.982, alpha: 1),
        dark: NSColor(calibratedRed: 0.088, green: 0.096, blue: 0.102, alpha: 1)
    )
    static let windowBackground = LinearGradient(
        colors: [
            adaptiveColor(
                light: NSColor(calibratedRed: 0.988, green: 0.991, blue: 0.996, alpha: 1),
                dark: NSColor(calibratedRed: 0.006, green: 0.010, blue: 0.017, alpha: 1)
            ),
            adaptiveColor(
                light: NSColor(calibratedRed: 0.954, green: 0.963, blue: 0.974, alpha: 1),
                dark: NSColor(calibratedRed: 0.001, green: 0.003, blue: 0.008, alpha: 1)
            )
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let panelBackground = windowBackground
    static let historyRowBackground = LinearGradient(
        colors: [
            adaptiveColor(
                light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.92),
                dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.105)
            ),
            adaptiveColor(
                light: NSColor(calibratedRed: 0.982, green: 0.986, blue: 0.992, alpha: 0.86),
                dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.045)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panelStroke = adaptiveColor(
        light: NSColor(calibratedRed: 0.824, green: 0.847, blue: 0.878, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.13)
    )
    static let border = adaptiveColor(
        light: NSColor(calibratedRed: 0.850, green: 0.870, blue: 0.895, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.08)
    )
    static let divider = adaptiveColor(
        light: NSColor(calibratedRed: 0.890, green: 0.902, blue: 0.918, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.10)
    )
    static let primaryText = adaptiveColor(
        light: NSColor(calibratedRed: 0.035, green: 0.045, blue: 0.062, alpha: 1),
        dark: NSColor(calibratedRed: 0.970, green: 0.980, blue: 0.995, alpha: 1)
    )
    static let secondaryText = adaptiveColor(
        light: NSColor(calibratedRed: 0.390, green: 0.420, blue: 0.480, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.62)
    )
    static let primaryBlue = Color(red: 0.02, green: 0.40, blue: 0.98)
    static let logoOuterBlue = adaptiveColor(
        light: NSColor(calibratedRed: 0.000, green: 0.240, blue: 0.780, alpha: 1),
        dark: NSColor(calibratedRed: 0.000, green: 0.185, blue: 0.610, alpha: 1)
    )
    static let logoInnerBlue = adaptiveColor(
        light: NSColor(calibratedRed: 0.020, green: 0.390, blue: 0.980, alpha: 1),
        dark: NSColor(calibratedRed: 0.020, green: 0.410, blue: 1.000, alpha: 1)
    )
    static let logoGlow = adaptiveColor(
        light: NSColor(calibratedRed: 0.020, green: 0.280, blue: 0.760, alpha: 0.14),
        dark: NSColor(calibratedRed: 0.020, green: 0.290, blue: 0.900, alpha: 0.32)
    )
    static let upperGlow = adaptiveColor(
        light: NSColor(calibratedRed: 0.820, green: 0.900, blue: 1.000, alpha: 0.54),
        dark: NSColor(calibratedRed: 0.040, green: 0.115, blue: 0.230, alpha: 0.40)
    )
    static let centerGlow = adaptiveColor(
        light: NSColor(calibratedRed: 0.780, green: 0.860, blue: 1.000, alpha: 0.24),
        dark: NSColor(calibratedRed: 0.020, green: 0.060, blue: 0.130, alpha: 0.30)
    )
    static let controlBackground = adaptiveColor(
        light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.82),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.035)
    )
    static let controlStroke = adaptiveColor(
        light: NSColor(calibratedRed: 0.785, green: 0.815, blue: 0.865, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.145)
    )
    static let primaryButtonFill = LinearGradient(
        colors: [
            Color(red: 0.030, green: 0.450, blue: 1.000),
            Color(red: 0.020, green: 0.360, blue: 0.960)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let segmentBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.918, green: 0.934, blue: 0.956, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.050)
    )
    static let segmentDivider = adaptiveColor(
        light: NSColor(calibratedRed: 0.810, green: 0.836, blue: 0.875, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.16)
    )
    static let cardBackground = adaptiveColor(
        light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.96),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.055)
    )
    static let popoverBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.990, green: 0.993, blue: 0.998, alpha: 1),
        dark: NSColor(calibratedRed: 0.070, green: 0.076, blue: 0.090, alpha: 1)
    )
    static let subtleBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.960, green: 0.968, blue: 0.980, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.040)
    )
    static let markHighlight = adaptiveColor(
        light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.12)
    )
    static let markBase = adaptiveColor(
        light: NSColor(calibratedRed: 0.930, green: 0.946, blue: 0.968, alpha: 1),
        dark: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.035)
    )
    static let shadow = adaptiveColor(
        light: NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.110, alpha: 0.10),
        dark: NSColor(calibratedRed: 0.000, green: 0.000, blue: 0.000, alpha: 0.38)
    )

    static func chromeNSColor(for mode: AppAppearanceMode) -> NSColor {
        switch mode {
        case .light:
            NSColor(calibratedRed: 0.970, green: 0.975, blue: 0.982, alpha: 1)
        case .dark:
            NSColor(calibratedRed: 0.088, green: 0.096, blue: 0.102, alpha: 1)
        }
    }

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return bestMatch == .darkAqua ? dark : light
        })
    }
}
