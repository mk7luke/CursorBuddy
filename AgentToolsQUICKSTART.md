# Quick Start Guide: Adding Agent Tools to CursorBuddy

## ✅ What's Been Added

A complete agent tooling system has been added to your CursorBuddy project with:

- **13 different tools** for file operations, process execution, and app control
- **Anthropic (Claude) integration** ready to use
- **OpenAI (GPT-4) integration** ready to use  
- **Batch execution** for multi-step workflows
- **Conversational agent handler** with context memory

## 📦 Package Structure

```
CursorBuddy/
├── Package.swift (✅ UPDATED - now includes AgentTools module)
└── AgentTools/ (✅ NEW MODULE)
    ├── AgentToolTypes.swift              # Core types & tool definitions
    ├── AgentToolExecutor.swift           # Main execution engine
    ├── AgentToolAdapter.swift            # LLM API adapters
    ├── FileToolManager.swift             # File operations
    ├── ProcessToolManager.swift          # Shell/terminal
    ├── AppControlToolManager.swift       # macOS app control
    ├── AgentIntegrationExample.swift     # API examples
    ├── AgentConversationHandler.swift    # Conversational agent
    ├── CompanionManagerExtension.swift   # Easy integration
    ├── AgentToolsDemo.swift              # Demos & tests
    └── README.md                         # Full documentation
```

## 🚀 Quick Usage

### Option 1: Use the Conversation Handler (Easiest)

```swift
import AgentTools

// In your CompanionManager or wherever you handle user messages
let agent = AgentConversationHandler(
    apiKey: APIKeyConfig.anthropicAPIKey,  // or your API key
    provider: .anthropic  // or .openai
)

// Send a message
let response = try await agent.send("Create a file on my desktop called test.txt")
print(response)
```

### Option 2: Direct Tool Execution

```swift
import AgentTools

// Execute a single tool directly
let tool = AgentTool.readFile(path: "~/Desktop/test.txt")
let result = try await AgentToolExecutor.shared.execute(tool)

switch result {
case .success(let message, let data):
    print("✅ \(message)")
    if let content = data?["content"] {
        print("File content: \(content)")
    }
case .error(let message):
    print("❌ \(message)")
}
```

### Option 3: Integrate with Existing CompanionManager

```swift
// The extension is already available!
extension CompanionManager {
    func executeAgentTool(_ tool: AgentTool) async throws -> AgentToolResult
    var anthropicToolDefinitions: [[String: Any]]
    var openAIToolDefinitions: [[String: Any]]
}

// Use it:
let result = try await companionManager.executeAgentTool(
    .createFile(path: "~/Desktop/hello.txt", content: "Hello World")
)
```

## 🧪 Testing It Out

### Run the Demo

Add this to your app somewhere (maybe in CompanionAppDelegate):

```swift
import AgentTools

// In applicationDidFinishLaunching or any @MainActor context:
Task {
    await AgentToolsDemo.runAllDemos()
}
```

This will test:
- ✅ File creation, reading, writing, deleting
- ✅ Directory operations
- ✅ Shell command execution
- ✅ App listing and control
- ✅ AppleScript execution
- ✅ Batch operations

### Or Test Individual Demos

```swift
await AgentToolsDemo.demoFileOperations()
await AgentToolsDemo.demoProcessOperations()
await AgentToolsDemo.demoAppControl()
await AgentToolsDemo.demoBatchOperations()
```

## 🔑 Setting Up API Keys

You'll need an API key from either:
- **Anthropic**: https://console.anthropic.com
- **OpenAI**: https://platform.openai.com

Then use it:

```swift
let agent = AgentConversationHandler(
    apiKey: "your-api-key-here",
    provider: .anthropic
)
```

## 💡 Real-World Examples

### Example 1: File Management

```swift
let agent = AgentConversationHandler(apiKey: apiKey)

let response = try await agent.send("""
Create a Swift package on my Desktop called "MyLibrary" with:
- Package.swift
- Sources/MyLibrary/MyLibrary.swift
- A README.md
""")
```

