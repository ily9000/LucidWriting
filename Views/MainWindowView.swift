import SwiftUI

struct MainWindowView: View {
    @AppStorage("claudeApiKey") private var apiKey: String = ""
    @AppStorage("apiKeyValidated") private var apiKeyValidated: Bool = false
    @State private var validationState: APIValidationState = .unknown
    @State private var isValidating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderSection()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Status Section
                    StatusSection(apiKey: apiKey)

                    Divider()

                    // API Key Section
                    APIKeySection(
                        apiKey: $apiKey,
                        validationState: $validationState,
                        isValidating: $isValidating,
                        apiKeyValidated: $apiKeyValidated
                    )

                    Divider()

                    // Hotkey Info Section
                    HotkeySection()

                    Divider()

                    // Permissions Section
                    PermissionsSection()

                    Divider()

                    // Screenshot History Section
                    ScreenshotHistorySection()
                }
                .padding(20)
            }

            Divider()

            // Footer
            FooterSection()
        }
        .frame(width: 450, height: 680)
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    var body: some View {
        HStack {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.title)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Message Refiner")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Refine your messages with AI")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Status Section

struct StatusSection: View {
    let apiKey: String

    var isReady: Bool {
        !apiKey.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            HStack {
                Circle()
                    .fill(isReady ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(isReady ? "Ready to refine" : "API key not configured")
                    .foregroundColor(isReady ? .primary : .red)

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - API Key Section

enum APIValidationState: Equatable {
    case unknown
    case validating
    case valid
    case invalid(String)
}

struct APIKeySection: View {
    @Binding var apiKey: String
    @Binding var validationState: APIValidationState
    @Binding var isValidating: Bool
    @Binding var apiKeyValidated: Bool
    @State private var isEditing: Bool = false

    private var isLocked: Bool {
        // Locked if validated (persisted) or just validated in this session
        if apiKeyValidated && !isEditing {
            return true
        }
        if case .valid = validationState {
            return !isEditing
        }
        return false
    }

    private var maskedKey: String {
        guard apiKey.count > 12 else { return String(repeating: "•", count: apiKey.count) }
        let prefix = String(apiKey.prefix(7))
        let suffix = String(apiKey.suffix(4))
        return "\(prefix)•••••••••••\(suffix)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude API Key")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if isLocked {
                    // Locked state - show masked key with Edit button
                    HStack {
                        Text(maskedKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                            .cornerRadius(6)

                        Button("Edit") {
                            isEditing = true
                            validationState = .unknown
                            apiKeyValidated = false
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    // Editable state
                    HStack {
                        SecureField("sk-ant-api03-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKey) { _ in
                                // Reset validation when key changes
                                validationState = .unknown
                            }

                        Button(action: testAPIKey) {
                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 50)
                            } else {
                                Text("Test")
                                    .frame(width: 50)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(apiKey.isEmpty || isValidating)
                    }
                }

                // Validation feedback
                validationFeedbackView

                if !isLocked {
                    Link("Get an API key from Anthropic Console",
                         destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .onChange(of: validationState) { newState in
            if case .valid = newState {
                // Lock the field and persist validated state
                isEditing = false
                apiKeyValidated = true
            }
        }
        .onAppear {
            // Show valid state if previously validated
            if apiKeyValidated && !apiKey.isEmpty {
                validationState = .valid
            }
        }
    }

    @ViewBuilder
    var validationFeedbackView: some View {
        switch validationState {
        case .unknown:
            EmptyView()
        case .validating:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Validating API key...")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        case .valid:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("API key is valid!")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
            .font(.callout)
        case .invalid(let reason):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(reason)
                    .foregroundColor(.red)
            }
            .font(.caption)
        }
    }

    func testAPIKey() {
        isValidating = true
        validationState = .validating

        Task {
            let service = ClaudeService()
            let result = await service.validateAPIKey(apiKey)

            await MainActor.run {
                isValidating = false
                switch result {
                case .valid:
                    validationState = .valid
                    NSSound(named: "Glass")?.play()
                case .invalid(let reason):
                    validationState = .invalid(reason)
                case .networkError(let error):
                    validationState = .invalid("Network error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Hotkey Section

struct HotkeySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcut")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        KeyCapView(symbol: "command")
                        Text("+")
                            .foregroundColor(.secondary)
                        KeyCapView(symbol: "shift")
                        Text("+")
                            .foregroundColor(.secondary)
                        KeyCapView(text: "L")
                    }

                    Spacer()
                }

                Text("Press this shortcut while composing a message to capture the screen, analyze context, and get a refined version in your clipboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct KeyCapView: View {
    var symbol: String?
    var text: String?

    var body: some View {
        Group {
            if let symbol = symbol {
                Image(systemName: symbol)
            } else if let text = text {
                Text(text)
                    .fontWeight(.medium)
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.primary)
        .frame(minWidth: 24, minHeight: 22)
        .padding(.horizontal, 6)
        .background(Color(NSColor.controlColor))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Permissions Section

struct PermissionsSection: View {
    @State private var hasScreenRecordingPermission = false
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            HStack {
                // Status icon
                Image(systemName: hasScreenRecordingPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(hasScreenRecordingPermission ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Screen Recording")
                            .fontWeight(.medium)

                        if hasScreenRecordingPermission {
                            Text("Granted")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        } else {
                            Text("Not Granted")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    Text("Required to capture messaging windows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !hasScreenRecordingPermission {
                    Button("Open Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .onAppear {
            checkPermission()
            // Start a timer to periodically check permission status
            checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                checkPermission()
            }
        }
        .onDisappear {
            checkTimer?.invalidate()
            checkTimer = nil
        }
    }

    func checkPermission() {
        // CGPreflightScreenCaptureAccess is unreliable - it returns false even when granted
        // Instead, try to actually get window list info which requires the permission
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
            // If we can get window names, permission is granted
            // Without permission, window names are nil/empty
            let hasWindowNames = windowList.contains { window in
                if let name = window[kCGWindowName as String] as? String, !name.isEmpty {
                    return true
                }
                return false
            }
            hasScreenRecordingPermission = hasWindowNames
        } else {
            hasScreenRecordingPermission = false
        }
    }
}

// MARK: - Screenshot History Section

struct ScreenshotHistorySection: View {
    @ObservedObject private var history = ScreenshotHistory.shared
    @State private var selectedEntry: ScreenshotEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Screenshot History")
                    .font(.headline)

                Spacer()

                if !history.entries.isEmpty {
                    Button("Clear") {
                        history.clear()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
            }

            if history.entries.isEmpty {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.secondary)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No screenshots yet")
                            .fontWeight(.medium)
                        Text("Press Cmd+Shift+L to capture a window")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(history.entries) { entry in
                            ScreenshotThumbnail(entry: entry, isSelected: selectedEntry?.id == entry.id)
                                .onTapGesture {
                                    if selectedEntry?.id == entry.id {
                                        selectedEntry = nil
                                    } else {
                                        selectedEntry = entry
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Show selected screenshot details
                if let entry = selectedEntry {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let appName = entry.appName {
                                    Text(appName)
                                        .fontWeight(.medium)
                                }
                                if let title = entry.windowTitle, !title.isEmpty {
                                    Text(title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Close") {
                                selectedEntry = nil
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }

                        Image(nsImage: entry.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct ScreenshotThumbnail: View {
    let entry: ScreenshotEntry
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: entry.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 60)
                .clipped()
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isSelected ? 2 : 1)
                )

            Text(entry.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Footer Section

struct FooterSection: View {
    var body: some View {
        HStack {
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Text("v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Preview

struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
    }
}
