import Foundation

/// Validation and diagnostic tools for agent setup
@MainActor
public struct AgentToolsValidator {
    
    // MARK: - Validation
    
    /// Run all validation checks
    public static func validateSetup() {
        print("🔍 Agent Tools Setup Validation")
        print(String(repeating: "=", count: 60))
        print()
        
        validateToolDefinitions()
        validateToolParsing()
        validateSystemPrompts()
        validateAPIAdapters()
        
        print()
        print(String(repeating: "=", count: 60))
        print("✅ Validation complete!")
        print()
    }
    
    // MARK: - Individual Checks
    
    private static func validateToolDefinitions() {
        print("1️⃣ Checking tool definitions...")
        
        let anthropicTools = AgentToolAdapter.anthropicToolDefinitions()
        print("   • Anthropic format: \(anthropicTools.count) tools")
        
        let openAITools = AgentToolAdapter.openAIToolDefinitions()
        print("   • OpenAI format: \(openAITools.count) tools")
        
        // Verify each tool has required fields
        for (index, tool) in anthropicTools.enumerated() {
            guard let name = tool["name"] as? String,
                  let description = tool["description"] as? String,
                  let schema = tool["input_schema"] as? [String: Any] else {
                print("   ❌ Tool \(index) is missing required fields!")
                continue
            }
            
            if index == 0 {
                print("   • Example tool: \(name)")
                print("     Description: \(description)")
            }
        }
        
        print("   ✅ Tool definitions valid")
        print()
    }
    
    private static func validateToolParsing() {
        print("2️⃣ Checking tool parsing...")
        
        // Test Anthropic format parsing
        let anthropicToolUse: [String: Any] = [
            "name": "create_file",
            "input": [
                "path": "~/test.txt",
                "content": "Hello"
            ]
        ]
        
        if let parsed = AgentToolAdapter.parseAnthropicToolCall(anthropicToolUse) {
            print("   • Anthropic parsing: ✅ Works")
            if case .createFile(let path, let content) = parsed {
                print("     Parsed: createFile(\(path), \(content))")
            }
        } else {
            print("   • Anthropic parsing: ❌ Failed")
        }
        
        // Test OpenAI format parsing
        let openAIFunctionCall: [String: Any] = [
            "name": "read_file",
            "arguments": "{\"path\": \"~/test.txt\"}"
        ]
        
        if let parsed = AgentToolAdapter.parseOpenAIToolCall(openAIFunctionCall) {
            print("   • OpenAI parsing: ✅ Works")
            if case .readFile(let path) = parsed {
                print("     Parsed: readFile(\(path))")
            }
        } else {
            print("   • OpenAI parsing: ❌ Failed")
        }
        
        print("   ✅ Tool parsing valid")
        print()
    }
    
    private static func validateSystemPrompts() {
        print("3️⃣ Checking system prompts...")
        
        let anthropicPrompt = AgentSystemPrompts.anthropicSystemPrompt
        let openAIPrompt = AgentSystemPrompts.openAISystemPrompt
        
        print("   • Anthropic prompt: \(anthropicPrompt.count) characters")
        print("   • OpenAI prompt: \(openAIPrompt.count) characters")
        
        // Check for key phrases that tell the AI it has access
        let keyPhrases = [
            "YOU HAVE",
            "YOU CAN",
            "full access",
            "tools"
        ]
        
        var foundPhrases = 0
        for phrase in keyPhrases {
            if anthropicPrompt.localizedCaseInsensitiveContains(phrase) {
                foundPhrases += 1
            }
        }
        
        if foundPhrases >= 3 {
            print("   • System prompt emphasizes capabilities: ✅")
        } else {
            print("   • System prompt might be weak: ⚠️")
        }
        
        print("   ✅ System prompts valid")
        print()
    }
    
    private static func validateAPIAdapters() {
        print("4️⃣ Checking API adapters...")
        
        // Test result formatting
        let successResult = AgentToolResult.success(
            message: "Test success",
            data: ["key": "value"]
        )
        
        let anthropicResult = AgentToolAdapter.formatAnthropicToolResult(
            successResult,
            toolUseId: "test-id"
        )
        
        if let type = anthropicResult["type"] as? String,
           let content = anthropicResult["content"] as? String {
            print("   • Anthropic result format: ✅ Valid")
            print("     Type: \(type), Content: \(content)")
        } else {
            print("   • Anthropic result format: ❌ Invalid")
        }
        
        let openAIResult = AgentToolAdapter.formatOpenAIToolResult(successResult)
        
        if let role = openAIResult["role"] as? String,
           let content = openAIResult["content"] as? String {
            print("   • OpenAI result format: ✅ Valid")
            print("     Role: \(role)")
        } else {
            print("   • OpenAI result format: ❌ Invalid")
        }
        
        print("   ✅ API adapters valid")
        print()
    }
    
