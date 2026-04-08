import Foundation
import AppKit
import os

// MARK: - Built-in Tool Definitions

/// Native tools that CursorBuddy can execute directly — no MCP server needed.
@MainActor
final class BuiltInTools {
    static let shared = BuiltInTools()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.cursorbuddy",
        category: "BuiltInTools"
    )

    private init() {}

    // MARK: - Tool Definitions for Claude API

    var claudeToolDefinitions: [[String: Any]] {
        [
            [
                "name": "execute_command",
                "description": "Run a shell command on the user's Mac and return its output. Use for file operations, opening apps, running scripts, installing packages, git commands, etc.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "command": [
                            "type": "string",
                            "description": "The shell command to execute (run via /bin/zsh)"
                        ]
                    ],
                    "required": ["command"]
                ] as [String: Any]
            ],
            [
                "name": "read_file",
                "description": "Read the contents of a file on the user's Mac. Returns the text content.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Absolute path to the file to read"
                        ]
                    ],
                    "required": ["path"]
                ] as [String: Any]
            ],
            [
                "name": "write_file",
                "description": "Write content to a file on the user's Mac. Creates the file if it doesn't exist, overwrites if it does.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Absolute path to the file to write"
                        ],
                        "content": [
                            "type": "string",
                            "description": "Content to write to the file"
                        ]
                    ],
                    "required": ["path", "content"]
                ] as [String: Any]
            ],
            [
                "name": "list_directory",
                "description": "List the contents of a directory on the user's Mac. Returns file names, types, and sizes.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "path": [
                            "type": "string",
                            "description": "Absolute path to the directory to list"
                        ]
                    ],
                    "required": ["path"]
                ] as [String: Any]
            ],
            [
                "name": "open_url",
                "description": "Open a URL in the user's default browser.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "url": [
                            "type": "string",
                            "description": "The URL to open"
                        ]
                    ],
                    "required": ["url"]
                ] as [String: Any]
            ],
            [
                "name": "open_application",
                "description": "Open an application on the user's Mac by name.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "The application name (e.g. 'Safari', 'Terminal', 'Finder')"
                        ]
                    ],
                    "required": ["name"]
                ] as [String: Any]
            ],
            [
                "name": "search_files",
                "description": "Search for files by name pattern in a directory. Uses glob-style matching.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "directory": [
                            "type": "string",
                            "description": "Directory to search in"
                        ],
                        "pattern": [
                            "type": "string",
                            "description": "Search pattern (e.g. '*.swift', 'README*')"
                        ]
                    ],
                    "required": ["directory", "pattern"]
                ] as [String: Any]
            ],
            [
                "name": "get_clipboard",
                "description": "Get the current text content of the user's clipboard.",
                "input_schema": [
                    "type": "object",
                    "properties": [:] as [String: Any]
                ] as [String: Any]
            ],
            [
                "name": "set_clipboard",
                "description": "Set the user's clipboard to the given text.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "text": [
                            "type": "string",
                            "description": "Text to copy to the clipboard"
                        ]
                    ],
                    "required": ["text"]
                ] as [String: Any]
            ],
        ]
    }

    // MARK: - Tool Execution

    /// Execute a built-in tool. Returns the text result.
    func execute(name: String, arguments: [String: Any]) async throws -> String {
        logger.info("Executing built-in tool: \(name)")

        switch name {
        case "execute_command":
            return try await executeCommand(arguments)
        case "read_file":
            return try readFile(arguments)
        case "write_file":
            return try writeFile(arguments)
        case "list_directory":
            return try listDirectory(arguments)
        case "open_url":
            return try openURL(arguments)
        case "open_application":
            return try openApplication(arguments)
        case "search_files":
            return try await searchFiles(arguments)
        case "get_clipboard":
            return getClipboard()
        case "set_clipboard":
            return setClipboard(arguments)
        default:
            throw ToolError.unknownTool(name)
        }
    }

    /// Check if a tool name is a built-in tool.
    func isBuiltIn(_ name: String) -> Bool {
        let names: Set<String> = [
            "execute_command", "read_file", "write_file", "list_directory",
            "open_url", "open_application", "search_files",
            "get_clipboard", "set_clipboard"
        ]
        return names.contains(name)
    }

    // MARK: - Implementations

    private func executeCommand(_ args: [String: Any]) async throws -> String {
        guard let command = args["command"] as? String else {
            throw ToolError.missingArgument("command")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        // Inherit a reasonable environment
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:\(env["PATH"] ?? "")"
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        let exitCode = process.terminationStatus
        var result = outStr
        if !errStr.isEmpty {
            result += (result.isEmpty ? "" : "\n") + "stderr: " + errStr
        }
        if exitCode != 0 {
            result += "\n[exit code: \(exitCode)]"
        }

        logger.info("execute_command: '\(command.prefix(60))' → exit \(exitCode)")
        return result.isEmpty ? "(no output)" : String(result.prefix(10000))
    }

    private func readFile(_ args: [String: Any]) throws -> String {
        guard let path = args["path"] as? String else {
            throw ToolError.missingArgument("path")
        }
        let expanded = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            throw ToolError.fileNotFound(expanded)
        }
        let content = try String(contentsOfFile: expanded, encoding: .utf8)
        return String(content.prefix(50000))
    }

    private func writeFile(_ args: [String: Any]) throws -> String {
        guard let path = args["path"] as? String,
              let content = args["content"] as? String else {
            throw ToolError.missingArgument("path and content")
        }
        let expanded = NSString(string: path).expandingTildeInPath
        let dir = (expanded as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try content.write(toFile: expanded, atomically: true, encoding: .utf8)
        return "Written \(content.count) characters to \(path)"
    }

    private func listDirectory(_ args: [String: Any]) throws -> String {
        guard let path = args["path"] as? String else {
            throw ToolError.missingArgument("path")
        }
        let expanded = NSString(string: path).expandingTildeInPath
        let contents = try FileManager.default.contentsOfDirectory(atPath: expanded)

        var lines: [String] = []
        for name in contents.sorted() {
            let fullPath = (expanded as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)
            let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let size = attrs?[.size] as? Int64 ?? 0

            if isDir.boolValue {
                lines.append("📁 \(name)/")
            } else {
                let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                lines.append("📄 \(name) (\(sizeStr))")
            }
        }
        return lines.isEmpty ? "(empty directory)" : lines.joined(separator: "\n")
    }

    private func openURL(_ args: [String: Any]) throws -> String {
        guard let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
            throw ToolError.missingArgument("url")
        }
        NSWorkspace.shared.open(url)
        return "Opened \(urlString)"
    }

    private func openApplication(_ args: [String: Any]) throws -> String {
        guard let name = args["name"] as? String else {
            throw ToolError.missingArgument("name")
        }
        let config = NSWorkspace.OpenConfiguration()
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            return "Opened \(name)"
        }
        // Try by name
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", name]
        try proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0 ? "Opened \(name)" : "Could not find app '\(name)'"
    }

    private func searchFiles(_ args: [String: Any]) async throws -> String {
        guard let directory = args["directory"] as? String,
              let pattern = args["pattern"] as? String else {
            throw ToolError.missingArgument("directory and pattern")
        }
        let expanded = NSString(string: directory).expandingTildeInPath
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        proc.arguments = [expanded, "-name", pattern, "-maxdepth", "5"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.isEmpty ? "No files found matching '\(pattern)' in \(directory)" : String(output.prefix(10000))
    }

    private func getClipboard() -> String {
        NSPasteboard.general.string(forType: .string) ?? "(clipboard is empty or contains non-text data)"
    }

    private func setClipboard(_ args: [String: Any]) -> String {
        guard let text = args["text"] as? String else {
            return "Error: missing 'text' argument"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return "Copied \(text.count) characters to clipboard"
    }
}

// MARK: - Tool Errors

enum ToolError: LocalizedError {
    case unknownTool(String)
    case missingArgument(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name): return "Unknown tool: \(name)"
        case .missingArgument(let arg): return "Missing required argument: \(arg)"
        case .fileNotFound(let path): return "File not found: \(path)"
        }
    }
}
