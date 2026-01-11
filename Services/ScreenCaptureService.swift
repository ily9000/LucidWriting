import Cocoa
import ScreenCaptureKit

class ScreenCaptureService {

    // Store the PID of the app that was active before we triggered
    private var previousAppPID: Int32?
    // Store window info captured at the same time
    private var previousWindowInfo: (title: String?, appName: String?, windowID: CGWindowID)?

    /// Call this BEFORE showing any windows to remember which app was focused
    func rememberFocusedApp() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        previousWindowInfo = nil

        // Get the window list once
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            print("Warning: Could not get window list")
            return
        }

        // First try the frontmost application
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.processIdentifier != myPID {
            previousAppPID = frontApp.processIdentifier

            // Also capture window info for this app
            if let windowInfo = windowList.first(where: { window in
                guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
                      let layer = window[kCGWindowLayer as String] as? Int,
                      layer == 0
                else { return false }
                return windowPID == frontApp.processIdentifier
            }),
            let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                let title = windowInfo[kCGWindowName as String] as? String
                previousWindowInfo = (title: title, appName: frontApp.localizedName, windowID: windowID)
            }

            print("Remembered focused app: \(frontApp.localizedName ?? "unknown") (PID: \(previousAppPID!))")
            return
        }

        // Fallback: Find the topmost window that isn't ours from the window list
        for window in windowList {
            guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  layer == 0,  // Normal window layer
                  windowPID != myPID
            else { continue }

            previousAppPID = windowPID
            let appName = NSRunningApplication(processIdentifier: windowPID)?.localizedName
            let title = window[kCGWindowName as String] as? String
            previousWindowInfo = (title: title, appName: appName, windowID: windowID)
            print("Remembered topmost window app: \(appName ?? "unknown") (PID: \(windowPID))")
            return
        }

        print("Warning: Could not find any app to remember")
    }

    /// Returns the window info that was captured when rememberFocusedApp() was called
    func getRememberedWindowInfo() -> (title: String?, appName: String?, windowID: CGWindowID)? {
        return previousWindowInfo
    }

    /// Captures the currently focused window (works correctly on multi-screen setups)
    func captureActiveWindow() -> NSImage? {
        // Get all on-screen windows, ordered front-to-back
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            print("Failed to get window list")
            return nil
        }

        let myPID = ProcessInfo.processInfo.processIdentifier

        // Use the remembered PID, or find the topmost non-MessageRefiner window
        let targetPID: Int32? = previousAppPID ?? {
            // Fallback: Find the first normal window that isn't ours
            for window in windowList {
                guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
                      let layer = window[kCGWindowLayer as String] as? Int,
                      layer == 0,  // Normal window layer
                      windowPID != myPID  // Not our window
                else { continue }
                return windowPID
            }
            return nil
        }()

        guard let pid = targetPID else {
            print("No target app found to capture")
            return nil
        }

        // Find the TOPMOST window belonging to the target app
        // CGWindowListCopyWindowInfo returns windows in front-to-back order
        // Use layer == 0 to filter only normal windows (not menu bar, dock, etc.)
        guard let windowInfo = windowList.first(where: { window in
            guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0  // Normal window layer
            else { return false }
            return windowPID == pid
        }),
        let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
            let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "unknown"
            print("No window found for app: \(appName)")
            return nil
        }

        let windowName = windowInfo[kCGWindowName as String] as? String ?? "untitled"
        print("Capturing window: '\(windowName)' (ID: \(windowID))")

        // Capture the window
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            print("Failed to capture window image")
            return nil
        }

        // Clear the remembered PID after capture
        previousAppPID = nil

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Captures the screen containing the focused window (for multi-monitor support)
    func captureScreenWithFocusedWindow() -> NSImage? {
        // First, find the focused window's bounds
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return captureScreen()
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return captureScreen()
        }

        let pid = frontApp.processIdentifier

        // Find focused window and its bounds
        guard let windowInfo = windowList.first(where: { window in
            guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { return false }
            return windowPID == pid
        }),
        let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
        let x = boundsDict["X"],
        let y = boundsDict["Y"],
        let width = boundsDict["Width"],
        let height = boundsDict["Height"] else {
            return captureScreen()
        }

        let windowCenter = CGPoint(x: x + width / 2, y: y + height / 2)

        // Find the screen containing this window's center point
        let targetScreen = NSScreen.screens.first { screen in
            // NSScreen coordinates are bottom-left origin, CGWindow uses top-left
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            let flippedY = primaryHeight - windowCenter.y
            return screen.frame.contains(CGPoint(x: windowCenter.x, y: flippedY))
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = targetScreen else {
            return nil
        }

        // Capture that specific screen
        let screenRect = screen.frame

        guard let cgImage = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: screenRect.size)
    }

    /// Fallback: captures the screen with the mouse cursor (better than NSScreen.main)
    func captureScreen() -> NSImage? {
        // Find the screen containing the mouse cursor
        let mouseLocation = NSEvent.mouseLocation

        let targetScreen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = targetScreen else { return nil }

        let screenRect = screen.frame

        guard let cgImage = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: screenRect.size)
    }

    /// Gets the title of the active window (useful for context)
    func getActiveWindowTitle() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let pid = frontApp.processIdentifier

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let appWindow = windowList.first { window in
            guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { return false }
            return windowPID == pid
        }

        return appWindow?[kCGWindowName as String] as? String
    }

    /// Gets the name of the active application
    func getActiveAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    /// Gets comprehensive info about the focused window
    func getFocusedWindowInfo() -> (title: String?, appName: String?, windowID: CGWindowID)? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let pid = frontApp.processIdentifier

        guard let windowInfo = windowList.first(where: { window in
            guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { return false }
            return windowPID == pid
        }),
        let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
            return nil
        }

        let title = windowInfo[kCGWindowName as String] as? String
        let appName = frontApp.localizedName

        return (title: title, appName: appName, windowID: windowID)
    }
}