### Example 2: Git Workflow

```swift
let response = try await agent.send("""
In my project at ~/Desktop/MyApp:
1. Initialize git
2. Create a .gitignore for Swift
3. Make initial commit
4. Show me git status
""")
```

### Example 3: Development Tasks

```swift
let response = try await agent.send("""
Find all .swift files in ~/Desktop/MyProject and tell me:
1. Total number of files
2. Total lines of code
3. Create a summary.txt with this info
""")
```

### Example 4: App Automation

```swift
let response = try await agent.send("""
1. Check if Xcode is running
2. If not, launch it
3. Use AppleScript to create a new project
""")
```

## 🔒 Security Considerations

⚠️ **Important**: These tools have full system access!

### Recommended Safety Measures:

1. **Validate paths** before file operations
2. **Confirm destructive operations** with the user
3. **Whitelist allowed commands** for shell execution
4. **Sandbox to specific directories** if possible
5. **Log all operations** for audit trail

### Example Safety Wrapper:

```swift
func safeSend(_ message: String) async throws -> String {
    // Show user what will be done
    print("Agent will execute: \(message)")
    
    // Optional: Ask for confirmation
    let confirmed = await showConfirmationDialog(message)
    guard confirmed else { return "Operation cancelled" }
    
    // Execute
    return try await agent.send(message)
}
```

## 📋 Available Tools Summary

| Category | Tools |
|----------|-------|
| **Files** | read, write, create, delete, list, copy, move |
| **Directories** | create, list |
| **Process** | execute shell commands |
| **Apps** | launch, terminate, list running apps |
| **Automation** | AppleScript execution |

See `AgentTools/README.md` for full details on each tool.

## 🎯 Next Steps

1. **Test the demos** to verify everything works
2. **Get an API key** from Anthropic or OpenAI
3. **Integrate into your UI** where appropriate
4. **Add safety measures** as needed
5. **Extend with custom tools** for your use case

## 🛠️ Extending the System

To add a new tool:

1. Add enum case to `AgentTool` in `AgentToolTypes.swift`
2. Add definition to `AgentToolDefinition`  
3. Implement handler in appropriate manager
4. Add parsing in `AgentToolAdapter.parseTool()`
5. Test it!

Example:

```swift
// 1. Add to AgentTool enum
case searchText(path: String, query: String)

// 2. Add definition
public static let searchText = AgentToolDefinition(
    name: "search_text",
    description: "Search for text in a file",
    inputSchema: [
        "type": "object",
        "properties": [
            "path": ["type": "string"],
            "query": ["type": "string"]
        ],
        "required": ["path", "query"]
    ]
)

// 3. Implement in FileToolManager
func searchText(at path: String, query: String) async throws -> AgentToolResult {
    // Implementation
}

// 4. Add to executor
case .searchText(let path, let query):
    return try await fileManager.searchText(at: path, query: query)

// 5. Add parsing
case "search_text":
    guard let path = input["path"] as? String,
          let query = input["query"] as? String else { return nil }
    return .searchText(path: path, query: query)
```

## 📚 Additional Resources

- Full tool documentation: `AgentTools/README.md`
- Demo code: `AgentTools/AgentToolsDemo.swift`
- Integration examples: `AgentTools/AgentIntegrationExample.swift`
- Conversation handler: `AgentTools/AgentConversationHandler.swift`

## ❓ Common Issues

**Q: "Permission denied" errors?**  
A: Your app needs Full Disk Access in System Settings → Privacy & Security

**Q: "Command not found" errors?**  
A: Make sure you're using full paths or the command exists in `/usr/bin`

**Q: API errors?**  
A: Check your API key and internet connection

**Q: Want to restrict file access?**  
A: Add path validation in `FileToolManager.expandPath()`

---

**You're all set!** The agent tooling system is fully integrated and ready to use. 🎉
