import Foundation
import MCP

// MARK: - JSONSchema Extension

extension JSONSchema {
    /// Convert JSONSchema to a JSON-serializable object for the Claude API
    func toJSONObject() -> [String: Any] {
        switch self {
        case .null:
            return ["type": "null"]
            
        case .boolean:
            return ["type": "boolean"]
            
        case .string(let description):
            var result: [String: Any] = ["type": "string"]
            if let desc = description {
                result["description"] = desc
            }
            return result
            
        case .number(let description):
            var result: [String: Any] = ["type": "number"]
            if let desc = description {
                result["description"] = desc
            }
            return result
            
        case .integer(let description):
            var result: [String: Any] = ["type": "integer"]
            if let desc = description {
                result["description"] = desc
            }
            return result
            
        case .array(let items, let description):
            var result: [String: Any] = ["type": "array"]
            if let items = items {
                result["items"] = items.toJSONObject()
            }
            if let desc = description {
                result["description"] = desc
            }
            return result
            
        case .object(let properties, let required, let description):
            var result: [String: Any] = ["type": "object"]
            
            var propsDict: [String: Any] = [:]
            for (key, schema) in properties {
                propsDict[key] = schema.toJSONObject()
            }
            result["properties"] = propsDict
            
            if !required.isEmpty {
                result["required"] = required
            }
            
            if let desc = description {
                result["description"] = desc
            }
            
            return result
            
        case .anyOf(let schemas, let description):
            var result: [String: Any] = [
                "anyOf": schemas.map { $0.toJSONObject() }
            ]
            if let desc = description {
                result["description"] = desc
            }
            return result
        }
    }
}

/// Bridge between AgentTools and MCP protocol
/// This allows AgentTools to work with your existing MCP-based Claude API integration
@MainActor
public final class AgentToolsMCPBridge {
    
    public static let shared = AgentToolsMCPBridge()
    
    private init() {}
    
    // MARK: - MCP Tool Definitions
    
    /// Convert AgentTools to MCP Tool format
    public var mcpTools: [Tool] {
        return [
            // File operations
            createMCPTool(
                name: "read_file",
                description: "Read the contents of a file at the specified path",
                inputSchema: .object(
                    properties: [
                        "path": .string(description: "Absolute file path")
                    ],
                    required: ["path"]
                )
            ),
            createMCPTool(
                name: "write_file",
                description: "Write content to a file, overwriting existing content",
                inputSchema: .object(
                    properties: [
                        "path": .string(description: "Absolute file path"),
                        "content": .string(description: "Content to write")
                    ],
                    required: ["path", "content"]
                )
            ),
            createMCPTool(
                name: "create_file",
                description: "Create a new file with the specified content",
                inputSchema: .object(
                    properties: [
                        "path": .string(description: "Absolute file path"),
                        "content": .string(description: "Initial content")
                    ],
                    required: ["path", "content"]
                )
            ),
            createMCPTool(
                name: "delete_file",
                description: "Delete a file or directory",
                inputSchema: .object(
                    properties: [
                        "path": .string(description: "Absolute file path")
                    ],
                    required: ["path"]
                )
            ),
            createMCPTool(
                name: "list_directory",
                description: "List all files and directories in a directory",
                inputSchema: .object(
                    properties: [
                        "path": .string(description: "Absolute directory path")
                    ],
                    required: ["path"]
                )
            ),
            createMCPTool(
                name: "create_directory",
                description: "Create a new directory",
                inputSchema: .object(
                    properties: [
                        "path": .string(description: "Absolute directory path")
                    ],
                    required: ["path"]
                )
            ),
            createMCPTool(
                name: "move_file",
                description: "Move or rename a file/directory",
                inputSchema: .object(
                    properties: [
                        "from": .string(description: "Source path"),
                        "to": .string(description: "Destination path")
                    ],
                    required: ["from", "to"]
                )
            ),
            createMCPTool(
                name: "copy_file",
                description: "Copy a file/directory to a new location",
                inputSchema: .object(
                    properties: [
                        "from": .string(description: "Source path"),
                        "to": .string(description: "Destination path")
                    ],
                    required: ["from", "to"]
                )
            ),
            createMCPTool(
                name: "execute_command",
                description: "Execute a shell command and return the output",
                inputSchema: .object(
                    properties: [
                        "command": .string(description: "Command to execute"),
                        "arguments": .array(items: .string(description: nil), description: "Command arguments"),
                        "working_directory": .string(description: "Working directory (optional)")
                    ],
                    required: ["command"]
                )
            ),
            createMCPTool(
                name: "launch_app",
                description: "Launch a macOS application by bundle identifier",
                inputSchema: .object(
                    properties: [
                        "bundle_identifier": .string(description: "App bundle ID (e.g., com.apple.Safari)")
                    ],
                    required: ["bundle_identifier"]
                )
            ),
            createMCPTool(
                name: "terminate_app",
                description: "Terminate a running macOS application",
                inputSchema: .object(
                    properties: [
                        "bundle_identifier": .string(description: "App bundle ID")
                    ],
                    required: ["bundle_identifier"]
                )
            ),
            createMCPTool(
                name: "get_running_apps",
                description: "Get a list of all currently running applications",
                inputSchema: .object(properties: [:], required: [])
            ),
            createMCPTool(
                name: "send_applescript",
                description: "Execute an AppleScript to control applications",
                inputSchema: .object(
                    properties: [
                        "script": .string(description: "AppleScript code to execute")
                    ],
                    required: ["script"]
                )
            )
        ]
    }
    
