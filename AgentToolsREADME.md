# AgentTools

A comprehensive toolkit for adding LLM agent capabilities to CursorBuddy with support for file operations, process execution, and macOS app control.

## Features

### 🗂️ File Operations
- **Read/Write Files**: Full file system access with path expansion
- **Directory Management**: Create, list, and navigate directories
- **File Operations**: Move, copy, delete files and directories

### 💻 Process Execution
- **Shell Commands**: Execute any terminal command with arguments
- **Working Directory**: Support for custom working directories
- **Output Capture**: Capture stdout and stderr from processes

### 🖥️ macOS App Control
- **Launch Apps**: Start applications by bundle identifier
- **Terminate Apps**: Stop running applications (graceful + force)
- **List Running Apps**: Query all active applications
- **AppleScript**: Full AppleScript automation support

## Integration

### With Anthropic (Claude)

```swift
let integration = AgentIntegrationExample()
let response = try await integration.sendToAnthropic(
    apiKey: "your-api-key",
    userMessage: "List all files in ~/Documents"
)
```

### With OpenAI (GPT-4)

```swift
let integration = AgentIntegrationExample()
let response = try await integration.sendToOpenAI(
    apiKey: "your-api-key",
    userMessage: "Create a Python script that prints Hello World"
)
```

### Direct Tool Execution

```swift
// Execute a single tool
let tool = AgentTool.readFile(path: "~/Documents/test.txt")
let result = try await AgentToolExecutor.shared.execute(tool)

// Batch execution
let tools: [AgentTool] = [
    .createDirectory(path: "~/Desktop/MyProject"),
    .createFile(path: "~/Desktop/MyProject/README.md", content: "# My Project"),
    .executeCommand(command: "git", arguments: ["init"], workingDirectory: "~/Desktop/MyProject")
]
let results = await AgentToolExecutor.shared.executeBatch(tools)
```

## Available Tools

### File Tools
| Tool | Description | Parameters |
|------|-------------|------------|
| `read_file` | Read file contents | `path` |
| `write_file` | Write/overwrite file | `path`, `content` |
| `create_file` | Create new file | `path`, `content` |
| `delete_file` | Delete file/directory | `path` |
| `list_directory` | List directory contents | `path` |
| `create_directory` | Create directory | `path` |
| `move_file` | Move/rename file | `from`, `to` |
| `copy_file` | Copy file | `from`, `to` |

### Process Tools
| Tool | Description | Parameters |
|------|-------------|------------|
| `execute_command` | Run shell command | `command`, `arguments`, `working_directory?` |

### App Control Tools
| Tool | Description | Parameters |
|------|-------------|------------|
| `launch_app` | Launch macOS app | `bundle_identifier` |
| `terminate_app` | Stop macOS app | `bundle_identifier` |
| `get_running_apps` | List running apps | none |
| `send_applescript` | Execute AppleScript | `script` |

## Architecture

```
AgentTools/
├── AgentToolTypes.swift         # Core types and tool definitions
├── AgentToolExecutor.swift      # Main execution coordinator
├── AgentToolAdapter.swift       # LLM API adapters (Anthropic/OpenAI)
├── FileToolManager.swift        # File system operations
├── ProcessToolManager.swift     # Process/terminal execution
├── AppControlToolManager.swift  # macOS app control
├── AgentIntegrationExample.swift # Example integrations
└── CompanionManagerExtension.swift # Easy integration with CursorBuddy
```

## Usage Examples

### Example 1: File Management Agent

```swift
let response = try await integration.sendToAnthropic(
    apiKey: apiKey,
    userMessage: """
    Create a new Swift package called "MyLibrary" with:
    1. A Package.swift file
    2. A Sources/MyLibrary directory
    3. A basic MyLibrary.swift file with a hello() function
    """
)
```

The agent will:
1. Create the directory structure
2. Generate appropriate Package.swift
3. Create the source files
4. Report success

### Example 2: Development Workflow

```swift
let response = try await integration.sendToAnthropic(
    apiKey: apiKey,
    userMessage: """
    In ~/Desktop/MyApp:
    1. Initialize a git repository
    2. Create a .gitignore for Swift
    3. Make an initial commit
    4. Show me the git log
    """
)
```

### Example 3: App Automation

```swift
let response = try await integration.sendToAnthropic(
    apiKey: apiKey,
    userMessage: """
    Launch Safari and navigate to apple.com using AppleScript
    """
)
```

### Example 4: System Analysis

```swift
let response = try await integration.sendToAnthropic(
    apiKey: apiKey,
    userMessage: """
    Show me all running apps and tell me which ones are using
    the most resources
    """
)
```

## Security Considerations

⚠️ **Important**: This system provides full file system and terminal access.

### Recommended Safety Measures:

1. **Sandboxing**: Consider restricting operations to specific directories
2. **User Confirmation**: Prompt before destructive operations
3. **Audit Logging**: Log all tool executions
4. **Path Validation**: Validate paths before operations
5. **Command Whitelisting**: Restrict allowed shell commands

### Example Safety Wrapper:

```swift
func executeSafely(_ tool: AgentTool) async throws -> AgentToolResult {
    // Validate the tool
    guard isToolAllowed(tool) else {
        return .error(message: "Tool not allowed by security policy")
    }
    
    // Request user confirmation for destructive operations
    if isDestructive(tool) {
        let confirmed = await requestUserConfirmation(for: tool)
        guard confirmed else {
            return .error(message: "Operation cancelled by user")
        }
    }
    
    // Log the operation
    logToolExecution(tool)
    
    // Execute
    return try await AgentToolExecutor.shared.execute(tool)
}
```

## Permissions Required

Your app will need the following entitlements/permissions:

- ✅ **File Access**: Full Disk Access (for unrestricted file operations)
- ✅ **Process Execution**: com.apple.security.cs.allow-jit (for shell commands)
- ✅ **App Control**: Accessibility API (for advanced app control)
- ✅ **AppleScript**: Automation permission

## Future Enhancements

Potential additions:
- 🌐 Web browsing/scraping tools
- 📧 Email/calendar integration
- 🗄️ Database operations
- 🔐 Keychain access
- 📱 iOS device control
- 🌍 Network operations
- 🖼️ Image processing
- 🎵 Media file handling

## Contributing

When adding new tools:

1. Add enum case to `AgentTool`
2. Add definition to `AgentToolDefinition`
3. Implement handler in appropriate manager
4. Add parsing logic to `AgentToolAdapter`
5. Update this README

## License

Part of CursorBuddy project.
