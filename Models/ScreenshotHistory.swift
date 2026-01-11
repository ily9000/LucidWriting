import Cocoa
import Combine

struct ScreenshotEntry: Identifiable {
    let id = UUID()
    let image: NSImage
    let timestamp: Date
    let appName: String?
    let windowTitle: String?
}

class ScreenshotHistory: ObservableObject {
    static let shared = ScreenshotHistory()

    @Published var entries: [ScreenshotEntry] = []

    private let maxEntries = 20

    private init() {}

    func add(screenshot: NSImage, appName: String? = nil, windowTitle: String? = nil) {
        let entry = ScreenshotEntry(
            image: screenshot,
            timestamp: Date(),
            appName: appName,
            windowTitle: windowTitle
        )

        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)

            // Keep only the most recent entries
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}
