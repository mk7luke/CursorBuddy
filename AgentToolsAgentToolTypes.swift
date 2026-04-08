import Foundation

/// Represents all available agent tools
public enum AgentTool: Sendable {
    // File operations
    case readFile(path: String)
    case writeFile(path: String, content: String)
    case createFile(path: String, content: String)
    case deleteFile(path: String)
    case listDirectory(path: String)
    case createDirectory(path: String)
    case moveFile(from: String, to: String)
    case copyFile(from: String, to: String)
    
    // Process/Terminal operations
    case executeCommand(command: String, arguments: [String], workingDirectory: String?)
    
    // App control
    case launchApp(bundleIdentifier: String)
    case terminateApp(bundleIdentifier: String)
    case getRunningApps
    case sendAppleScript(script: String)
}

/// Result from executing an agent tool
public enum AgentToolResult: Sendable {
    case success(message: String, data: [String: String]? = nil)
    case error(message: String)
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    public var message: String {
        switch self {
        case .success(let msg, _): return msg
        case .error(let msg): return msg
        }
    }
}

/// Tool definition for LLM tool calling (Anthropic/OpenAI format)
public struct AgentToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]
    
    public init(name: String, description: String, inputSchema: [String: Any]) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
    
    // Standard tool definitions
    public static let allTools: [AgentToolDefinition] = [
        .readFile,
        .writeFile,
        .createFile,
        .deleteFile,
        .listDirectory,
        .createDirectory,
        .moveFile,
        .copyFile,
        .executeCommand,
        .launchApp,
        .terminateApp,
        .getRunningApps,
        .sendAppleScript
    ]
}

// MARK: - Tool Definitions

extension AgentToolDefinition {
    public static let readFile = AgentToolDefinition(
        name: "read_file",
        description: "Read the contents of a file at the specified path",
        inputSchema: [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute file path"]
            ],
            "required": ["path"]
        ]
    )
    
    public static let writeFile = AgentToolDefinition(
        name: "write_file",
        description: "Write content to a file, overwriting existing content",
        inputSchema: [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute file path"],
                "content": ["type": "string", "description": "Content to write"]
            ],
            "required": ["path", "content"]
        ]
    )
    
    public static let createFile = AgentToolDefinition(
        name: "create_file",
        description: "Create a new file with the specified content",
        inputSchema: [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute file path"],
                "content": ["type": "string", "description": "Initial content"]
            ],
            "required": ["path", "content"]
        ]
    )
    
    public static let deleteFile = AgentToolDefinition(
        name: "delete_file",
        description: "Delete a file or directory",
        inputSchema: [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute file path"]
            ],
            "required": ["path"]
        ]
    )
    
    public static let listDirectory = AgentToolDefinition(
        name: "list_directory",
        description: "List all files and directories in a directory",
        inputSchema: [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute directory path"]
            ],
            "required": ["path"]
        ]
    )
    
    public static let createDirectory = AgentToolDefinition(
        name: "create_directory",
        description: "Create a new directory",
        inputSchema: [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute directory path"]
            ],
            "required": ["path"]
        ]
    )
    
    public static let moveFile = AgentToolDefinition(
        name: "move_file",
        description: "Move or rename a file/directory",
        inputSchema: [
            "type": "object",
            "properties": [
                "from": ["type": "string", "description": "Source path"],
                "to": ["type": "string", "description": "Destination path"]
            ],
            "required": ["from", "to"]
        ]
    )
    
    public static let copyFile = AgentToolDefinition(
        name: "copy_file",
        description: "Copy a file/directory to a new location",
        inputSchema: [
            "type": "object",
            "properties": [
                "from": ["type": "string", "description": "Source path"],
                "to": ["type": "string", "description": "Destination path"]
            ],
            "required": ["from", "to"]
        ]
    )
    
    public static let executeCommand = AgentToolDefinition(
        name: "execute_command",
        description: "Execute a shell command and return the output",
        inputSchema: [
            "type": "object",
            "properties": [
                "command": ["type": "string", "description": "Command to execute"],
                "arguments": ["type": "array", "items": ["type": "string"], "description": "Command arguments"],
                "working_directory": ["type": "string", "description": "Working directory (optional)"]
            ],
            "required": ["command"]
        ]
    )
    
    public static let launchApp = AgentToolDefinition(
        name: "launch_app",
        description: "Launch a macOS application by bundle identifier",
        inputSchema: [
            "type": "object",
            "properties": [
                "bundle_identifier": ["type": "string", "description": "App bundle ID (e.g., com.apple.Safari)"]
            ],
            "required": ["bundle_identifier"]
        ]
    )
    
    public static let terminateApp = AgentToolDefinition(
        name: "terminate_app",
        description: "Terminate a running macOS application",
        inputSchema: [
            "type": "object",
            "properties": [
                "bundle_identifier": ["type": "string", "description": "App bundle ID"]
            ],
            "required": ["bundle_identifier"]
        ]
    )
    
    public static let getRunningApps = AgentToolDefinition(
        name: "get_running_apps",
        description: "Get a list of all currently running applications",
        inputSchema: [
            "type": "object",
            "properties": [:]
        ]
    )
    
    public static let sendAppleScript = AgentToolDefinition(
        name: "send_applescript",
        description: "Execute an AppleScript to control applications",
        inputSchema: [
            "type": "object",
            "properties": [
                "script": ["type": "string", "description": "AppleScript code to execute"]
            ],
            "required": ["script"]
        ]
    )
}
