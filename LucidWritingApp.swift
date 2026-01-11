import SwiftUI
import Carbon.HIToolbox

@main
struct LucidWritingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    private var hotKeyRef: EventHotKeyRef?

    // Services
    private let screenCapture = ScreenCaptureService()
    private let ocrService = OCRService()
    private let claudeService = ClaudeService()
    private let clipboardService = ClipboardService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMainWindow()
        registerHotKey()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right", accessibilityDescription: "LucidWriting") {
                button.image = image
            } else {
                button.title = "MR"
            }
            button.action = #selector(toggleMainWindow)
            button.target = self
        }
    }

    func setupMainWindow() {
        let contentView = MainWindowView()

        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        mainWindow?.title = "LucidWriting"
        mainWindow?.contentViewController = NSHostingController(rootView: contentView)
        mainWindow?.center()
        mainWindow?.isReleasedWhenClosed = false
        mainWindow?.setFrameAutosaveName("MainWindow")
    }

    @objc func toggleMainWindow() {
        guard let window = mainWindow else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Handle dock icon click when app is already running
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    // Also handle when app becomes active
    func applicationDidBecomeActive(_ notification: Notification) {
        if mainWindow?.isVisible == false {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Hotkey Registration

    func registerHotKey() {
        // Cmd+Shift+L
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D524652) // "MRFR"
        hotKeyID.id = 1

        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 0x25 // 'L' key

        print("Registering hotkey Cmd+Shift+L (keyCode: \(keyCode), modifiers: \(modifiers))")

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            print("Hotkey event handler triggered!")
            NotificationCenter.default.post(name: .triggerMessageRefine, object: nil)
            return noErr
        }, 1, &eventType, nil, nil)

        print("InstallEventHandler result: \(handlerStatus)")

        let registerStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        print("RegisterEventHotKey result: \(registerStatus) (0 = success)")

        if registerStatus != noErr {
            print("ERROR: Failed to register hotkey! Error code: \(registerStatus)")
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleHotKeyPress), name: .triggerMessageRefine, object: nil)
    }

    @objc func handleHotKeyPress() {
        print("Hotkey pressed! Starting refinement...")
        // Remember which app was focused BEFORE we do anything
        screenCapture.rememberFocusedApp()
        Task {
            await refineCurrentMessage()
        }
    }

    // MARK: - Message Refinement

    func refineCurrentMessage() async {
        print("refineCurrentMessage() called")

        // Show processing indicator
        await MainActor.run {
            print("Showing processing window...")
            ProcessingWindowController.shared.show()
            ProcessingState.shared.currentStep = .capturing
        }

        // Get window info that was captured when hotkey was pressed (before processing window shown)
        let windowInfo = screenCapture.getRememberedWindowInfo()

        // Capture the active window
        print("Attempting screen capture...")
        guard let screenshot = screenCapture.captureActiveWindow() else {
            print("Screen capture FAILED")
            await MainActor.run {
                ProcessingWindowController.shared.close()
            }
            showNotification(title: "Capture Failed", body: "Could not capture the active window. Make sure Screen Recording permission is granted.")
            return
        }
        print("Screen capture succeeded")

        // Save to history with the remembered window info
        ScreenshotHistory.shared.add(
            screenshot: screenshot,
            appName: windowInfo?.appName,
            windowTitle: windowInfo?.title
        )

        // Update UI with screenshot
        await MainActor.run {
            ProcessingState.shared.screenshot = screenshot
            ProcessingState.shared.currentStep = .ocr
        }

        // Extract text via OCR
        let ocrText = await ocrService.extractText(from: screenshot)
        print("OCR extracted: \(ocrText.prefix(100))...")

        // Update to analyzing step with OCR text
        await MainActor.run {
            ProcessingState.shared.ocrText = ocrText
            ProcessingState.shared.currentStep = .analyzing
        }

        // Send to Claude for refinement
        do {
            let result = try await claudeService.refineMessage(screenshot: screenshot, ocrText: ocrText)

            // Hide processing indicator
            await MainActor.run {
                ProcessingWindowController.shared.close()
            }

            if let refinedMessage = result.refinedMessage {
                // Play sound
                NSSound(named: "Pop")?.play()

                // Show result window
                await MainActor.run {
                    ResultWindowController.shared.showResult(
                        original: result.originalMessage ?? "(not detected)",
                        refined: refinedMessage,
                        recipient: result.recipient ?? "Unknown",
                        platform: result.platform ?? "Unknown",
                        reasoning: result.reasoning ?? ""
                    ) { [weak self] editedMessage in
                        // Copy the edited message to clipboard
                        self?.clipboardService.copy(editedMessage)
                        NSSound(named: "Tink")?.play()
                    }
                }
            } else {
                showNotification(title: "No Draft Found", body: "Could not find a draft message to refine.")
            }
        } catch {
            await MainActor.run {
                ProcessingWindowController.shared.close()
            }
            showNotification(title: "Refinement Failed", body: error.localizedDescription)
        }
    }

    func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let triggerMessageRefine = Notification.Name("triggerMessageRefine")
}
