import Foundation

/// Main coordinator for executing agent tools
@MainActor
public final class AgentToolExecutor {
    
    public static let shared = AgentToolExecutor()
    
    private let fileManager: FileToolManager
    private let processManager: ProcessToolManager
    private let appManager: AppControlToolManager
    
    private init() {
        self.fileManager = FileToolManager()
        self.processManager = ProcessToolManager()
        self.appManager = AppControlToolManager()
    }
    
    // MARK: - Tool Execution
    
    public func execute(_ tool: AgentTool) async throws -> AgentToolResult {
        switch tool {
        case .readFile(let path):
            return try await fileManager.readFile(at: path)
            
        case .writeFile(let path, let content):
            return try await fileManager.writeFile(at: path, content: content)
            
        case .createFile(let path, let content):
            return try await fileManager.createFile(at: path, content: content)
            
        case .deleteFile(let path):
            return try await fileManager.deleteFile(at: path)
            
        case .listDirectory(let path):
            return try await fileManager.listDirectory(at: path)
            
        case .createDirectory(let path):
            return try await fileManager.createDirectory(at: path)
            
        case .moveFile(let from, let to):
            return try await fileManager.moveFile(from: from, to: to)
            
        case .copyFile(let from, let to):
            return try await fileManager.copyFile(from: from, to: to)
            
        case .executeCommand(let command, let arguments, let workingDirectory):
            return try await processManager.execute(
                command: command,
                arguments: arguments,
                workingDirectory: workingDirectory
            )
            
        case .launchApp(let bundleIdentifier):
            return try await appManager.launchApp(bundleIdentifier: bundleIdentifier)
            
        case .terminateApp(let bundleIdentifier):
            return try await appManager.terminateApp(bundleIdentifier: bundleIdentifier)
            
        case .getRunningApps:
            return try await appManager.getRunningApps()
            
        case .sendAppleScript(let script):
            return try await appManager.executeAppleScript(script)
        }
    }
    
    // MARK: - Batch Execution
    
    public func executeBatch(_ tools: [AgentTool]) async -> [AgentToolResult] {
        var results: [AgentToolResult] = []
        
        for tool in tools {
            do {
                let result = try await execute(tool)
                results.append(result)
                
                // Stop on first error if desired
                if case .error = result {
                    break
                }
            } catch {
                results.append(.error(message: "Execution failed: \(error.localizedDescription)"))
                break
            }
        }
        
        return results
    }
}
