import Foundation

/// Handles process execution and terminal operations
@MainActor
final class ProcessToolManager {
    
    func execute(
        command: String,
        arguments: [String],
        workingDirectory: String?
    ) async throws -> AgentToolResult {
        let process = Process()
        
        // Set up the command
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = [command] + arguments
        process.arguments = args
        
        // Set working directory if provided
        if let workingDir = workingDirectory {
            let expandedPath = expandPath(workingDir)
            process.currentDirectoryURL = URL(fileURLWithPath: expandedPath)
        }
        
        // Set up pipes for stdout and stderr
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = nil
        
        return await withCheckedContinuation { continuation in
            do {
                // Read output asynchronously
                var outputData = Data()
                var errorData = Data()
                
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        outputData.append(data)
                    }
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        errorData.append(data)
                    }
                }
                
                process.terminationHandler = { process in
                    // Stop reading
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    let exitCode = process.terminationStatus
                    
                    if exitCode == 0 {
                        continuation.resume(returning: .success(
                            message: "Command executed successfully",
                            data: [
                                "command": command,
                                "arguments": arguments.joined(separator: " "),
                                "output": output,
                                "exit_code": "0"
                            ]
                        ))
                    } else {
                        continuation.resume(returning: .error(
                            message: "Command failed with exit code \(exitCode)\nOutput: \(output)\nError: \(error)"
                        ))
                    }
                }
                
                try process.run()
                
            } catch {
                continuation.resume(returning: .error(
                    message: "Failed to execute command: \(error.localizedDescription)"
                ))
            }
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
