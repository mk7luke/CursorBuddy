import Foundation
import AgentTools

/// Demo/testing functions for agent tools
@MainActor
public struct AgentToolsDemo {
    
    // MARK: - File Operations Demo
    
    public static func demoFileOperations() async {
        print("=== Agent Tools: File Operations Demo ===\n")
        
        let executor = AgentToolExecutor.shared
        let testDir = "~/Desktop/AgentToolsTest"
        let testFile = "\(testDir)/test.txt"
        
        do {
            // 1. Create directory
            print("1️⃣ Creating test directory...")
            let dirResult = try await executor.execute(.createDirectory(path: testDir))
            print("   ✅ \(dirResult.message)\n")
            
            // 2. Create file
            print("2️⃣ Creating test file...")
            let createResult = try await executor.execute(
                .createFile(path: testFile, content: "Hello from Agent Tools!")
            )
            print("   ✅ \(createResult.message)\n")
            
            // 3. Read file
            print("3️⃣ Reading file...")
            let readResult = try await executor.execute(.readFile(path: testFile))
            if case .success(_, let data) = readResult, let content = data?["content"] {
                print("   ✅ Content: \(content)\n")
            }
            
            // 4. Write to file
            print("4️⃣ Updating file...")
            let writeResult = try await executor.execute(
                .writeFile(path: testFile, content: "Updated content!\nLine 2\nLine 3")
            )
            print("   ✅ \(writeResult.message)\n")
            
            // 5. List directory
            print("5️⃣ Listing directory...")
            let listResult = try await executor.execute(.listDirectory(path: testDir))
            if case .success(_, let data) = listResult, let items = data?["items"] {
                print("   ✅ Contents:\n\(items)\n")
            }
            
            // 6. Copy file
            print("6️⃣ Copying file...")
            let copyResult = try await executor.execute(
                .copyFile(from: testFile, to: "\(testDir)/test_copy.txt")
            )
            print("   ✅ \(copyResult.message)\n")
            
            // 7. Clean up
            print("7️⃣ Cleaning up...")
            let deleteResult = try await executor.execute(.deleteFile(path: testDir))
            print("   ✅ \(deleteResult.message)\n")
            
            print("✨ File operations demo completed successfully!\n")
            
        } catch {
            print("❌ Error: \(error)\n")
        }
    }
    
    // MARK: - Process Operations Demo
    
    public static func demoProcessOperations() async {
        print("=== Agent Tools: Process Operations Demo ===\n")
        
        let executor = AgentToolExecutor.shared
        
        do {
            // 1. List files with ls
            print("1️⃣ Running 'ls' command...")
            let lsResult = try await executor.execute(
                .executeCommand(command: "ls", arguments: ["-la", "~"], workingDirectory: nil)
            )
            if case .success(_, let data) = lsResult, let output = data?["output"] {
                print("   ✅ Output (first 500 chars):\n\(String(output.prefix(500)))\n")
            }
            
            // 2. Echo command
            print("2️⃣ Running 'echo' command...")
            let echoResult = try await executor.execute(
                .executeCommand(command: "echo", arguments: ["Hello from Agent!"], workingDirectory: nil)
            )
            if case .success(_, let data) = echoResult, let output = data?["output"] {
                print("   ✅ Output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))\n")
            }
            
            // 3. System info
            print("3️⃣ Getting system info...")
            let unameResult = try await executor.execute(
                .executeCommand(command: "uname", arguments: ["-a"], workingDirectory: nil)
            )
            if case .success(_, let data) = unameResult, let output = data?["output"] {
                print("   ✅ System: \(output.trimmingCharacters(in: .whitespacesAndNewlines))\n")
            }
            
            print("✨ Process operations demo completed successfully!\n")
            
        } catch {
            print("❌ Error: \(error)\n")
        }
    }
    
    // MARK: - App Control Demo
    
