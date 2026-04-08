import Foundation
import MCP
import os

// MARK: - Connected MCP Server

/// Represents a live connection to an MCP server with its discovered tools.
struct MCPConnectedServer: Identifiable {
    let id: UUID
    let config: MCPServerConfig
    let client: Client
    var tools: [Tool]
    var status: MCPServerStatus

    /// The Process handle for stdio servers (kept alive for the connection lifetime)
    var process: Process?
}

enum MCPServerStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - MCP Client Manager

/// Manages connections to all configured MCP servers and aggregates their tools.
@MainActor
final class MCPClientManager: ObservableObject {
    static let shared = MCPClientManager()

    @Published private(set) var connectedServers: [UUID: MCPConnectedServer] = [:]
    @Published private(set) var isConnecting: Bool = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.cursorbuddy",
        category: "MCPClient"
    )

    private init() {}

    // MARK: - Aggregated Tools

    /// All tools from all connected servers, for passing to Claude.
    var allTools: [Tool] {
        Array(connectedServers.values.flatMap { $0.tools })
    }

    /// Build Claude API tool definitions from all connected MCP tools.
    /// Returns an array of dicts suitable for the Anthropic `tools` parameter.
    var claudeToolDefinitions: [[String: Any]] {
        let definitions = allTools.compactMap { tool in
            var def: [String: Any] = [
                "name": tool.name,
                "input_schema": tool.inputSchema.toJSONObject()
            ]
            if let desc = tool.description {
                def["description"] = desc
            }
            return def
        }
        return definitions
    }

    /// Find which server owns a given tool name.
    func server(forTool toolName: String) -> MCPConnectedServer? {
        connectedServers.values.first { server in
            server.tools.contains { $0.name == toolName }
        }
    }

    // MARK: - Connect All

    /// Connect to all enabled MCP servers from the config store.
    func connectAll() async {
        isConnecting = true
        let configs = MCPServerConfigStore.shared.enabledServers

        for config in configs {
            if connectedServers[config.id] != nil { continue }
            await connect(config: config)
        }

        // Disconnect servers that are no longer in config
        let enabledIDs = Set(configs.map(\.id))
        for id in connectedServers.keys where !enabledIDs.contains(id) {
            await disconnect(id: id)
        }

        isConnecting = false
        logger.info("MCP: \(self.connectedServers.count) server(s) connected, \(self.allTools.count) tool(s) available")
    }

    // MARK: - Connect Single Server

    func connect(config: MCPServerConfig) async {
        let serverID = config.id
        connectedServers[serverID] = MCPConnectedServer(
            id: serverID, config: config,
            client: Client(name: "CursorBuddy", version: "1.0"),
            tools: [], status: .connecting
        )

        do {
            let client = Client(name: "CursorBuddy", version: "1.0")
            let transport: any Transport

            switch config.transportType {
            case .stdio:
                let (stdioTransport, process) = try launchStdioServer(config: config)
                transport = stdioTransport
                connectedServers[serverID]?.process = process

            case .http:
                guard let url = URL(string: config.url) else {
                    throw MCPError.internalError("Invalid URL: \(config.url)")
                }
                transport = HTTPClientTransport(endpoint: url)
            }

            try await client.connect(transport: transport)

            // Discover tools
            let (tools, _) = try await client.listTools()

            connectedServers[serverID] = MCPConnectedServer(
                id: serverID, config: config,
                client: client, tools: tools, status: .connected,
                process: connectedServers[serverID]?.process
            )

            // Update tool count in config store
            var updatedConfig = config
            updatedConfig.toolCount = tools.count
            MCPServerConfigStore.shared.update(updatedConfig)

            logger.info("MCP: Connected to '\(config.displayName)' — \(tools.count) tool(s)")
            for tool in tools {
                logger.info("  → \(tool.name): \(tool.description ?? "")")
            }

        } catch {
            logger.error("MCP: Failed to connect to '\(config.displayName)': \(error.localizedDescription)")
            connectedServers[serverID]?.status = .error(error.localizedDescription)
        }
    }

    // MARK: - Disconnect

    func disconnect(id: UUID) async {
        guard let server = connectedServers[id] else { return }
        await server.client.disconnect()
        server.process?.terminate()
        connectedServers.removeValue(forKey: id)
        logger.info("MCP: Disconnected from '\(server.config.displayName)'")
    }

    func disconnectAll() async {
        for id in connectedServers.keys {
            await disconnect(id: id)
        }
    }

    // MARK: - Call Tool

    /// Call an MCP tool by name. Returns the text content of the result.
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        guard let server = server(forTool: name) else {
            throw MCPError.internalError("No MCP server provides tool '\(name)'")
        }

        // Convert [String: Any] to [String: Value]
        let mcpArgs = arguments.compactMapValues { anyToValue($0) }

        let (content, isError) = try await server.client.callTool(
            name: name,
            arguments: mcpArgs
        )

        // Extract text from content blocks
        let text = content.compactMap { block -> String? in
            switch block {
            case .text(let text, _, _): return text
            default: return nil
            }
        }.joined(separator: "\n")

        if isError == true {
            throw MCPError.internalError("Tool '\(name)' returned error: \(text)")
        }

        logger.info("MCP: Called tool '\(name)' → \(text.prefix(100))...")
        return text
    }

    // MARK: - Stdio Launch

    private func launchStdioServer(config: MCPServerConfig) throws -> (StdioTransport, Process) {
        let process = Process()

        // Resolve command — check if it's a path or needs PATH lookup
        let resolvedCommand = resolveCommand(config.command)
        process.executableURL = URL(fileURLWithPath: resolvedCommand)
        process.arguments = config.arguments

        // Environment: inherit current + add configured vars
        var env = ProcessInfo.processInfo.environment
        for (key, value) in config.environmentVariables {
            env[key] = value
        }
        process.environment = env

        if let workDir = config.workingDirectory, !workDir.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        }

        // Pipes for stdio communication
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        logger.info("MCP: Launched stdio process '\(config.command)' (pid \(process.processIdentifier))")

        // Log stderr in background
        let errorHandle = stderrPipe.fileHandleForReading
        let serverName = config.displayName
        let log = logger
        Task.detached {
            for try await line in errorHandle.bytes.lines {
                log.warning("MCP[\(serverName)] stderr: \(line)")
            }
        }

        // Create StdioTransport from the pipe file descriptors
        let inputFD = stdoutPipe.fileHandleForReading.fileDescriptor
        let outputFD = stdinPipe.fileHandleForWriting.fileDescriptor
        let transport = StdioTransport(
            input: .init(rawValue: inputFD),
            output: .init(rawValue: outputFD)
        )

        return (transport, process)
    }

    /// Resolve a command name to a full path (e.g. "npx" → "/usr/local/bin/npx")
    private func resolveCommand(_ command: String) -> String {
        if command.hasPrefix("/") || command.hasPrefix("~") {
            return NSString(string: command).expandingTildeInPath
        }

        // Search common PATH locations
        let searchPaths = [
            "/usr/local/bin", "/usr/bin", "/opt/homebrew/bin",
            "/usr/local/share/npm/bin",
            NSString("~/.nvm/versions/node").expandingTildeInPath,
            NSString("~/.local/bin").expandingTildeInPath,
        ]

        // Try which first
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [command]
        let whichPipe = Pipe()
        whichProcess.standardOutput = whichPipe
        whichProcess.standardError = FileHandle.nullDevice
        try? whichProcess.run()
        whichProcess.waitUntilExit()
        if whichProcess.terminationStatus == 0,
           let output = String(data: whichPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !output.isEmpty {
            return output
        }

        // Fallback: search common paths
        for dir in searchPaths {
            let path = (dir as NSString).appendingPathComponent(command)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return command
    }

    // MARK: - Value Conversion

    private func anyToValue(_ value: Any) -> Value? {
        switch value {
        case let s as String: return .string(s)
        case let n as Int: return .int(n)
        case let d as Double: return .double(d)
        case let b as Bool: return .bool(b)
        case let arr as [Any]:
            return .array(arr.compactMap { anyToValue($0) })
        case let dict as [String: Any]:
            return .object(dict.compactMapValues { anyToValue($0) })
        default:
            return .string(String(describing: value))
        }
    }
}

// MARK: - Value → JSON Object

extension Value {
    /// Convert MCP Value to a JSON-serializable object for the Claude API.
    func toJSONObject() -> Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .null: return NSNull()
        case .array(let arr): return arr.map { $0.toJSONObject() }
        case .object(let dict):
            var result: [String: Any] = [:]
            for (k, v) in dict { result[k] = v.toJSONObject() }
            return result
        case .data(_, let data): return data.base64EncodedString()
        }
    }
}
