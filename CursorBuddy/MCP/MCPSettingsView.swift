import SwiftUI

// MARK: - MCP Settings View

struct MCPSettingsView: View {
    @StateObject private var clientManager = MCPClientManager.shared
    @State private var servers: [MCPServerConfig] = MCPServerConfigStore.shared.servers
    @State private var selectedServerID: UUID?
    @State private var editingServer: MCPServerConfig?
    @State private var showAddSheet = false
    @State private var newArgument = ""
    @State private var newEnvKey = ""
    @State private var newEnvValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("MCP Servers")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                if clientManager.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await clientManager.connectAll() }
                    refreshServers()
                } label: {
                    Label("Reconnect All", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            Text("Connect to MCP servers to give CursorBuddy access to external tools. Servers provide tools that Claude can call during conversations.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(clientManager.allTools.count) tool(s) available from \(clientManager.connectedServers.count) server(s)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.blue)

                Spacer()
            }

            Divider()

            // Server List
            if servers.isEmpty {
                emptyState
            } else {
                serverList
            }

            // Add button
            HStack {
                Button {
                    let newServer = MCPServerConfig()
                    editingServer = newServer
                    showAddSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .controlSize(.small)

                Spacer()
            }

            // Connected tools list
            if !clientManager.allTools.isEmpty {
                Divider()
                toolsList
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showAddSheet) {
            if let server = editingServer {
                MCPServerEditorView(
                    server: server,
                    isNew: !servers.contains(where: { $0.id == server.id }),
                    onSave: { saved in
                        if servers.contains(where: { $0.id == saved.id }) {
                            MCPServerConfigStore.shared.update(saved)
                        } else {
                            MCPServerConfigStore.shared.add(saved)
                        }
                        refreshServers()
                        Task { await clientManager.connectAll() }
                        showAddSheet = false
                    },
                    onCancel: {
                        showAddSheet = false
                    }
                )
            }
        }
        .onAppear { refreshServers() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.15))
            Text("No MCP servers configured")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
            Text("Add a stdio or HTTP server to extend CursorBuddy with external tools.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var serverList: some View {
        VStack(spacing: 6) {
            ForEach(servers) { server in
                serverRow(server)
            }
        }
    }

    private func serverRow(_ server: MCPServerConfig) -> some View {
        let connected = clientManager.connectedServers[server.id]
        let status = connected?.status ?? .disconnected

        return HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
                .shadow(color: statusColor(status).opacity(0.6), radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: .medium))

                HStack(spacing: 6) {
                    Text(server.transportType.label)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    if let count = connected?.tools.count, count > 0 {
                        Text("• \(count) tool(s)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.blue.opacity(0.8))
                    }

                    if case .error(let msg) = status {
                        Text("• \(msg)")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { server.isEnabled },
                set: { enabled in
                    var updated = server
                    updated.isEnabled = enabled
                    MCPServerConfigStore.shared.update(updated)
                    refreshServers()
                    if enabled {
                        Task { await clientManager.connect(config: updated) }
                    } else {
                        Task { await clientManager.disconnect(id: server.id) }
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()

            Button {
                editingServer = server
                showAddSheet = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)

            Button {
                Task { await clientManager.disconnect(id: server.id) }
                MCPServerConfigStore.shared.remove(id: server.id)
                refreshServers()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(server.isEnabled ? Color.blue.opacity(0.04) : .white.opacity(0.02))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(server.isEnabled ? Color.blue.opacity(0.12) : .white.opacity(0.06), lineWidth: 1)
        }
    }

    private var toolsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Tools")
                .font(.system(size: 13, weight: .medium))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(clientManager.allTools, id: \.name) { tool in
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 10))
                                .foregroundColor(.blue.opacity(0.6))

                            Text(tool.name)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))

                            if let desc = tool.description {
                                Text("— \(desc)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.35))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }

    private func statusColor(_ status: MCPServerStatus) -> Color {
        switch status {
        case .connected: return .green
        case .connecting: return .orange
        case .error: return .red
        case .disconnected: return .white.opacity(0.3)
        }
    }

    private func refreshServers() {
        MCPServerConfigStore.shared.load()
        servers = MCPServerConfigStore.shared.servers
    }
}

// MARK: - Server Editor Sheet

struct MCPServerEditorView: View {
    @State var server: MCPServerConfig
    let isNew: Bool
    let onSave: (MCPServerConfig) -> Void
    let onCancel: () -> Void

    @State private var newArg = ""
    @State private var newEnvKey = ""
    @State private var newEnvValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "Add MCP Server" : "Edit MCP Server")
                .font(.system(size: 16, weight: .semibold))

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                TextField("My Server", text: $server.name)
                    .textFieldStyle(.roundedBorder)
            }

            // Transport type
            VStack(alignment: .leading, spacing: 4) {
                Text("Transport")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Picker("", selection: $server.transportType) {
                    ForEach(MCPTransportType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Transport-specific fields
            if server.transportType == .stdio {
                stdioFields
            } else {
                httpFields
            }

            Divider()

            // Buttons
            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isNew ? "Add" : "Save") {
                    onSave(server)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .disabled(!server.isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .preferredColorScheme(.dark)
    }

    private var stdioFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Command
            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                TextField("npx, node, python, etc.", text: $server.command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            // Arguments
            VStack(alignment: .leading, spacing: 4) {
                Text("Arguments")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                ForEach(server.arguments.indices, id: \.self) { index in
                    HStack {
                        Text(server.arguments[index])
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Button {
                            server.arguments.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("argument", text: $newArg)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit { addArgument() }

                    Button("Add") { addArgument() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(newArg.isEmpty)
                }
            }

            // Environment variables
            VStack(alignment: .leading, spacing: 4) {
                Text("Environment Variables")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                ForEach(Array(server.environmentVariables.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text("\(key)=\(server.environmentVariables[key] ?? "")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            server.environmentVariables.removeValue(forKey: key)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 4) {
                    TextField("KEY", text: $newEnvKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: 120)

                    Text("=")
                        .foregroundColor(.white.opacity(0.3))

                    TextField("value", text: $newEnvValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))

                    Button("Add") { addEnvVar() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(newEnvKey.isEmpty)
                }
            }

            // Working directory
            VStack(alignment: .leading, spacing: 4) {
                Text("Working Directory (optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                TextField("/path/to/dir", text: Binding(
                    get: { server.workingDirectory ?? "" },
                    set: { server.workingDirectory = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    private var httpFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Server URL")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            TextField("https://example.com/mcp", text: $server.url)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            Text("HTTP+SSE endpoint. The server must support the MCP Streamable HTTP transport.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
        }
    }

    private func addArgument() {
        let arg = newArg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !arg.isEmpty else { return }
        server.arguments.append(arg)
        newArg = ""
    }

    private func addEnvVar() {
        let key = newEnvKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = newEnvValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        server.environmentVariables[key] = value
        newEnvKey = ""
        newEnvValue = ""
    }
}
