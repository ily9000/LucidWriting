import SwiftUI

enum ProcessingStep: String {
    case capturing = "Capturing screen..."
    case ocr = "Extracting text (OCR)..."
    case analyzing = "Analyzing with Claude..."
    case done = "Done!"
}

struct ProcessingWindowView: View {
    @ObservedObject var state = ProcessingState.shared

    var body: some View {
        VStack(spacing: 12) {
            // Screenshot preview (if available)
            if let screenshot = state.screenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 380, maxHeight: 200)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(radius: 2)
            }

            // Progress indicator
            if state.currentStep != .done {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
            }

            Text(state.currentStep == .done ? "Analysis Complete!" : "Refining your message...")
                .font(.headline)

            Text(state.currentStep.rawValue)
                .font(.callout)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.2), value: state.currentStep)

            // OCR text preview (if available and step is past OCR)
            if let ocrText = state.ocrText, !ocrText.isEmpty,
               state.currentStep == .analyzing || state.currentStep == .done {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extracted Text:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(ocrText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 80)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(width: 420, height: state.screenshot != nil ? 420 : 150)
    }
}

// MARK: - Processing State (Observable)

class ProcessingState: ObservableObject {
    static let shared = ProcessingState()

    @Published var currentStep: ProcessingStep = .capturing
    @Published var screenshot: NSImage?
    @Published var ocrText: String?

    func reset() {
        currentStep = .capturing
        screenshot = nil
        ocrText = nil
    }
}

// MARK: - Processing Window Controller

class ProcessingWindowController {
    static let shared = ProcessingWindowController()

    private var window: NSWindow?

    func show() {
        // Close existing window if any
        window?.close()

        let contentView = ProcessingWindowView()

        // Reset state for new processing
        ProcessingState.shared.reset()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window?.title = "Processing"
        window?.contentViewController = NSHostingController(rootView: contentView)
        window?.isReleasedWhenClosed = false
        window?.level = .floating

        // Position on the screen where the mouse is (for multi-monitor support)
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let windowFrame = window!.frame
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window?.center()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }
}

// MARK: - Preview

struct ProcessingWindowView_Previews: PreviewProvider {
    static var previews: some View {
        ProcessingWindowView()
    }
}
