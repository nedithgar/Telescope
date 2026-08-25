import Darwin
import Foundation
import Testing
@testable import Telescope

@Suite
struct StandardOutputIntegrationTests {
    // Regression test: ScrubberKit previously printed extraction details to stdout.
    // Telescope reserves stdout for MCP JSON-RPC, so such output corrupts the protocol stream.
    @Test(
        "Document extraction produces no standard output",
        .timeLimit(.minutes(1))
    )
    func documentExtractionProducesNoStandardOutput() throws {
        let sentinel = "TELESCOPESENTINEL7F0B7CF9"
        let result = try runStandardOutputProbe(sentinel: sentinel)

        try #require(
            result.terminationStatus == 0,
            "The standard-output probe failed: \(result.standardError)"
        )
        #expect(
            result.standardOutput.isEmpty,
            "Document extraction must not write to the MCP protocol stream"
        )
    }
}

private struct StandardOutputProbeResult {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

private func runStandardOutputProbe(
    sentinel: String
) throws -> StandardOutputProbeResult {
    let fileManager = FileManager.default
    let captureID = UUID().uuidString
    let standardOutputURL = fileManager.temporaryDirectory
        .appendingPathComponent("TelescopeStdoutProbe-\(captureID).stdout")
    let standardErrorURL = fileManager.temporaryDirectory
        .appendingPathComponent("TelescopeStdoutProbe-\(captureID).stderr")
    try Data().write(to: standardOutputURL)
    try Data().write(to: standardErrorURL)
    defer {
        try? fileManager.removeItem(at: standardOutputURL)
        try? fileManager.removeItem(at: standardErrorURL)
    }

    let standardOutputHandle = try FileHandle(forWritingTo: standardOutputURL)
    defer { try? standardOutputHandle.close() }
    let standardErrorHandle = try FileHandle(forWritingTo: standardErrorURL)
    defer { try? standardErrorHandle.close() }

    let process = Process()
    process.executableURL = try standardOutputProbeURL()
    process.arguments = [sentinel]
    process.standardOutput = standardOutputHandle
    process.standardError = standardErrorHandle

    let processExited = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in processExited.signal() }
    try process.run()

    guard processExited.wait(timeout: .now() + .seconds(30)) == .success else {
        process.terminate()
        if processExited.wait(timeout: .now() + .seconds(2)) == .timedOut {
            _ = kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
        }
        throw StandardOutputProbeError.timedOut
    }

    let standardOutputData = try Data(contentsOf: standardOutputURL)
    let standardErrorData = try Data(contentsOf: standardErrorURL)

    return StandardOutputProbeResult(
        terminationStatus: process.terminationStatus,
        standardOutput: String(decoding: standardOutputData, as: UTF8.self),
        standardError: String(decoding: standardErrorData, as: UTF8.self)
    )
}

private enum StandardOutputProbeError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "The standard-output probe did not exit within 30 seconds"
    }
}

private func standardOutputProbeURL() throws -> URL {
    let fileManager = FileManager.default
    let arguments = CommandLine.arguments
    var searchDirectories: [URL] = []

    if let builtProductsDirectory = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
        searchDirectories.append(URL(fileURLWithPath: builtProductsDirectory))
    }

    let testBundlePathIndex = arguments.firstIndex(of: "--test-bundle-path")
    if let testBundleExecutablePath = testBundlePathIndex.flatMap({ index in
        arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
    }) {
        searchDirectories.append(
            URL(fileURLWithPath: testBundleExecutablePath).deletingLastPathComponent()
        )
    }

    searchDirectories.append(contentsOf: Bundle.allBundles.compactMap { bundle in
        bundle.executableURL?.deletingLastPathComponent()
    })
    searchDirectories.append(
        URL(fileURLWithPath: arguments[0]).deletingLastPathComponent()
    )

    for startingDirectory in searchDirectories {
        var directory = startingDirectory
        for _ in 0..<6 {
            let candidate = directory.appendingPathComponent("TelescopeStdoutProbe")
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }
    }

    throw CocoaError(
        .fileNoSuchFile,
        userInfo: [NSFilePathErrorKey: "TelescopeStdoutProbe"]
    )
}
