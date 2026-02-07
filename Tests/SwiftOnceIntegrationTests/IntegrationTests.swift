import Testing
import Foundation
import SwiftOnce

// MARK: - Helpers

private func apiKeyIsAvailable() -> Bool {
    guard let key = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"],
          !key.isEmpty else {
        return false
    }
    return true
}

private func makeTempDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("swiftonce-integration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func removeTempDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

// MARK: - Tests that do NOT require a real API key

@Test func versionCommand() async throws {
    let result = try await CLIRunner.run(
        arguments: ["version"],
        excludeKeys: ["ELEVENLABS_API_KEY"]
    )
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("SwiftOnce"))
    #expect(result.stdout.contains(SwiftOnce.version))
}

@Test func helpCommand() async throws {
    let result = try await CLIRunner.run(
        arguments: ["help"],
        excludeKeys: ["ELEVENLABS_API_KEY"]
    )
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("Commands:"))
    #expect(result.stdout.contains("voices"))
    #expect(result.stdout.contains("speak"))
}

@Test func missingAPIKey() async throws {
    let result = try await CLIRunner.run(
        arguments: ["voices"],
        excludeKeys: ["ELEVENLABS_API_KEY"]
    )
    #expect(result.exitCode != 0)
    #expect(result.stderr.contains("ELEVENLABS_API_KEY"))
}

@Test func invalidAPIKey() async throws {
    let result = try await CLIRunner.run(
        arguments: ["voices"],
        environment: ["ELEVENLABS_API_KEY": "sk_invalid_fake_key_12345"],
        timeout: 30
    )
    #expect(result.exitCode != 0)
    #expect(result.stderr.contains("Error"))
}

// MARK: - Tests that require a real API key

@Test func voicesCommand() async throws {
    guard apiKeyIsAvailable() else { return }

    let result = try await CLIRunner.run(arguments: ["voices"])
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("Voices ("))

    // Should contain at least one voice entry with [id] pattern
    let bracketPattern = try Regex(#"\[[a-zA-Z0-9]+\]"#)
    let matches = result.stdout.matches(of: bracketPattern)
    #expect(matches.count >= 1)
}

@Test func voicesPageSize() async throws {
    guard apiKeyIsAvailable() else { return }

    let result = try await CLIRunner.run(arguments: ["voices", "--page-size", "3"])
    #expect(result.exitCode == 0)

    // Count voice entry lines (lines containing [id] pattern)
    let bracketPattern = try Regex(#"\[[a-zA-Z0-9]+\]"#)
    let lines = result.stdout.components(separatedBy: "\n")
    let voiceLines = lines.filter { line in
        line.firstMatch(of: bracketPattern) != nil
    }
    #expect(voiceLines.count <= 3)
}

@Test func searchFindsVoices() async throws {
    guard apiKeyIsAvailable() else { return }

    let result = try await CLIRunner.run(arguments: ["search", "Rachel"])
    #expect(result.exitCode == 0)
    #expect(result.stdout.localizedCaseInsensitiveContains("rachel"))
}

@Test func searchNoResults() async throws {
    guard apiKeyIsAvailable() else { return }

    let result = try await CLIRunner.run(arguments: ["search", "xyzzy_nonexistent_99999"])
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("No voices found"))
}

@Test func defaultVoiceCommand() async throws {
    guard apiKeyIsAvailable() else { return }

    let result = try await CLIRunner.run(arguments: ["default-voice"])
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("Default voice resolved:"))
    #expect(result.stdout.contains("Name:"))
    #expect(result.stdout.contains("ID:"))
}

@Test func speakDefaultVoice() async throws {
    guard apiKeyIsAvailable() else { return }

    let tempDir = try makeTempDirectory()
    defer { removeTempDirectory(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test_default.mp3").path
    let result = try await CLIRunner.run(
        arguments: ["speak", "-o", outputPath, "Hello from SwiftOnce integration test."],
        timeout: 60
    )
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("Audio saved"))

    let fileData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
    #expect(fileData.count > 100)
}

@Test func speakExplicitVoice() async throws {
    guard apiKeyIsAvailable() else { return }

    // First, list voices to get a real voice ID
    let listResult = try await CLIRunner.run(arguments: ["voices", "--page-size", "1"])
    #expect(listResult.exitCode == 0)

    // Extract first voice ID from output using [id] pattern
    let idPattern = try Regex(#"\[([a-zA-Z0-9]+)\]"#)
    guard let match = listResult.stdout.firstMatch(of: idPattern),
          match.output.count > 1 else {
        Issue.record("Could not extract voice ID from voices output")
        return
    }
    let voiceId = String(match.output[1].substring!)

    let tempDir = try makeTempDirectory()
    defer { removeTempDirectory(tempDir) }

    let outputPath = tempDir.appendingPathComponent("test_explicit.mp3").path
    let result = try await CLIRunner.run(
        arguments: ["speak", "--voice", voiceId, "-o", outputPath, "Testing explicit voice selection."],
        timeout: 60
    )
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("Audio saved"))

    let fileData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
    #expect(fileData.count > 100)
}