    /// Get Claude-compatible tool definitions
    public var claudeToolDefinitions: [[String: Any]] {
        return mcpTools.compactMap { tool in
            var def: [String: Any] = [
                "name": tool.name,
                "input_schema": tool.inputSchema.toJSONObject()
            ]
            if let desc = tool.description {
                def["description"] = desc
            }
            return def
        }
    }
    
    // MARK: - Tool Execution
    
    /// Execute a tool call from Claude
    public func executeTool(name: String, arguments: [String: Any]) async throws -> String {
        // Parse into AgentTool
        guard let tool = parseToolCall(name: name, arguments: arguments) else {
            throw AgentToolError.invalidToolCall("Unknown tool: \(name)")
        }
        
        // Execute
        let result = try await AgentToolExecutor.shared.execute(tool)
        
        // Return result
        switch result {
        case .success(let message, let data):
            if let data = data {
                var response = message + "\n"
                for (key, value) in data {
                    response += "\(key): \(value)\n"
                }
                return response.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return message
            
        case .error(let message):
            throw AgentToolError.executionFailed(message)
        }
    }
    
    // MARK: - Helpers
    
    private func createMCPTool(name: String, description: String, inputSchema: JSONSchema) -> Tool {
        return Tool(name: name, description: description, inputSchema: inputSchema)
    }
    
    private func parseToolCall(name: String, arguments: [String: Any]) -> AgentTool? {
        switch name {
        case "read_file":
            guard let path = arguments["path"] as? String else { return nil }
            return .readFile(path: path)
            
        case "write_file":
            guard let path = arguments["path"] as? String,
                  let content = arguments["content"] as? String else { return nil }
            return .writeFile(path: path, content: content)
            
        case "create_file":
            guard let path = arguments["path"] as? String,
                  let content = arguments["content"] as? String else { return nil }
            return .createFile(path: path, content: content)
            
        case "delete_file":
            guard let path = arguments["path"] as? String else { return nil }
            return .deleteFile(path: path)
            
        case "list_directory":
            guard let path = arguments["path"] as? String else { return nil }
            return .listDirectory(path: path)
            
        case "create_directory":
            guard let path = arguments["path"] as? String else { return nil }
            return .createDirectory(path: path)
            
        case "move_file":
            guard let from = arguments["from"] as? String,
                  let to = arguments["to"] as? String else { return nil }
            return .moveFile(from: from, to: to)
            
        case "copy_file":
            guard let from = arguments["from"] as? String,
                  let to = arguments["to"] as? String else { return nil }
            return .copyFile(from: from, to: to)
            
        case "execute_command":
            guard let command = arguments["command"] as? String else { return nil }
            let args = arguments["arguments"] as? [String] ?? []
            let workingDir = arguments["working_directory"] as? String
            return .executeCommand(command: command, arguments: args, workingDirectory: workingDir)
            
        case "launch_app":
            guard let bundleID = arguments["bundle_identifier"] as? String else { return nil }
            return .launchApp(bundleIdentifier: bundleID)
            
        case "terminate_app":
            guard let bundleID = arguments["bundle_identifier"] as? String else { return nil }
            return .terminateApp(bundleIdentifier: bundleID)
            
        case "get_running_apps":
            return .getRunningApps
            
        case "send_applescript":
            guard let script = arguments["script"] as? String else { return nil }
            return .sendAppleScript(script: script)
            
        default:
            return nil
        }
    }
}

// MARK: - Errors

public enum AgentToolError: Error, LocalizedError {
    case invalidToolCall(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidToolCall(let msg): return "Invalid tool call: \(msg)"
        case .executionFailed(let msg): return "Tool execution failed: \(msg)"
        }
    }
}
