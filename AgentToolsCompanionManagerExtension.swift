import Foundation
import AgentTools

/// Extension to add agent tool capabilities to your existing companion system
@MainActor
public extension CompanionManager {
    
    /// Execute an agent action based on LLM response
    func executeAgentTool(_ tool: AgentTool) async throws -> AgentToolResult {
        return try await AgentToolExecutor.shared.execute(tool)
    }
    
    /// Get tool definitions for your LLM API calls
    var anthropicToolDefinitions: [[String: Any]] {
        AgentToolAdapter.anthropicToolDefinitions()
    }
    
    var openAIToolDefinitions: [[String: Any]] {
        AgentToolAdapter.openAIToolDefinitions()
    }
    
    /// Example: Process a user request with tool execution
    func handleAgentRequest(userMessage: String, apiKey: String) async throws -> String {
        let integration = AgentIntegrationExample()
        
        // Use Anthropic (or switch to OpenAI)
        return try await integration.sendToAnthropic(
            apiKey: apiKey,
            userMessage: userMessage
        )
    }
}

// MARK: - Quick Usage Example

/*
 
 Usage in your existing CompanionManager:
 
 ```swift
 // 1. Get the API key from your config
 let apiKey = APIKeyConfig.anthropicAPIKey
 
 // 2. Send a user request that might trigger tools
 let response = try await companionManager.handleAgentRequest(
     userMessage: "Create a new file at ~/Desktop/test.txt with the content 'Hello World'",
     apiKey: apiKey
 )
 
 // 3. The agent will:
 //    - Parse the request
 //    - Call the create_file tool
 //    - Execute it locally
 //    - Return a confirmation
 
 print(response) // "I've created the file test.txt on your Desktop with the content 'Hello World'."
 ```
 
 Or for more control:
 
 ```swift
 // Direct tool execution
 let tool = AgentTool.createFile(
     path: "~/Desktop/test.txt",
     content: "Hello World"
 )
 
 let result = try await companionManager.executeAgentTool(tool)
 
 switch result {
 case .success(let message, let data):
     print("Success: \(message)")
     if let data = data {
         print("Details: \(data)")
     }
     
 case .error(let message):
     print("Error: \(message)")
 }
 ```
 
 */
