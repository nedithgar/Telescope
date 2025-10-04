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
        // Setup ScrubberKit (required before first use)
        ScrubberConfiguration.setup()
        
        // Setup logging (optional but helpful)
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .info
            return handler
        }
        let logger = Logger(label: "dev.telescope.server")
        let version = "0.0.2"

        // Parse CLI arguments early
        let args = Array(CommandLine.arguments.dropFirst()) // skip executable name

        // Support basic help/version flags
        if args.contains("-h") || args.contains("--help") {
            let help = """
            Usage: telescope-server [options]

            Options:
                --disable-rerank              Disable URL re-ranking (ScrubberKit heuristic + BM25)
                --rerank-keep-per-host=N      Limit results per host (default: 2, set large number to effectively disable)
                --version                     Print version and exit
                -h, --help                    Show this help and exit

            Examples:
                telescope-server
                telescope-server --disable-rerank
                telescope-server --rerank-keep-per-host=3
            """
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            print(help)
            exit(0)
        }
        if args.contains("--version") {
            print("telescope-server v\(version)")
            exit(0)
        }

        // Create server instance
        let server = Server(
            name: "TelescopeServer",
            version: version,
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: true)
            )
        )

        // Feature flags and tuning
        let disableRerank = args.contains("--disable-rerank")
        var rerankKeepPerHost: Int? = 2 // balanced profile default
        if let keepFlagIndex = args.firstIndex(where: { $0.hasPrefix("--rerank-keep-per-host=") }) {
            let valuePart = args[keepFlagIndex].split(separator: "=", maxSplits: 1).last.map(String.init)
            if let valuePart, let intVal = Int(valuePart), intVal > 0 { rerankKeepPerHost = intVal }
            else { logger.warning("Ignored invalid --rerank-keep-per-host value; using default 2") }
        }
        if disableRerank { logger.info("Rerank disabled via --disable-rerank") }
        logger.info("Rerank keep-per-host: \(rerankKeepPerHost.map(String.init) ?? "disabled")")
        let searchService = TelescopeSearchService(useRerank: !disableRerank, rerankKeepPerHostname: rerankKeepPerHost)

        // ListTools handler exposing a single tool: searchweb
        let rerankStateDesc = disableRerank ? "off" : "on"
        let hostCapDesc = rerankKeepPerHost.map(String.init) ?? "none"
        let toolDescription = "Search the web and return cleaned textual page excerpts (ScrubberKit; rerank: \(rerankStateDesc); host cap: \(hostCapDesc))."
        await server.withMethodHandler(ListTools.self) { _ in
            let tool = Tool(
                name: "searchweb",
                description: toolDescription,
                inputSchema: .object([
                    "type": .string("object"), // compatibility; SDK may not require explicit type
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("The search query keywords")
                        ]),
                        "limit": .object([
                            "type": .string("number"),
                            "description": .string("Maximum number of documents to return (default 10, max 20)")
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
            let rawLimit = params.arguments?["limit"]?.intValue ?? params.arguments?["limit"]?.doubleValue.map { Int($0) }
            let limit = rawLimit ?? 10

            // Perform search using the Telescope service
            let documents = await searchService.search(query: query, limit: limit)
            let output = searchService.formatResults(query: query, documents: documents)
            
            return .init(content: [.text(output)], isError: false)
        }

        let transport = StdioTransport(logger: logger)
        let mcpService = MCPService(server: server, transport: transport, logger: logger)
        let serviceGroup = ServiceGroup(
            services: [mcpService],
            gracefulShutdownSignals: [.sigint, .sigterm],
            cancellationSignals: [],
            logger: logger
        )
        do {
            try await serviceGroup.run()
        } catch {
            logger.error("Service group terminated with error: \(String(describing: error))")
            exit(1)
        }
    }
}