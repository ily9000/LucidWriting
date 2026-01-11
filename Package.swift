// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MessageRefiner",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MessageRefiner",
            path: ".",
            exclude: ["Package.swift"],
            sources: [
                "MessageRefinerApp.swift",
                "Views/MenuBarView.swift",
                "Views/SettingsView.swift",
                "Services/ScreenCaptureService.swift",
                "Services/OCRService.swift",
                "Services/ClaudeService.swift",
                "Services/ClipboardService.swift",
                "Services/NotesService.swift",
                "Models/MessageContext.swift"
            ]
        )
    ]
)
