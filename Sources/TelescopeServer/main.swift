import Foundation
import MCP
import Telescope
import ScrubberKit
import Logging
import ServiceLifecycle

struct MCPService: Service {
    let server: Server
    let transport: Transport
    let logger: Logger

    func run() async throws {
        try await server.start(transport: transport) { clientInfo, _ in
            logger.info("Client connected: \(clientInfo.name) v\(clientInfo.version)")
        }
        // Keep the service alive until cancelled
    // Effectively run indefinitely (~100 years) using seconds
    let secondsInYear: Int64 = 365 * 24 * 60 * 60
    try await Task.sleep(for: .seconds(secondsInYear * 100))
    }

    func shutdown() async {
        logger.info("Shutting down MCP server")
        await server.stop()
    }
}

@main
struct TelescopeServerMain {
    static func main() async {
        // Setup logging (optional but helpful)
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }
        let logger = Logger(label: "dev.telescope.server")

        let server = Server(
            name: "TelescopeServer",
            version: "0.0.1",
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: true)
            )
        )

        // ListTools handler exposing a single tool: searchweb
        await server.withMethodHandler(ListTools.self) { _ in
            let tool = Tool(
                name: "searchweb",
                description: "Search the web for a query and return cleaned textual page excerpts (using ScrubberKit)",
                inputSchema: .object([
                    "type": .string("object"), // compatibility; SDK may not require explicit type
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("The search query keywords")
                        ]),
                        "limit": .object([
                            "type": .string("number"),
                            "description": .string("Maximum number of documents to return (default 5, max 20)")
                        ])
                    ]),
                    "required": .array([.string("query")])
                ])
            )
            return .init(tools: [tool])
        }

        // CallTool handler performing the actual search
        await server.withMethodHandler(CallTool.self) { params in
            guard params.name == "searchweb" else {
                return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
            let query = params.arguments?["query"]?.stringValue ?? ""
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .init(content: [.text("Missing required 'query' argument")], isError: true)
            }
            let limitRaw = params.arguments?["limit"]?.intValue ?? params.arguments?["limit"]?.doubleValue.map { Int($0) }
            var limit = limitRaw ?? 5
            if limit < 1 { limit = 1 }
            if limit > 20 { limit = 20 }

            // ScrubberKit must be executed on main thread per its design (asserts); we coordinate via continuation
            let searchLimit = limit
            let documents: [AnyDocument] = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    let scrubber = Scrubber(query: query)
                    scrubber.run(limitation: searchLimit) { docs in
                        // Map to lightweight serializable structure
                        let mapped = docs.map { doc in
                            let text: String = {
                                // Try common property names
                                let mirror = Mirror(reflecting: doc)
                                let candidates = [
                                    mirror.descendant("plainText"),
                                    mirror.descendant("content"),
                                    mirror.descendant("text"),
                                    mirror.descendant("body")
                                ]
                                for c in candidates {
                                    if let s = c as? String, s.count > 0 { return s }
                                }
                                // Fallback: find first large string property
                                for child in mirror.children {
                                    if let s = child.value as? String, s.count > 0 { return s }
                                }
                                return ""
                            }()
                            return AnyDocument(title: (Mirror(reflecting: doc).descendant("title") as? String) ?? "", url: (Mirror(reflecting: doc).descendant("url") as? URL)?.absoluteString ?? "", plainText: text.prefix(8_000))
                        }
                        continuation.resume(returning: mapped)
                    } onProgress: { _ in }
                }
            }
            // Build text output. Each document separated with markers.
            var output = "Search results for: \(query)\n\n"
            for (idx, doc) in documents.enumerated() {
                output += "# Result \(idx + 1): \(doc.title)\nURL: \(doc.url)\n\n"
                output += doc.plainText + "\n\n"
            }
            return .init(content: [.text(output)], isError: false)
        }

        let transport = StdioTransport(logger: logger)
        let mcpService = MCPService(server: server, transport: transport, logger: logger)
        let group = ServiceGroup(
            services: [mcpService],
            gracefulShutdownSignals: [.sigint, .sigterm],
            cancellationSignals: [],
            logger: logger
        )
        do {
            try await group.run()
        } catch {
            logger.error("Service group terminated with error: \(String(describing: error))")
            exit(1)
        }
    }
}

// Lightweight document representation to avoid exposing ScrubberKit internals directly
struct AnyDocument: Codable {
    let title: String
    let url: String
    let plainText: String
    init(title: String, url: String, plainText: Substring) {
        self.title = title
        self.url = url
        self.plainText = String(plainText)
    }
}
