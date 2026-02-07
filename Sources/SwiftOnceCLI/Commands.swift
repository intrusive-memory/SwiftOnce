import Foundation
import SwiftOnce

func listVoices(apiKey: String, args: [String]) async throws {
    var pageSize: Int? = nil
    if let idx = args.firstIndex(of: "--page-size"), idx + 1 < args.count {
        pageSize = Int(args[idx + 1])
    }

    let client = SwiftOnce(apiKey: apiKey)
    let result = try await client.voices(pageSize: pageSize)

    printOutput("Voices (\(result.voices.count) returned, total: \(result.totalCount ?? result.voices.count)):")
    for voice in result.voices {
        let category = voice.category?.rawValue ?? "unknown"
        printOutput("  \(voice.name) [\(voice.id)] (\(category))")
    }
    if result.hasMore {
        printOutput("  ... more voices available")
    }
}

func searchVoices(apiKey: String, args: [String]) async throws {
    guard let query = args.first else {
        printError("Usage: search <query>")
        exit(1)
    }

    let client = SwiftOnce(apiKey: apiKey)
    let result = try await client.voices(search: query)

    if result.voices.isEmpty {
        printOutput("No voices found matching \"\(query)\".")
    } else {
        printOutput("Found \(result.voices.count) voice(s):")
        for voice in result.voices {
            let category = voice.category?.rawValue ?? "unknown"
            let desc = voice.description ?? ""
            printOutput("  \(voice.name) [\(voice.id)] (\(category))")
            if !desc.isEmpty {
                printOutput("    \(desc)")
            }
        }
    }
}

func getVoice(apiKey: String, args: [String]) async throws {
    guard let voiceId = args.first else {
        printError("Usage: voice <id>")
        exit(1)
    }

    let client = SwiftOnce(apiKey: apiKey)
    let voice = try await client.voice(voiceId)

    printOutput("Voice: \(voice.name)")
    printOutput("  ID:       \(voice.id)")
    if let category = voice.category {
        printOutput("  Category: \(category.rawValue)")
    }
    if let desc = voice.description {
        printOutput("  Desc:     \(desc)")
    }
    if !voice.labels.isEmpty {
        let labelStr = voice.labels.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        printOutput("  Labels:   \(labelStr)")
    }
    if let preview = voice.previewUrl {
        printOutput("  Preview:  \(preview)")
    }
}

func speakText(apiKey: String, args: [String]) async throws {
    var voiceId: String? = nil
    var outputPath: String? = nil
    var textParts: [String] = []
    var i = 0

    while i < args.count {
        switch args[i] {
        case "--voice", "-v":
            i += 1
            guard i < args.count else {
                printError("--voice requires a value")
                exit(1)
            }
            voiceId = args[i]
        case "-o", "--output":
            i += 1
            guard i < args.count else {
                printError("-o requires a file path")
                exit(1)
            }
            outputPath = args[i]
        default:
            textParts.append(args[i])
        }
        i += 1
    }

    let text = textParts.joined(separator: " ")
    guard !text.isEmpty else {
        printError("Usage: speak [--voice <id>] [-o <path>] <text>")
        exit(1)
    }

    let client = SwiftOnce(apiKey: apiKey)
    let audioData: Data

    if let voiceId {
        audioData = try await client.speak(text, voice: voiceId)
    } else {
        audioData = try await client.speak(text)
    }

    let destination = outputPath ?? "output.mp3"
    try audioData.write(to: URL(fileURLWithPath: destination))
    printOutput("Audio saved to \(destination) (\(audioData.count) bytes)")
}

func showDefaultVoice(apiKey: String, args: [String]) async throws {
    var voiceName: String? = nil
    if let idx = args.firstIndex(of: "--name"), idx + 1 < args.count {
        voiceName = args[idx + 1]
    }

    let config = voiceName != nil
        ? SwiftOnceConfiguration(defaultVoiceName: voiceName)
        : SwiftOnceConfiguration()
    let client = SwiftOnce(apiKey: apiKey, configuration: config)
    let voice = try await client.resolveDefaultVoice()

    printOutput("Default voice resolved:")
    printOutput("  Name:     \(voice.name)")
    printOutput("  ID:       \(voice.id)")
    if let category = voice.category {
        printOutput("  Category: \(category.rawValue)")
    }
}
