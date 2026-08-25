import Foundation
import ScrubberKit

@main
struct TelescopeStdoutProbe {
    @MainActor
    static func main() async {
        guard let sentinel = CommandLine.arguments.dropFirst().first else {
            fail("Missing sentinel argument")
        }

        guard let document = await extractDocument(sentinel: sentinel) else {
            fail("Document extraction failed")
        }
        guard document.markdownDocument.contains(sentinel) else {
            fail("The test fixture did not reach Markdown extraction")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(EXIT_FAILURE)
    }

    @MainActor
    private static func extractDocument(sentinel: String) async -> Scrubber.Document? {
        ScrubberConfiguration.setup()
        let html = "<html><head><title>Probe</title></head><body><main>\(sentinel)</main></body></html>"
        let encodedHTML = Data(html.utf8).base64EncodedString()
        guard let fixtureURL = URL(string: "data:text/html;base64,\(encodedHTML)") else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            Scrubber.document(for: fixtureURL) { document in
                continuation.resume(returning: document)
            }
        }
    }
}
