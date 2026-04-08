import Foundation

/// Handles all file system operations for AgentTools
@MainActor
final class FileToolManager {
    
    private let fileManager = FileManager.default
    
    // MARK: - File Reading
    
    func readFile(at path: String) async throws -> AgentToolResult {
        let expandedPath = expandPath(path)
        
        guard fileManager.fileExists(atPath: expandedPath) else {
            return .error(message: "File not found at path: \(path)")
        }
        
        do {
            let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
            return .success(
                message: "Successfully read file",
                data: [
                    "path": expandedPath,
                    "content": content,
                    "size": "\(content.count) characters"
                ]
            )
        } catch {
            return .error(message: "Failed to read file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Writing
    
    func writeFile(at path: String, content: String) async throws -> AgentToolResult {
        let expandedPath = expandPath(path)
        
        do {
            try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
            return .success(
                message: "Successfully wrote to file",
                data: [
                    "path": expandedPath,
                    "size": "\(content.count) characters"
                ]
            )
        } catch {
            return .error(message: "Failed to write file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Creation
    
    func createFile(at path: String, content: String) async throws -> AgentToolResult {
        let expandedPath = expandPath(path)
        
        // Check if file already exists
        if fileManager.fileExists(atPath: expandedPath) {
            return .error(message: "File already exists at path: \(path)")
        }
        
        // Create parent directory if needed
        let parentDir = (expandedPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: parentDir) {
            do {
                try fileManager.createDirectory(
                    atPath: parentDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                return .error(message: "Failed to create parent directory: \(error.localizedDescription)")
            }
        }
        
        do {
            try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
            return .success(
                message: "Successfully created file",
                data: [
                    "path": expandedPath,
                    "size": "\(content.count) characters"
                ]
            )
        } catch {
            return .error(message: "Failed to create file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Deletion
    
    func deleteFile(at path: String) async throws -> AgentToolResult {
        let expandedPath = expandPath(path)
        
        guard fileManager.fileExists(atPath: expandedPath) else {
            return .error(message: "File not found at path: \(path)")
        }
        
        do {
            try fileManager.removeItem(atPath: expandedPath)
            return .success(
                message: "Successfully deleted file",
                data: ["path": expandedPath]
            )
        } catch {
            return .error(message: "Failed to delete file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Directory Operations
    
    func listDirectory(at path: String) async throws -> AgentToolResult {
        let expandedPath = expandPath(path)
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .error(message: "Directory not found at path: \(path)")
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)
            let sortedContents = contents.sorted()
            
            var itemDetails: [String] = []
            for item in sortedContents {
                let itemPath = (expandedPath as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)
                let type = isDir.boolValue ? "📁" : "📄"
                itemDetails.append("\(type) \(item)")
            }
            
            let listing = itemDetails.joined(separator: "\n")
            
            return .success(
                message: "Successfully listed directory",
                data: [
                    "path": expandedPath,
                    "count": "\(sortedContents.count) items",
                    "contents": listing
                ]
            )
        } catch {
            return .error(message: "Failed to list directory: \(error.localizedDescription)")
        }
    }
    
    func createDirectory(at path: String) async throws -> AgentToolResult {
        let expandedPath = expandPath(path)
        
        if fileManager.fileExists(atPath: expandedPath) {
            return .error(message: "Directory already exists at path: \(path)")
        }
        
        do {
            try fileManager.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return .success(
                message: "Successfully created directory",
                data: ["path": expandedPath]
            )
        } catch {
            return .error(message: "Failed to create directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Operations
    
    func moveFile(from sourcePath: String, to destinationPath: String) async throws -> AgentToolResult {
        let expandedSource = expandPath(sourcePath)
        let expandedDest = expandPath(destinationPath)
        
        guard fileManager.fileExists(atPath: expandedSource) else {
            return .error(message: "Source file not found: \(sourcePath)")
        }
        
        if fileManager.fileExists(atPath: expandedDest) {
            return .error(message: "Destination already exists: \(destinationPath)")
        }
        
        do {
            try fileManager.moveItem(atPath: expandedSource, toPath: expandedDest)
            return .success(
                message: "Successfully moved file",
                data: [
                    "from": expandedSource,
                    "to": expandedDest
                ]
            )
        } catch {
            return .error(message: "Failed to move file: \(error.localizedDescription)")
        }
    }
    
    func copyFile(from sourcePath: String, to destinationPath: String) async throws -> AgentToolResult {
        let expandedSource = expandPath(sourcePath)
        let expandedDest = expandPath(destinationPath)
        
        guard fileManager.fileExists(atPath: expandedSource) else {
            return .error(message: "Source file not found: \(sourcePath)")
        }
        
        if fileManager.fileExists(atPath: expandedDest) {
            return .error(message: "Destination already exists: \(destinationPath)")
        }
        
        do {
            try fileManager.copyItem(atPath: expandedSource, toPath: expandedDest)
            return .success(
                message: "Successfully copied file",
                data: [
                    "from": expandedSource,
                    "to": expandedDest
                ]
            )
        } catch {
            return .error(message: "Failed to copy file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func expandPath(_ path: String) -> String {
        let nsPath = NSString(string: path)
        return nsPath.expandingTildeInPath
    }
}
