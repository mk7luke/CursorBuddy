import Foundation

/// Example integration showing how to use agent tools with Anthropic/OpenAI APIs
@MainActor
public final class AgentIntegrationExample {
    
    private let toolExecutor = AgentToolExecutor.shared
    
    // MARK: - Anthropic Integration Example
    
    /// Example: Send a message to Anthropic with tool support
    public func sendToAnthropic(
        apiKey: String,
        userMessage: String,
        conversationHistory: [[String: Any]] = []
    ) async throws -> String {
        
        var messages = conversationHistory
        messages.append([
            "role": "user",
            "content": userMessage
        ])
        
        // Prepare request with tools
        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 4096,
            "messages": messages,
            "tools": AgentToolAdapter.anthropicToolDefinitions()
        ]
        
        // Make API request
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Process response
        guard let content = response["content"] as? [[String: Any]] else {
            throw AgentError.invalidResponse
        }
        
        // Handle tool use
        var toolResults: [[String: Any]] = []
        for block in content {
            if let type = block["type"] as? String, type == "tool_use" {
                // Execute the tool
                if let tool = AgentToolAdapter.parseAnthropicToolCall(block),
                   let toolUseId = block["id"] as? String {
                    let result = try await toolExecutor.execute(tool)
                    let toolResult = AgentToolAdapter.formatAnthropicToolResult(result, toolUseId: toolUseId)
                    toolResults.append(toolResult)
                }
            }
        }
        
        // If tools were used, send results back
        if !toolResults.isEmpty {
            messages.append([
                "role": "assistant",
                "content": content
            ])
            messages.append([
                "role": "user",
                "content": toolResults
            ])
            
            // Recursive call to get final response
            return try await sendToAnthropic(apiKey: apiKey, userMessage: "", conversationHistory: messages)
        }
        
        // Extract text response
        for block in content {
            if let type = block["type"] as? String, type == "text",
               let text = block["text"] as? String {
                return text
            }
        }
        
        throw AgentError.noTextResponse
    }
    
    // MARK: - OpenAI Integration Example
    
    /// Example: Send a message to OpenAI with tool support
    public func sendToOpenAI(
        apiKey: String,
        userMessage: String,
        conversationHistory: [[String: Any]] = []
    ) async throws -> String {
        
        var messages = conversationHistory
        messages.append([
            "role": "user",
            "content": userMessage
        ])
        
        // Prepare request with tools
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": messages,
            "tools": AgentToolAdapter.openAIToolDefinitions(),
            "tool_choice": "auto"
        ]
        
        // Make API request
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Process response
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AgentError.invalidResponse
        }
        
        // Check for tool calls
        if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
            messages.append(message)
            
            // Execute tools
            for toolCall in toolCalls {
                if let function = toolCall["function"] as? [String: Any],
                   let tool = AgentToolAdapter.parseOpenAIToolCall(function),
                   let toolCallId = toolCall["id"] as? String {
                    let result = try await toolExecutor.execute(tool)
                    
                    messages.append([
                        "role": "tool",
                        "tool_call_id": toolCallId,
                        "content": result.message
                    ])
                }
            }
            
            // Recursive call to get final response
            return try await sendToOpenAI(apiKey: apiKey, userMessage: "", conversationHistory: messages)
        }
        
        // Extract text response
        if let content = message["content"] as? String {
            return content
        }
        
        throw AgentError.noTextResponse
    }
    
    // MARK: - Foundation Models Integration (Optional)
    
    // If you want to use Apple's on-device LLM instead, you could add:
    // - FoundationModels integration with custom tools
    // - This would be fully local and private
}

enum AgentError: Error {
    case invalidResponse
    case noTextResponse
}
