import Foundation

/// Converts between agent tool calls and LLM API formats (Anthropic/OpenAI)
public struct AgentToolAdapter {
    
    // MARK: - Tool Definitions for LLM
    
    /// Get all tool definitions in Anthropic format
    public static func anthropicToolDefinitions() -> [[String: Any]] {
        return AgentToolDefinition.allTools.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": tool.inputSchema
            ]
        }
    }
    
    /// Get all tool definitions in OpenAI format
    public static func openAIToolDefinitions() -> [[String: Any]] {
        return AgentToolDefinition.allTools.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.inputSchema
                ]
            ]
        }
    }
    
    // MARK: - Parse Tool Calls from LLM Response
    
    /// Parse Anthropic tool use block
    public static func parseAnthropicToolCall(_ toolUse: [String: Any]) -> AgentTool? {
        guard let name = toolUse["name"] as? String,
              let input = toolUse["input"] as? [String: Any] else {
            return nil
        }
        
        return parseTool(name: name, input: input)
    }
    
    /// Parse OpenAI function call
    public static func parseOpenAIToolCall(_ functionCall: [String: Any]) -> AgentTool? {
        guard let name = functionCall["name"] as? String,
              let argumentsString = functionCall["arguments"] as? String,
              let argumentsData = argumentsString.data(using: .utf8),
              let input = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            return nil
        }
        
        return parseTool(name: name, input: input)
    }
    
    // MARK: - Tool Parsing
    
    private static func parseTool(name: String, input: [String: Any]) -> AgentTool? {
        switch name {
        // File operations
        case "read_file":
            guard let path = input["path"] as? String else { return nil }
            return .readFile(path: path)
            
        case "write_file":
            guard let path = input["path"] as? String,
                  let content = input["content"] as? String else { return nil }
            return .writeFile(path: path, content: content)
            
        case "create_file":
            guard let path = input["path"] as? String,
                  let content = input["content"] as? String else { return nil }
            return .createFile(path: path, content: content)
            
        case "delete_file":
            guard let path = input["path"] as? String else { return nil }
            return .deleteFile(path: path)
            
        case "list_directory":
            guard let path = input["path"] as? String else { return nil }
            return .listDirectory(path: path)
            
        case "create_directory":
            guard let path = input["path"] as? String else { return nil }
            return .createDirectory(path: path)
            
        case "move_file":
            guard let from = input["from"] as? String,
                  let to = input["to"] as? String else { return nil }
            return .moveFile(from: from, to: to)
            
        case "copy_file":
            guard let from = input["from"] as? String,
                  let to = input["to"] as? String else { return nil }
            return .copyFile(from: from, to: to)
            
        // Process operations
        case "execute_command":
            guard let command = input["command"] as? String else { return nil }
            let arguments = input["arguments"] as? [String] ?? []
            let workingDirectory = input["working_directory"] as? String
            return .executeCommand(command: command, arguments: arguments, workingDirectory: workingDirectory)
            
        // App control
        case "launch_app":
            guard let bundleID = input["bundle_identifier"] as? String else { return nil }
            return .launchApp(bundleIdentifier: bundleID)
            
        case "terminate_app":
            guard let bundleID = input["bundle_identifier"] as? String else { return nil }
            return .terminateApp(bundleIdentifier: bundleID)
            
        case "get_running_apps":
            return .getRunningApps
            
        case "send_applescript":
            guard let script = input["script"] as? String else { return nil }
            return .sendAppleScript(script: script)
            
        default:
            return nil
        }
    }
    
    // MARK: - Format Results for LLM
    
    /// Format result for Anthropic tool_result content block
    public static func formatAnthropicToolResult(_ result: AgentToolResult, toolUseId: String) -> [String: Any] {
        return [
            "type": "tool_result",
            "tool_use_id": toolUseId,
            "content": result.message,
            "is_error": !result.isSuccess
        ]
    }
    
    /// Format result for OpenAI function response
    public static func formatOpenAIToolResult(_ result: AgentToolResult) -> [String: Any] {
        var response: [String: Any] = [
            "role": "function",
            "content": result.message
        ]
        
        if case .success(_, let data) = result, let data = data {
            if let jsonData = try? JSONSerialization.data(withJSONObject: data),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                response["content"] = jsonString
            }
        }
        
        return response
    }
}
