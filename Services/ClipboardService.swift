import AppKit

class ClipboardService {

    /// Copies text to the system clipboard
    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Gets the current clipboard contents
    func paste() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
}