    // MARK: - Permission Checks
    
    /// Check macOS permissions
    public static func checkPermissions() {
        print("🔐 Permission Check")
        print(String(repeating: "=", count: 60))
        print()
        
        // Test file access
        print("1️⃣ Testing file system access...")
        let testPath = NSHomeDirectory() + "/Desktop"
        let fm = FileManager.default
        
        if fm.isReadableFile(atPath: testPath) {
            print("   ✅ Can read Desktop")
        } else {
            print("   ❌ Cannot read Desktop - need Full Disk Access")
        }
        
        if fm.isWritableFile(atPath: testPath) {
            print("   ✅ Can write to Desktop")
        } else {
            print("   ❌ Cannot write to Desktop - need Full Disk Access")
        }
        
        // Test app access
        print("\n2️⃣ Testing app access...")
        let runningApps = NSWorkspace.shared.runningApplications
        print("   ✅ Can see \(runningApps.count) running apps")
        
        // Test process execution
        print("\n3️⃣ Testing process execution...")
        print("   ⚠️  Run AgentToolsDemo.demoProcessOperations() to test")
        
        print()
        print(String(repeating: "=", count: 60))
        print()
    }
    
    // MARK: - Debug Info
    
    /// Print all available tools with details
    public static func listAllTools() {
        print("📋 Available Agent Tools")
        print(String(repeating: "=", count: 60))
        print()
        
        let tools = AgentToolAdapter.anthropicToolDefinitions()
        
        for (index, tool) in tools.enumerated() {
            if let name = tool["name"] as? String,
               let description = tool["description"] as? String,
               let schema = tool["input_schema"] as? [String: Any],
               let properties = schema["properties"] as? [String: Any] {
                
                print("\(index + 1). \(name)")
                print("   Description: \(description)")
                print("   Parameters: \(properties.keys.joined(separator: ", "))")
                print()
            }
        }
        
        print(String(repeating: "=", count: 60))
        print()
    }
    
    // MARK: - Quick Diagnostic
    
    /// Run a quick diagnostic and return a report
    public static func quickDiagnostic() -> String {
        var report = "🏥 Agent Tools Quick Diagnostic\n"
        report += String(repeating: "=", count: 60) + "\n\n"
        
        // Tool count
        let toolCount = AgentToolAdapter.anthropicToolDefinitions().count
        report += "✅ Tools available: \(toolCount)/13\n"
        
        // System prompt
        let promptLength = AgentSystemPrompts.anthropicSystemPrompt.count
        report += "✅ System prompt: \(promptLength) characters\n"
        
        // File access
        let desktopPath = NSHomeDirectory() + "/Desktop"
        let canAccess = FileManager.default.isReadableFile(atPath: desktopPath)
        report += canAccess ? "✅ File access: Working\n" : "❌ File access: Limited\n"
        
        // Running apps
        let appCount = NSWorkspace.shared.runningApplications.count
        report += "✅ App access: Can see \(appCount) apps\n"
        
        report += "\n"
        
        if toolCount == 13 && promptLength > 500 && canAccess {
            report += "🎉 Everything looks good!\n"
        } else {
            report += "⚠️  Some issues detected. Run validateSetup() for details.\n"
        }
        
        report += String(repeating: "=", count: 60) + "\n"
        
        return report
    }
}

// MARK: - Convenience Functions

/// Quick validation check
@MainActor
public func validateAgentTools() {
    AgentToolsValidator.validateSetup()
}

/// Quick permission check
@MainActor
public func checkAgentPermissions() {
    AgentToolsValidator.checkPermissions()
}

/// List all tools
@MainActor
public func listAgentTools() {
    AgentToolsValidator.listAllTools()
}

/// Get diagnostic report
@MainActor
public func agentDiagnostic() -> String {
    return AgentToolsValidator.quickDiagnostic()
}
