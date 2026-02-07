import Foundation

struct CLIResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum CLIRunnerError: Error, CustomStringConvertible {
    case binaryNotFound(String)
    case timeout

    var description: String {
        switch self {
        case .binaryNotFound(let message): return message
        case .timeout: return "CLI process timed out"
        }
    }
}

enum CLIRunner {

    /// Locate the compiled SwiftOnceCLI binary.
    /// 1. Check SWIFTONCE_CLI_PATH env var
    /// 2. Search DerivedData for most recently modified binary
    static func findCLIBinary() throws -> URL {
        if let explicit = ProcessInfo.processInfo.environment["SWIFTONCE_CLI_PATH"] {
            let url = URL(fileURLWithPath: explicit)
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw CLIRunnerError.binaryNotFound(
                    "SWIFTONCE_CLI_PATH is set to '\(explicit)' but it is not an executable file."
                )
            }
            return url
        }

        let derivedData = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: derivedData, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            throw CLIRunnerError.binaryNotFound(
                "Cannot read DerivedData at \(derivedData.path). Set SWIFTONCE_CLI_PATH explicitly."
            )
        }

        var candidates: [(url: URL, date: Date)] = []
        for dir in contents where dir.lastPathComponent.hasPrefix("SwiftOnce-") {
            let binary = dir
                .appendingPathComponent("Build/Products/Debug/SwiftOnceCLI")
            if fm.isExecutableFile(atPath: binary.path),
               let attrs = try? fm.attributesOfItem(atPath: binary.path),
               let modified = attrs[.modificationDate] as? Date {
                candidates.append((binary, modified))
            }
        }

        guard let newest = candidates.max(by: { $0.date < $1.date }) else {
            throw CLIRunnerError.binaryNotFound(
                "SwiftOnceCLI binary not found in DerivedData. Build it first:\n" +
                "  xcodebuild build -scheme SwiftOnceCLI -destination 'platform=macOS'\n" +
                "Or set SWIFTONCE_CLI_PATH to the binary path."
            )
        }

        return newest.url
    }

    /// Run the CLI with the given arguments, returning stdout, stderr, and exit code.
    ///
    /// - Parameters:
    ///   - arguments: CLI arguments (e.g. ["voices", "--page-size", "3"])
    ///   - environment: Additional env vars to set (merged onto inherited env)
    ///   - excludeKeys: Env var keys to remove from inherited environment
    ///   - timeout: Maximum seconds to wait (default 30)
    static func run(
        arguments: [String] = [],
        environment: [String: String] = [:],
        excludeKeys: Set<String> = [],
        timeout: TimeInterval = 30
    ) async throws -> CLIResult {
        let binaryURL = try findCLIBinary()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = binaryURL
                process.arguments = arguments

                // Build environment: inherit, merge overrides, remove exclusions
                var env = ProcessInfo.processInfo.environment
                for key in excludeKeys { env.removeValue(forKey: key) }
                for (key, value) in environment { env[key] = value }
                process.environment = env

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // Read pipes before waitUntilExit to avoid deadlock
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                // Timeout handling
                let deadline = DispatchTime.now() + timeout
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    process.waitUntilExit()
                    group.leave()
                }

                let waitResult = group.wait(timeout: deadline)
                if waitResult == .timedOut {
                    process.terminate()
                    continuation.resume(throwing: CLIRunnerError.timeout)
                    return
                }

                let result = CLIResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )
                continuation.resume(returning: result)
            }
        }
    }
}
