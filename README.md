## 🔭 What is Telescope?

Telescope is an MCP server that enables AI agents to search the web and retrieve readable page content from search results without any search engine API keys, bridging the gap between AI agents and web content by providing access to web information straight from your local machine.

### Key Features

- **Web Search Integration** - Search the web using natural language queries
- **Multiple Content Formats** - Returns Markdown by default with plain-text fallback, with explicit plain-text and rendered-HTML options
- **Result Re-Ranking (Default On)** - Intelligent heuristic + BM25 based URL re-ranking powered by ScrubberKit to prioritize higher quality, deduplicated sources (can be disabled with `--disable-rerank`)
- **No API Keys Required** - Works out of the box; does NOT rely on Google/Bing/third‑party search API keys
- **Configurable Results** - Control the number of search results (10-20 documents)
- **MCP Compatible** - Works seamlessly with Claude Desktop, Cursor, and other MCP-compatible AI agents
- **Privacy-Focused** - Runs locally on your machine

## 🚀 Quick Start

You can either grab the prebuilt universal macOS archive from GitHub Releases (recommended) or build from source.

### 1. Download the Latest Release Archive

1. Go to: https://github.com/nedithgar/Telescope/releases/latest
2. Download the asset: `telescope-server-vX.Y.Z-macOS-universal.zip` (example: `telescope-server-v0.1.0-macOS-universal.zip`)
3. Download the matching checksum: `telescope-server-vX.Y.Z-macOS-universal.zip.sha256`
4. Verify integrity (substitute the actual version):

```bash
shasum -a 256 -c telescope-server-v0.1.0-macOS-universal.zip.sha256
```

Expected output ends with `OK`.

### 2. Extract & Install (macOS)

Extract the archive, then install the executable and its resource bundle together in a dedicated directory. Invoke the executable by its full path so SwiftPM can locate the adjacent resource bundle.

```bash
unzip telescope-server-v0.1.0-macOS-universal.zip
sudo mkdir -p /usr/local/libexec/telescope
sudo ditto telescope-server-v0.1.0-macOS-universal /usr/local/libexec/telescope
```

Do not move `telescope-server` without the adjacent `ScrubberKit_ScrubberKit.bundle`.

Verify it runs:

```bash
/usr/local/libexec/telescope/telescope-server --help || echo "Install check failed"
```

### 3. Add to an MCP-Compatible Client Configuration

Example JSON snippet using the default macOS installation path:

```json
{
  "mcpServers": {
    "telescope": {
      "command": "/usr/local/libexec/telescope/telescope-server",
      "args": []
    }
  }
}
```

If you used a custom location, keep the extracted directory intact and update `command` to the `telescope-server` inside it.

### 4. Optional Runtime Flags

Disable reranking (use raw ordering):

```bash
/usr/local/libexec/telescope/telescope-server --disable-rerank
```

Increase per-host result allowance:

```bash
/usr/local/libexec/telescope/telescope-server --rerank-keep-per-host=3
```

---

If you prefer to build instead of downloading, see the next section.

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

Just build and run—Telescope will return Markdown excerpts from real web pages, falling back to plain text when needed. (Normal network access from your machine is, of course, required.)

### Default Behavior

- **Result Limit**: 10-20 documents per search (configurable per request, clamped to this range)
- **Content Truncation**: Each document is limited to 20,000 characters to optimize token usage
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

Search the web for a query and return extracted page excerpts. Markdown is returned by default, with automatic plain-text fallback when Markdown conversion produces no content.

The selected `format` applies to each page-content excerpt, not to the enclosing tool response. For every format, `searchweb` returns one readable text report containing the query and each result's title and URL. HTML excerpts are included as rendered DOM serialization, but remain subject to the 20,000-character limit and are not guaranteed to be balanced, standalone documents or to form one valid HTML document when multiple results are returned.

**Parameters:**
- `query` (required): The search query keywords
- `limit` (optional): Maximum number of documents to return (default: 10, max: 20)
- `format` (optional): Representation used for each page-content excerpt: `markdown` (default), `text`, or `html`. Rendered HTML excerpts are returned only when explicitly requested.

## 📚 Architecture

Telescope uses a modern service-based architecture:

- **Telescope** (Library) - Core service (`TelescopeSearchService`) for web searching and content extraction using ScrubberKit
  - `SearchDocument` - Lightweight, Sendable document structure containing the selected content representation
  - `search(query:limit:format:)` - Async search method that runs ScrubberKit on main thread
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
