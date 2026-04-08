import AppKit
import Foundation

/// Handles macOS app launching, control, and automation
@MainActor
final class AppControlToolManager {
    
    // MARK: - App Launching
    
    func launchApp(bundleIdentifier: String) async throws -> AgentToolResult {
        let workspace = NSWorkspace.shared
        
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return .error(message: "App not found with bundle identifier: \(bundleIdentifier)")
        }
        
        do {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            try await workspace.openApplication(at: appURL, configuration: config)
            
            return .success(
                message: "Successfully launched app",
                data: [
                    "bundle_identifier": bundleIdentifier,
                    "app_path": appURL.path
                ]
            )
        } catch {
            return .error(message: "Failed to launch app: \(error.localizedDescription)")
        }
    }
    
    func terminateApp(bundleIdentifier: String) async throws -> AgentToolResult {
        let runningApps = NSWorkspace.shared.runningApplications
        
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return .error(message: "App is not running: \(bundleIdentifier)")
        }
        
        let terminated = app.terminate()
        
        if terminated {
            return .success(
                message: "Successfully terminated app",
                data: ["bundle_identifier": bundleIdentifier]
            )
        } else {
            // Try force termination
            let forceTerminated = app.forceTerminate()
            if forceTerminated {
                return .success(
                    message: "Successfully force-terminated app",
                    data: ["bundle_identifier": bundleIdentifier]
                )
            } else {
                return .error(message: "Failed to terminate app: \(bundleIdentifier)")
            }
        }
    }
    
    func getRunningApps() async throws -> AgentToolResult {
        let runningApps = NSWorkspace.shared.runningApplications
        
        var appList: [String] = []
        for app in runningApps {
            if let bundleID = app.bundleIdentifier,
               let name = app.localizedName {
                let active = app.isActive ? " [ACTIVE]" : ""
                appList.append("\(name) (\(bundleID))\(active)")
            }
        }
        
        return .success(
            message: "Found \(appList.count) running apps",
            data: [
                "apps": appList.joined(separator: "\n"),
                "count": "\(appList.count)"
            ]
        )
    }
    
    // MARK: - AppleScript Execution
    
    func executeAppleScript(_ script: String) async throws -> AgentToolResult {
        var error: NSDictionary?
        
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            return .error(message: "AppleScript error: \(errorMessage)")
        }
        
        let outputString = result?.stringValue ?? "Script executed (no output)"
        
        return .success(
            message: "AppleScript executed successfully",
            data: [
                "script": script,
                "output": outputString
            ]
        )
    }
}
