import SwiftUI

struct ResultWindowView: View {
    let originalMessage: String
    let initialRefinedMessage: String
    let recipient: String
    let platform: String
    let reasoning: String
    let onCopy: (String) -> Void  // Now passes the edited message
    let onDismiss: () -> Void

    @State private var editedMessage: String = ""
    @State private var copied = false
    @State private var customInstruction: String = ""
    @State private var isRefining = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Message Refined")
                        .font(.headline)
                    Text("\(platform) • To: \(recipient)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Original message
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Original", systemImage: "text.quote")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(originalMessage)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }

                    // Arrow
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.down")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }

                    // Refined message (editable)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Refined", systemImage: "sparkles")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)

                            Spacer()

                            if editedMessage != initialRefinedMessage {
                                Button("Reset") {
                                    editedMessage = initialRefinedMessage
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }

                            Text("Click to edit")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        TextEditor(text: $editedMessage)
                            .font(.body)
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 200)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Re-refine with custom instruction
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Refine again with instruction", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("e.g., 'make it shorter' or 'more formal for CEO'", text: $customInstruction)
                                .textFieldStyle(.roundedBorder)

                            Button(action: refineAgain) {
                                if isRefining {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(customInstruction.isEmpty || isRefining)
                        }
                    }

                    // Reasoning
                    if !reasoning.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Changes made", systemImage: "lightbulb")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(reasoning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Action buttons
            HStack {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: {
                    onCopy(editedMessage)
                    copied = true

                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy to Clipboard")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 500, minHeight: 550)
        .onAppear {
            editedMessage = initialRefinedMessage
        }
    }

    private func refineAgain() {
        isRefining = true

        Task {
            let service = ClaudeService()
            if let refined = await service.refineWithInstruction(
                message: editedMessage,
                instruction: customInstruction,
                recipient: recipient,
                platform: platform
            ) {
                await MainActor.run {
                    editedMessage = refined
                    customInstruction = ""
                    isRefining = false
                    NSSound(named: "Pop")?.play()
                }
            } else {
                await MainActor.run {
                    isRefining = false
                }
            }
        }
    }
}

// MARK: - Result Window Controller

class ResultWindowController {
    static let shared = ResultWindowController()

    private var window: NSWindow?

    func showResult(original: String, refined: String, recipient: String, platform: String, reasoning: String, onCopy: @escaping (String) -> Void) {
        // Close existing window if any
        window?.close()

        let contentView = ResultWindowView(
            originalMessage: original,
            initialRefinedMessage: refined,
            recipient: recipient,
            platform: platform,
            reasoning: reasoning,
            onCopy: onCopy,
            onDismiss: { [weak self] in
                self?.window?.close()
            }
        )

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window?.title = "Refined Message"
        window?.contentViewController = NSHostingController(rootView: contentView)
        window?.center()
        window?.isReleasedWhenClosed = false
        window?.level = .floating  // Keep on top

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

// MARK: - Preview

struct ResultWindowView_Previews: PreviewProvider {
    static var previews: some View {
        ResultWindowView(
            originalMessage: "hey can u send me the report when u get a chance thx",
            initialRefinedMessage: "Hi! When you get a chance, could you please send me the report? Thanks!",
            recipient: "John Smith",
            platform: "iMessage",
            reasoning: "Added proper greeting, expanded abbreviations, improved punctuation and tone.",
            onCopy: { _ in },
            onDismiss: {}
        )
    }
}
