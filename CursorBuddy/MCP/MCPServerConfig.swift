import Foundation

// MARK: - MCP Server Transport Type

enum MCPTransportType: String, Codable, CaseIterable, Identifiable {
    case stdio = "stdio"
    case http = "http"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stdio: return "Stdio (Local Process)"
        case .http: return "HTTP/SSE (Remote)"
        }
    }

    var description: String {
        switch self {
        case .stdio: return "Spawn a local process and communicate via stdin/stdout"
        case .http: return "Connect to a remote HTTP+SSE MCP server"
        }
    }
}

// MARK: - MCP Server Configuration

struct MCPServerConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var transportType: MCPTransportType

    // Stdio transport
    var command: String
    var arguments: [String]
    var environmentVariables: [String: String]
    var workingDirectory: String?

    // HTTP transport
    var url: String

    // Runtime state (not persisted)
    var toolCount: Int?

    init(
        id: UUID = UUID(),
        name: String = "",
        isEnabled: Bool = true,
        transportType: MCPTransportType = .stdio,
        command: String = "",
        arguments: [String] = [],
        environmentVariables: [String: String] = [:],
        workingDirectory: String? = nil,
        url: String = ""
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.transportType = transportType
        self.command = command
        self.arguments = arguments
        self.environmentVariables = environmentVariables
        self.workingDirectory = workingDirectory
        self.url = url
        self.toolCount = nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, transportType
        case command, arguments, environmentVariables, workingDirectory
        case url
    }

    var displayName: String {
        if !name.isEmpty { return name }
        switch transportType {
        case .stdio:
            let cmd = command.split(separator: "/").last.map(String.init) ?? command
            return cmd.isEmpty ? "New Server" : cmd
        case .http:
            return url.isEmpty ? "New Server" : url
        }
    }

    var isValid: Bool {
        switch transportType {
        case .stdio: return !command.isEmpty
        case .http: return !url.isEmpty && url.hasPrefix("http")
        }
    }
}

// MARK: - Persistence

final class MCPServerConfigStore {
    static let shared = MCPServerConfigStore()

    private let configPath: String
    private(set) var servers: [MCPServerConfig] = []

    private init() {
        let dir = NSString("~/.cursorbuddy").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        configPath = (dir as NSString).appendingPathComponent("mcp-servers.json")
        load()
    }

    func load() {
        guard let data = FileManager.default.contents(atPath: configPath),
              let decoded = try? JSONDecoder().decode([MCPServerConfig].self, from: data) else {
            servers = []
            return
        }
        servers = decoded
        print("[MCP] Loaded \(servers.count) server config(s)")
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(servers)
            try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            print("[MCP] Saved \(servers.count) server config(s)")
        } catch {
            print("[MCP] Failed to save configs: \(error)")
        }
    }

    func add(_ server: MCPServerConfig) {
        servers.append(server)
        save()
    }

    func update(_ server: MCPServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            save()
        }
    }

    func remove(id: UUID) {
        servers.removeAll { $0.id == id }
        save()
    }

    var enabledServers: [MCPServerConfig] {
        servers.filter { $0.isEnabled && $0.isValid }
    }
}
