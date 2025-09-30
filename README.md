# Telescope MCP Server 🔭

A Model Context Protocol (MCP) server that provides web search capabilities using [ScrubberKit](https://github.com/Lakr233/ScrubberKit) for cleaning and extracting text content from web pages.

## 🎯 What is Telescope?

Telescope is an MCP server that enables AI assistants like Claude Desktop and Cursor to search the web and retrieve cleaned, readable text content from search results. It bridges the gap between AI assistants and web content, providing structured access to web information.

### Key Features

- **Web Search Integration** - Search the web using natural language queries
- **Cleaned Text Extraction** - Automatically removes ads, navigation, and other noise using ScrubberKit
- **Configurable Results** - Control the number of search results (10-20 documents)
- **MCP Compatible** - Works seamlessly with Claude Desktop, Cursor, and other MCP-compatible AI assistants
- **Privacy-Focused** - Runs locally on your machine

## 🚀 Quick Start

### For Claude Desktop

1. Build the Telescope server:
   ```bash
   swift build -c release
   ```

2. Open Claude Desktop Settings (from the **menubar**, not the in-app settings)

3. Navigate to Developer → Edit Config

4. Add the Telescope MCP server configuration:
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

5. Save and restart Claude Desktop

### For Cursor IDE

Add to your Cursor settings:

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

- macOS 15.0+ (Sequoia or later) - required by macOS 16 platform requirement
- Swift 6.2+ (included with Xcode 16.4+)
- Xcode 16.4+ with Command Line Tools

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

### Default Behavior

- **Result Limit**: 10-20 documents per search (configurable per request, clamped to this range)
- **Text Truncation**: Each document is limited to 8,000 characters to optimize token usage
- **Thread Safety**: All operations are performed on the main thread as required by ScrubberKit
- **ScrubberKit Setup**: Automatically configured on server startup via `ScrubberConfiguration.setup()`

## 🛠️ MCP Tools Available

### `searchweb`

Search the web for a query and return cleaned textual page excerpts.

**Parameters:**
- `query` (required): The search query keywords
- `limit` (optional): Maximum number of documents to return (default: 10, max: 20)

**Example Usage in Claude:**

```
Search the web for "Swift MCP server tutorial"
Find information about "best practices for web scraping"
```

**Returns:**
```
Search results for: [your query]

# Result 1: [Page Title]
URL: [page URL]

[Cleaned text content...]

# Result 2: [Page Title]
URL: [page URL]

[Cleaned text content...]
```

## 📚 Architecture

Telescope uses a modern service-based architecture:

- **Telescope** (Library) - Core service (`TelescopeSearchService`) for web searching and text extraction using ScrubberKit
  - `SearchDocument` - Lightweight, Sendable document structure for serialization
  - `search(query:limit:)` - Async search method that runs ScrubberKit on main thread
  - `formatResults(query:documents:)` - Formats search results as readable text
- **TelescopeServer** (Executable) - MCP server that exposes the Telescope service to AI assistants
  - Version: 0.0.1
  - Handles `ListTools` and `CallTool` MCP methods
  - Uses `StdioTransport` for communication
- **ServiceLifecycle** - Manages the server lifecycle with graceful shutdown (SIGINT/SIGTERM)

### How It Works

1. **Server Initialization** - `ScrubberConfiguration.setup()` is called on startup
2. **Client Connection** - AI assistant connects to the MCP server via stdio
3. **Tool Discovery** - Server advertises the `searchweb` tool via `ListTools` handler
4. **Query Execution** - Assistant sends search queries through `CallTool` handler
5. **Content Retrieval** - `TelescopeSearchService` uses ScrubberKit on main thread to fetch and clean web content
6. **Results Delivery** - Cleaned text (up to 8,000 chars per document) is formatted and returned to the assistant

## 🧪 Testing

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose
```

**Note:** The test suite currently contains a minimal example test. Additional integration tests are recommended for production use.

### Testing the MCP Server

Use the MCP Inspector to test the server:

```bash
npx @modelcontextprotocol/inspector /path/to/Telescope/.build/release/telescope-server
```

## 📋 Requirements

### System Requirements

- macOS 16.0+ (as specified in Package.swift with `.macOS(.v26)`)
- Swift 6.2+
- Xcode 16.4+ (for building)

### Dependencies

- [ScrubberKit](https://github.com/Lakr233/ScrubberKit) (0.1.0+) - Web content extraction and cleaning
- [Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk) (0.10.0+) - Model Context Protocol implementation
- [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) (2.3.0+) - Service management

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| `Command not found` | Ensure the binary path in your MCP config is correct |
| `Build failed` | Check that you have Xcode 16.4+ and Swift 6.2+ installed |
| `Server not responding` | Check the MCP client logs for connection errors |
| `Search results empty` | Verify you have an active internet connection |

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

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0) - see the [LICENSE](./LICENSE) file for details.

## 🙏 Acknowledgments

- [ScrubberKit](https://github.com/Lakr233/ScrubberKit) for powerful web content extraction
- [Model Context Protocol](https://modelcontextprotocol.io) team for the MCP specification and Swift SDK

## 👤 Author

Created by [@nedithgar](https://github.com/nedithgar)

---

Made with 🔭 for the MCP ecosystem