    public static func demoAppControl() async {
        print("=== Agent Tools: App Control Demo ===\n")
        
        let executor = AgentToolExecutor.shared
        
        do {
            // 1. List running apps
            print("1️⃣ Listing running apps...")
            let appsResult = try await executor.execute(.getRunningApps)
            if case .success(_, let data) = appsResult {
                let count = data?["count"] ?? "?"
                print("   ✅ Found \(count) running apps\n")
                if let apps = data?["apps"] {
                    // Show first 10 apps
                    let appList = apps.components(separatedBy: "\n").prefix(10).joined(separator: "\n")
                    print("   First 10 apps:\n\(appList)\n")
                }
            }
            
            // 2. AppleScript demo (safe - just beep)
            print("2️⃣ Running AppleScript...")
            let scriptResult = try await executor.execute(
                .sendAppleScript(script: "beep 1")
            )
            print("   ✅ \(scriptResult.message)\n")
            
            // 3. AppleScript to get Finder info
            print("3️⃣ Getting Finder info via AppleScript...")
            let finderScript = """
            tell application "Finder"
                return name of startup disk
            end tell
            """
            let finderResult = try await executor.execute(.sendAppleScript(script: finderScript))
            if case .success(_, let data) = finderResult, let output = data?["output"] {
                print("   ✅ Startup disk: \(output)\n")
            }
            
            print("✨ App control demo completed successfully!\n")
            
        } catch {
            print("❌ Error: \(error)\n")
        }
    }
    
    // MARK: - Batch Operations Demo
    
    public static func demoBatchOperations() async {
        print("=== Agent Tools: Batch Operations Demo ===\n")
        
        let executor = AgentToolExecutor.shared
        let projectPath = "~/Desktop/BatchDemo"
        
        let tools: [AgentTool] = [
            .createDirectory(path: projectPath),
            .createFile(path: "\(projectPath)/README.md", content: "# My Project\n\nCreated by Agent Tools!"),
            .createFile(path: "\(projectPath)/main.swift", content: "print(\"Hello, World!\")"),
            .createDirectory(path: "\(projectPath)/Sources"),
            .listDirectory(path: projectPath),
            .executeCommand(command: "wc", arguments: ["-l", "\(projectPath)/README.md"], workingDirectory: nil),
            .deleteFile(path: projectPath)
        ]
        
        print("📦 Executing \(tools.count) tools in batch...\n")
        
        let results = await executor.executeBatch(tools)
        
        for (index, result) in results.enumerated() {
            let emoji = result.isSuccess ? "✅" : "❌"
            print("\(emoji) Tool \(index + 1): \(result.message)")
        }
        
        print("\n✨ Batch operations demo completed!\n")
    }
    
    // MARK: - Tool Definitions Demo
    
    public static func demoToolDefinitions() {
        print("=== Agent Tools: Tool Definitions Demo ===\n")
        
        print("📋 Anthropic Format:")
        let anthropicTools = AgentToolAdapter.anthropicToolDefinitions()
        print("   \(anthropicTools.count) tools available\n")
        if let firstTool = anthropicTools.first {
            print("   Example tool: \(firstTool["name"] ?? "?")")
            print("   Description: \(firstTool["description"] ?? "?")\n")
        }
        
        print("📋 OpenAI Format:")
        let openAITools = AgentToolAdapter.openAIToolDefinitions()
        print("   \(openAITools.count) tools available\n")
        
        print("✨ All tool definitions ready for LLM integration!\n")
    }
    
    // MARK: - Run All Demos
    
    public static func runAllDemos() async {
        print("\n" + String(repeating: "=", count: 60))
        print("🤖 AGENT TOOLS - COMPREHENSIVE DEMO")
        print(String(repeating: "=", count: 60) + "\n")
        
        demoToolDefinitions()
        await demoFileOperations()
        await demoProcessOperations()
        await demoAppControl()
        await demoBatchOperations()
        
        print(String(repeating: "=", count: 60))
        print("✨ ALL DEMOS COMPLETED!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Quick Test Function

/// Quick test you can call from anywhere
@MainActor
public func testAgentTools() async {
    await AgentToolsDemo.runAllDemos()
}
