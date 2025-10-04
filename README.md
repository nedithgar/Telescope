## 🔭 What is Telescope?

> ⚠️ Project Status: **Under Active Construction**
>
> This codebase (and especially this README) is still evolving. Interfaces, flags, and output formats may change without notice while the core architecture stabilizes. Expect rapid iterations, rough edges, and incomplete docs for a little while longer. If you try it and something breaks or feels confusing, please open an issue – that feedback is extremely helpful right now.

Telescope is an MCP server that enables AI agents to search the web and retrieve cleaned, readable text content from search results without any search engine API keys, bridging the gap between AI agents and web content by providing structured access to web information straight from your local machine.

### Key Features

- **Web Search Integration** - Search the web using natural language queries
- **Cleaned Text Extraction** - Automatically removes ads, navigation, and other noise using ScrubberKit
- **Result Re-Ranking (Default On)** - Intelligent heuristic + BM25 based URL re-ranking powered by ScrubberKit to prioritize higher quality, deduplicated sources (can be disabled with `--disable-rerank`)
- **No API Keys Required** - Works out of the box; does NOT rely on Google/Bing/third‑party search API keys
- **Configurable Results** - Control the number of search results (10-20 documents)
- **MCP Compatible** - Works seamlessly with Claude Desktop, Cursor, and other MCP-compatible AI agents
- **Privacy-Focused** - Runs locally on your machine

## 🚀 Quick Start

```json
{
  "mcpServers": {
    "telescope": {
      "command": "/path/to/Telescope/.build/release/telescope-server",
      "args": []
    }
  }
}
```

## 🏗️ Building from Source

### Prerequisites

- macOS 26.0+ 
- Swift 6.2+ 
- Xcode 26.0+ with Command Line Tools

### Build Commands

```bash
# Clone the repository
git clone https://github.com/yourusername/Telescope.git
cd Telescope

# Build the server
swift build -c release

# The binary will be available at:
# .build/release/telescope-server
```

### Development Build

For development and testing:

```bash
# Build in debug mode
swift build -c debug

# Run tests
swift test
```

## 🔧 Configuration

The Telescope server requires no additional configuration. It uses ScrubberKit's built-in web search capabilities to fetch and clean web content.

### No API Keys Needed

Telescope performs discovery and retrieval directly via ScrubberKit's integrated search + extraction pipeline. You do not need to:

- Create a Google Custom Search Engine
- Supply Bing, SerpAPI, or other paid API credentials
- Manage rate limits or billing for third-party search APIs

Just build and run—Telescope will return cleaned textual excerpts from real web pages. (Normal network access from your machine is, of course, required.)

### Default Behavior

- **Result Limit**: 10-20 documents per search (configurable per request, clamped to this range)
- **Text Truncation**: Each document is limited to 20,000 characters to optimize token usage
- **Thread Safety**: All operations are performed on the main thread
- **Re-Ranking**: Enabled by default. Pass `--disable-rerank` as a command line argument to the server binary to fall back to raw engine ordering.

### Disabling Re-Ranking

If you prefer the original search engine result ordering without heuristic merging and BM25 scoring, launch the server with:

```bash
./.build/release/telescope-server --disable-rerank
```

When disabled, the server logs: `Rerank disabled via --disable-rerank` on startup.

### Adjusting Host Diversity Cap

By default the balanced rerank profile limits results to 2 per hostname to improve diversity. You can change this with:

```bash
./.build/release/telescope-server --rerank-keep-per-host=3
```

Use a value > 0. Set a very large number to effectively disable the cap.

## 🛠️ MCP Tools Available

### `searchweb`

Search the web for a query and return cleaned textual page excerpts.

**Parameters:**
- `query` (required): The search query keywords
- `limit` (optional): Maximum number of documents to return (default: 10, max: 20)

## 📚 Architecture

Telescope uses a modern service-based architecture:

- **Telescope** (Library) - Core service (`TelescopeSearchService`) for web searching and text extraction using ScrubberKit
  - `SearchDocument` - Lightweight, Sendable document structure for serialization
  - `search(query:limit:)` - Async search method that runs ScrubberKit on main thread
  - `formatResults(query:documents:)` - Formats search results as readable text
- **TelescopeServer** (Executable) - MCP server that exposes the Telescope service to AI agents
  - Handles `ListTools` and `CallTool` MCP methods
  - Uses `StdioTransport` for communication
- **ServiceLifecycle** - Manages the server lifecycle with graceful shutdown (SIGINT/SIGTERM)

## 🧪 Testing

### Testing the MCP Server

Use the MCP Inspector to test the server:

```bash
npx @modelcontextprotocol/inspector /path/to/Telescope/.build/release/telescope-server
```

## 🐛 Troubleshooting

### Debug Logging

The server uses Swift's `Logging` framework and logs to stderr by default at `.info` level. To view logs:

```bash
# When running directly
.build/release/telescope-server 2>&1 | tee telescope.log

# Claude Desktop logs can be found at:
~/Library/Logs/Claude/mcp*.log
```

The logger is initialized with label `"dev.telescope.server"` and logs client connections, shutdowns, and errors.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository (or create a new branch if you have push access)
2. Create a descriptive branch: `git checkout -b feature/<short-name>` or `bugfix/<issue-id>`
3. Make your changes (add/update tests and docs where it helps)
4. Run the test suite locally: `swift test`
5. Commit with a clear message: `git commit -m "feat: concise summary"`
6. Push your branch: `git push origin <branch-name>`
7. Open a Pull Request describing the motivation, changes, and any notes for reviewers

## 📝 License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0) - see the [LICENSE](./LICENSE) file for details.

## 🙏 Acknowledgments

- [ScrubberKit](https://github.com/Lakr233/ScrubberKit) for powerful web content extraction
- [Model Context Protocol](https://modelcontextprotocol.io) team for the MCP specification and Swift SDK

## 👤 Author

Created by [@nedithgar](https://github.com/nedithgar)