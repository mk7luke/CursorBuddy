# Troubleshooting: "Agent Says It Can't Use Tools"

## Problem
The AI agent responds with "I can't access files" or "I don't have permission to execute commands" instead of using the available tools.

## Solutions

### ✅ Solution 1: System Prompt is Now Included (FIXED)

The system prompt has been added to both Anthropic and OpenAI implementations in `AgentConversationHandler`. This explicitly tells the AI it HAS access to tools.

**What was added:**
```swift
// In sendToAnthropic():
"system": AgentSystemPrompts.anthropicSystemPrompt

// In sendToOpenAI():
messages.insert([
    "role": "system",
    "content": AgentSystemPrompts.openAISystemPrompt
], at: 0)
```

### ✅ Solution 2: Verify Tools Are Being Sent

Check that tools are included in API requests:

```swift
// This should print all 13 tools
let tools = AgentToolAdapter.anthropicToolDefinitions()
print("Sending \(tools.count) tools to API")
for tool in tools {
    print("- \(tool["name"] ?? "unknown")")
}
```

Expected output:
```
Sending 13 tools to API
- read_file
- write_file
- create_file
- delete_file
- list_directory
- create_directory
- move_file
- copy_file
- execute_command
- launch_app
- terminate_app
- get_running_apps
- send_applescript
```

### ✅ Solution 3: Test Direct Tool Execution

Verify the tools themselves work:

```swift
import AgentTools

// Test file operations
let result = try await AgentToolExecutor.shared.execute(
    .createFile(path: "~/Desktop/test.txt", content: "Hello!")
)
print(result.message)  // Should say "Successfully wrote file"
```

### ✅ Solution 4: Check API Response Format

Add debug logging to see what the API is returning:

```swift
// In AgentConversationHandler, add logging:
let (data, _) = try await URLSession.shared.data(for: request)

// Add this debug line:
if let jsonString = String(data: data, encoding: .utf8) {
    print("[DEBUG] API Response: \(jsonString)")
}

let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]
```

### ✅ Solution 5: Use More Direct Prompts

Instead of:
> "Can you create a file?"

Try:
> "Create a file at ~/Desktop/test.txt with content 'Hello'"

The more specific and directive, the better.

### ✅ Solution 6: Remind the Agent

If it still says it can't, remind it explicitly:

> "You have access to file system tools. Please use the create_file tool to create ~/Desktop/test.txt"

### ✅ Solution 7: Check API Key & Model

Make sure you're using:
- **Anthropic**: `claude-3-5-sonnet-20241022` or newer (supports tool use)
- **OpenAI**: `gpt-4-turbo-preview` or newer (supports function calling)

Older models might not support tools.

### ✅ Solution 8: Verify Tool Schema Format

The tool definitions should match this format for Anthropic:

```json
{
  "name": "create_file",
  "description": "Create a new file with the specified content",
  "input_schema": {
    "type": "object",
    "properties": {
      "path": {
        "type": "string",
        "description": "Absolute file path"
      },
      "content": {
        "type": "string",
        "description": "Initial content"
      }
    },
    "required": ["path", "content"]
  }
}
```

## Quick Test

Run this to verify everything works end-to-end:

```swift
import AgentTools

Task { @MainActor in
    // 1. Test the tools directly
    print("1️⃣ Testing direct tool execution...")
    let tool = AgentTool.createFile(
        path: "~/Desktop/agent_test.txt",
        content: "Test from AgentTools"
    )
    let result = try await AgentToolExecutor.shared.execute(tool)
    print("   Result: \(result.message)")
    
    // 2. Test with conversation handler
    print("\n2️⃣ Testing conversation handler...")
    let agent = AgentConversationHandler(
        apiKey: "your-api-key-here",
        provider: .anthropic
    )
    
    let response = try await agent.send("""
        Create a file at ~/Desktop/hello.txt with the content 'Hello World'
        """)
    print("   Agent response: \(response)")
    
    // 3. Cleanup
    print("\n3️⃣ Cleaning up...")
    let cleanup = try await AgentToolExecutor.shared.execute(
        .deleteFile(path: "~/Desktop/agent_test.txt")
    )
    print("   \(cleanup.message)")
}
```

## If Still Not Working

### Check for Error Messages

Look for these specific errors:

1. **"Tool not found"** → Tool definitions aren't being sent
2. **"Invalid tool input"** → Schema format is wrong
3. **"Permission denied"** → macOS permissions issue (see below)
4. **"API Error"** → Check API key and network

### macOS Permissions

The app needs:
- ✅ **Full Disk Access** (System Settings → Privacy & Security → Full Disk Access)
- ✅ **Accessibility** (for app control features)

Grant these permissions to your app.

### Enable Verbose Logging

Add this to see detailed execution:

```swift
// In AgentToolExecutor.swift, modify execute():
public func execute(_ tool: AgentTool) async throws -> AgentToolResult {
    print("🔧 [AgentTools] Executing: \(tool)")
    
    let result: AgentToolResult
    switch tool {
    case .readFile(let path):
        print("   📄 Reading file: \(path)")
        result = try await fileManager.readFile(at: path)
    // ... etc
    }
    
    print("   ✅ Result: \(result.message)")
    return result
}
```

## Common Misunderstandings

### ❌ "I need to install packages first"
**No!** Everything is built-in. No external packages needed for basic file/process operations.

### ❌ "I need special permissions"
**Partially true.** For file access beyond the app sandbox, enable Full Disk Access.

### ❌ "The tools aren't being sent to the API"
**Check this!** Add logging to verify the `tools` array is in the request.

### ❌ "The AI model doesn't support tools"
**Use the right model!** Claude 3.5 Sonnet and GPT-4 Turbo both support tools.

## Successful Output

When working correctly, you should see:

```
[AgentTools] Executing: createFile(path: "~/Desktop/test.txt", content: "Hello")
[AgentTools] Result: Successfully created file

Agent response: I've created the file test.txt on your Desktop with the content "Hello".
```

## Still Having Issues?

1. Run `AgentToolsDemo.runAllDemos()` to test all tools
2. Check the demo output for which operations fail
3. Verify API key is valid
4. Try a different model (switch between Anthropic/OpenAI)
5. Check network connectivity
6. Review macOS Console.app for permission errors

---

**The system is now configured to tell the AI it HAS access to tools. The system prompt explicitly states this.**
