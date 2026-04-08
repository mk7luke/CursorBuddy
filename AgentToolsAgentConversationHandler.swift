import Foundation

/// A complete agent conversation handler that manages multi-turn tool use
@MainActor
public final class AgentConversationHandler {
    
    private let executor = AgentToolExecutor.shared
    private var conversationHistory: [[String: Any]] = []
    private let apiKey: String
    private let provider: LLMProvider
    
    public enum LLMProvider {
        case anthropic
        case openai
    }
    
    public init(apiKey: String, provider: LLMProvider = .anthropic) {
        self.apiKey = apiKey
        self.provider = provider
    }
    
    // MARK: - Main Interface
    
    /// Send a message and get a response, automatically handling tool calls
    public func send(_ message: String) async throws -> String {
        conversationHistory.append([
            "role": "user",
            "content": message
        ])
        
        let response: String
        switch provider {
        case .anthropic:
            response = try await sendToAnthropic()
        case .openai:
            response = try await sendToOpenAI()
        }
        
        return response
    }
    
    /// Reset the conversation
    public func reset() {
        conversationHistory.removeAll()
    }
    
    /// Get the full conversation history
    public var history: [[String: Any]] {
        conversationHistory
    }
    
    // MARK: - Anthropic Implementation
    
    private func sendToAnthropic() async throws -> String {
        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 4096,
            "messages": conversationHistory,
            "tools": AgentToolAdapter.anthropicToolDefinitions(),
            "system": AgentSystemPrompts.anthropicSystemPrompt
        ]
        
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        guard let content = response["content"] as? [[String: Any]] else {
            throw AgentError.invalidResponse
        }
        
        // Check if tools were used
        var hasTools = false
        var toolResults: [[String: Any]] = []
        
        for block in content {
            if let type = block["type"] as? String, type == "tool_use" {
                hasTools = true
                if let tool = AgentToolAdapter.parseAnthropicToolCall(block),
                   let toolUseId = block["id"] as? String {
                    print("[AgentTools] Executing: \(tool)")
                    let result = try await executor.execute(tool)
                    print("[AgentTools] Result: \(result.message)")
                    let toolResult = AgentToolAdapter.formatAnthropicToolResult(result, toolUseId: toolUseId)
                    toolResults.append(toolResult)
                }
            }
        }
        
        if hasTools {
            // Add assistant response and tool results to history
            conversationHistory.append([
                "role": "assistant",
                "content": content
            ])
            conversationHistory.append([
                "role": "user",
                "content": toolResults
            ])
            
            // Continue conversation to get final response
            return try await sendToAnthropic()
        }
        
        // Extract text response
        for block in content {
            if let type = block["type"] as? String, type == "text",
               let text = block["text"] as? String {
                // Add to history
                conversationHistory.append([
                    "role": "assistant",
                    "content": text
                ])
                return text
            }
        }
        
        throw AgentError.noTextResponse
    }
    
    // MARK: - OpenAI Implementation
    
    private func sendToOpenAI() async throws -> String {
        // Add system message if this is the first message
        var messages = conversationHistory
        if messages.isEmpty || (messages.first?["role"] as? String) != "system" {
            messages.insert([
                "role": "system",
                "content": AgentSystemPrompts.openAISystemPrompt
            ], at: 0)
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": messages,
            "tools": AgentToolAdapter.openAIToolDefinitions(),
            "tool_choice": "auto"
        ]
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AgentError.invalidResponse
        }
        
        // Check for tool calls
        if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
            conversationHistory.append(message)
            
            for toolCall in toolCalls {
                if let function = toolCall["function"] as? [String: Any],
                   let tool = AgentToolAdapter.parseOpenAIToolCall(function),
                   let toolCallId = toolCall["id"] as? String {
                    print("[AgentTools] Executing: \(tool)")
                    let result = try await executor.execute(tool)
                    print("[AgentTools] Result: \(result.message)")
                    
                    conversationHistory.append([
                        "role": "tool",
                        "tool_call_id": toolCallId,
                        "content": result.message
                    ])
                }
            }
            
            return try await sendToOpenAI()
        }
        
        // Extract text response
        if let content = message["content"] as? String {
            conversationHistory.append([
                "role": "assistant",
                "content": content
            ])
            return content
        }
        
        throw AgentError.noTextResponse
    }
}

// MARK: - Usage Examples

/*
 
 ### Basic Usage
 
 ```swift
 // Initialize with your API key
 let agent = AgentConversationHandler(
     apiKey: APIKeyConfig.anthropicAPIKey,
     provider: .anthropic
 )
 
 // Send messages
 let response1 = try await agent.send("Create a file called test.txt on my desktop with the content 'Hello'")
 print(response1)
 // "I've created test.txt on your Desktop with the content 'Hello'."
 
 let response2 = try await agent.send("Now read it back to me")
 print(response2)
 // "The file contains: Hello"
 
 // The agent remembers the conversation context
 let response3 = try await agent.send("Delete that file")
 print(response3)
 // "I've deleted test.txt from your Desktop."
 ```
 
 ### Multi-Step Workflows
 
 ```swift
 let agent = AgentConversationHandler(apiKey: apiKey)
 
 let response = try await agent.send("""
 I want to create a new Swift project. Please:
 1. Create a directory called HelloWorld on my Desktop
 2. Create a Package.swift file
 3. Create a main.swift file that prints Hello World
 4. Show me the directory structure
 """)
 
 print(response)
 // The agent will execute all steps and confirm completion
 ```
 
 ### Complex Tasks
 
 ```swift
 let agent = AgentConversationHandler(apiKey: apiKey)
 
 let response = try await agent.send("""
 Analyze my Desktop:
 1. List all files
 2. Count how many are directories vs files
 3. Find the 5 largest files
 4. Create a report.txt file with this information
 """)
 
 print(response)
 // Agent executes multiple commands and creates the report
 ```
 
 ### App Automation
 
 ```swift
 let agent = AgentConversationHandler(apiKey: apiKey)
 
 let response = try await agent.send("""
 Please:
 1. Show me what apps are currently running
 2. Launch Safari if it's not running
 3. Use AppleScript to navigate to apple.com
 """)
 
 print(response)
 ```
 
 */
