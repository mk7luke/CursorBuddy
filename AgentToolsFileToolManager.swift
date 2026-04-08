import Foundation

/// Handles all file system operations for agents
@MainActor
final class FileToolManager {
    
    private let fileManager = FileManager.default
    
    // MARK: - Read Operations
    
    func readFile(at path: String) async throws -> AgentToolResult {
        let url = URL(fileURLWithPath: expandPath(path))
        
        guard fileManager.fileExists(atPath: url.path) else {
            return .error(message: "File not found: \(path)")
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return .success(
                message: "Successfully read file",
                data: [
                    "path": path,
                    "content": content,
                    "size": "\(content.utf8.count) bytes"
                ]
            )
        } catch {
            return .error(message: "Failed to read file: \(error.localizedDescription)")
        }
    }
    
    func listDirectory(at path: String) async throws -> AgentToolResult {
        let url = URL(fileURLWithPath: expandPath(path))
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            var items: [String] = []
            for itemURL in contents {
                let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let size = (try? itemURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                let name = itemURL.lastPathComponent
                let type = isDirectory ? "dir" : "file"
                items.append("\(type): \(name) (\(size) bytes)")
            }
            
            return .success(
                message: "Found \(items.count) items",
                data: [
                    "path": path,
                    "items": items.joined(separator: "\n"),
                    "count": "\(items.count)"
                ]
            )
        } catch {
            return .error(message: "Failed to list directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Write Operations
    
    func writeFile(at path: String, content: String) async throws -> AgentToolResult {
        let url = URL(fileURLWithPath: expandPath(path))
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return .success(
                message: "Successfully wrote file",
                data: [
                    "path": path,
                    "size": "\(content.utf8.count) bytes"
                ]
            )
        } catch {
            return .error(message: "Failed to write file: \(error.localizedDescription)")
        }
    }
    
    func createFile(at path: String, content: String) async throws -> AgentToolResult {
        let url = URL(fileURLWithPath: expandPath(path))
        
        guard !fileManager.fileExists(atPath: url.path) else {
            return .error(message: "File already exists: \(path)")
        }
        
        // Create parent directories if needed
        let parentDir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            do {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                return .error(message: "Failed to create parent directory: \(error.localizedDescription)")
            }
        }
        
        return try await writeFile(at: path, content: content)
    }
    
    // MARK: - Delete Operations
    
    func deleteFile(at path: String) async throws -> AgentToolResult {
        let url = URL(fileURLWithPath: expandPath(path))
        
        guard fileManager.fileExists(atPath: url.path) else {
            return .error(message: "File not found: \(path)")
        }
        
        do {
            try fileManager.removeItem(at: url)
            return .success(message: "Successfully deleted: \(path)")
        } catch {
            return .error(message: "Failed to delete: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Directory Operations
    
    func createDirectory(at path: String) async throws -> AgentToolResult {
        let url = URL(fileURLWithPath: expandPath(path))
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return .success(message: "Successfully created directory: \(path)")
        } catch {
            return .error(message: "Failed to create directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Move/Copy Operations
    
    func moveFile(from sourcePath: String, to destPath: String) async throws -> AgentToolResult {
        let sourceURL = URL(fileURLWithPath: expandPath(sourcePath))
        let destURL = URL(fileURLWithPath: expandPath(destPath))
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return .error(message: "Source file not found: \(sourcePath)")
        }
        
        do {
            try fileManager.moveItem(at: sourceURL, to: destURL)
            return .success(message: "Successfully moved from \(sourcePath) to \(destPath)")
        } catch {
            return .error(message: "Failed to move file: \(error.localizedDescription)")
        }
    }
    
    func copyFile(from sourcePath: String, to destPath: String) async throws -> AgentToolResult {
        let sourceURL = URL(fileURLWithPath: expandPath(sourcePath))
        let destURL = URL(fileURLWithPath: expandPath(destPath))
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return .error(message: "Source file not found: \(sourcePath)")
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            return .success(message: "Successfully copied from \(sourcePath) to \(destPath)")
        } catch {
            return .error(message: "Failed to copy file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return NSString(string: path).expandingTildeInPath
        }
        return path
    }
}
