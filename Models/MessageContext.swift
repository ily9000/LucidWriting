import Foundation

struct MessageContext {
    let appName: String?
    let windowTitle: String?
    let ocrText: String
    let timestamp: Date

    init(appName: String? = nil, windowTitle: String? = nil, ocrText: String) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.ocrText = ocrText
        self.timestamp = Date()
    }

    /// Detects which messaging platform this is
    var platform: MessagingPlatform {
        let app = appName?.lowercased() ?? ""
        let title = windowTitle?.lowercased() ?? ""

        if app.contains("messages") || app.contains("imessage") {
            return .iMessage
        } else if app.contains("slack") {
            return .slack
        } else if app.contains("discord") {
            return .discord
        } else if app.contains("chrome") || app.contains("safari") || app.contains("firefox") || app.contains("arc") {
            // Check window title for web apps
            if title.contains("gmail") || title.contains("mail.google") {
                return .gmail
            } else if title.contains("linkedin") {
                return .linkedin
            } else if title.contains("twitter") || title.contains("x.com") {
                return .twitter
            } else if title.contains("slack") {
                return .slack
            }
            return .browser
        }

        return .unknown
    }
}

enum MessagingPlatform: String {
    case iMessage = "iMessage"
    case slack = "Slack"
    case discord = "Discord"
    case gmail = "Gmail"
    case linkedin = "LinkedIn"
    case twitter = "Twitter/X"
    case browser = "Browser"
    case unknown = "Unknown"
}
