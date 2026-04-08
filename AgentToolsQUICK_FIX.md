# Agent Tools - Quick Fix Guide

## 🚨 AGENT SAYS "I CAN'T ACCESS FILES" → HERE'S THE FIX

### ✅ **FIXED: System Prompt Added**

The agent now receives a system prompt that explicitly states:

> **"You HAVE FULL ACCESS to file system operations, terminal commands, and application control on macOS."**

This was added to `AgentConversationHandler` in both:
- `sendToAnthropic()` - via `"system": AgentSystemPrompts.anthropicSystemPrompt`
- `sendToOpenAI()` - via system message insertion

---

## 🔧 Quick Verification

Run this to verify everything works:

```swift
import AgentTools

// 1. Validate setup
validateAgentTools()

// 2. Check permissions
checkAgentPermissions()

// 3. Run a quick test
await AgentToolsDemo.demoFileOperations()
```

---

## 💬 How to Talk to the Agent

### ❌ DON'T ASK
- "Can you create a file?"
- "Are you able to read files?"
- "Do you have access to the file system?"

### ✅ JUST TELL IT
- "Create a file at ~/Desktop/test.txt with 'Hello World'"
- "Read ~/Documents/myfile.txt"
- "List all files in ~/Downloads"

**Be directive, not questioning.**

---

## 🛠️ Quick Test Commands

Test each capability:

```swift
let agent = AgentConversationHandler(apiKey: apiKey, provider: .anthropic)

// File operations
await agent.send("Create ~/Desktop/test.txt with content 'Hello'")

// Terminal
await agent.send("Run: ls -la ~/Desktop")

// Apps
await agent.send("List all running apps")

// Automation
await agent.send("Use AppleScript to beep once")
```

---

## 🔍 Debugging Checklist

If agent still says it can't do something:

1. ✅ **System prompt included?**
   - Check: System prompt is now automatically added
   
2. ✅ **Tools being sent?**
   ```swift
   let tools = AgentToolAdapter.anthropicToolDefinitions()
   print("Tools: \(tools.count)")  // Should be 13
   ```

3. ✅ **Right API model?**
   - Anthropic: `claude-3-5-sonnet-20241022` ✅
   - OpenAI: `gpt-4-turbo-preview` ✅

4. ✅ **API key valid?**
   - Test with a simple non-tool request first

5. ✅ **macOS permissions?**
   - System Settings → Privacy & Security → Full Disk Access
   - Add your app to the list

---

## 📝 Example Conversation

**Good conversation flow:**

```
User: "Create a file on my desktop called notes.txt"

Agent: [Uses create_file tool]
      "I've created notes.txt on your Desktop."

User: "Add the text 'Meeting at 3pm' to it"

Agent: [Uses write_file tool]
      "I've added that text to notes.txt."

User: "Now read it back to me"

Agent: [Uses read_file tool]
      "The file contains: Meeting at 3pm"
```

**If agent refuses:**

```
User: "Create a file on my desktop"

Agent: "I don't have access to create files..."

You: "You DO have access. Use the create_file tool with path ~/Desktop/test.txt"

Agent: [Should now use the tool]
```

---

## 🎯 All 13 Available Tools

1. **read_file** - Read file contents
2. **write_file** - Write/overwrite file
3. **create_file** - Create new file
4. **delete_file** - Delete file/directory
5. **list_directory** - List directory contents
6. **create_directory** - Create directory
7. **move_file** - Move/rename
8. **copy_file** - Copy file
9. **execute_command** - Run shell commands
10. **launch_app** - Launch macOS app
11. **terminate_app** - Quit app
12. **get_running_apps** - List running apps
13. **send_applescript** - Execute AppleScript

---

## 🚀 One-Line Setup

```swift
let agent = AgentConversationHandler(apiKey: "your-key", provider: .anthropic)
let response = try await agent.send("Create ~/Desktop/hello.txt with 'Hello World'")
```

That's it! The system prompt is automatically included.

---

## 🆘 Still Not Working?

1. **Read**: `AgentTools/TROUBLESHOOTING.md`
2. **Validate**: Run `validateAgentTools()`
3. **Test directly**: Run `AgentToolsDemo.runAllDemos()`
4. **Check logs**: Look for `[AgentTools]` log messages
5. **Try different model**: Switch between Anthropic/OpenAI

---

## ✨ What Changed

**Before:**
- No system prompt
- Agent didn't know it had tools
- Would say "I can't access files"

**After:**
- System prompt explicitly states capabilities
- Agent knows it has 13 tools available
- Should use tools when appropriate

The fix is in `AgentConversationHandler.swift` - system prompts are now automatically included in all requests.
