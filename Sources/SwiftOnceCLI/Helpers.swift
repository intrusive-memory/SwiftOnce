import Foundation
import SwiftOnce

func printOutput(_ message: String) {
    print(message)
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func printUsage() {
    printOutput("""
    SwiftOnceCLI - ElevenLabs API tool

    Usage: SwiftOnceCLI <command> [options]

    Commands:
      voices [--page-size N]                List available voices
      search <query>                        Search voices by name
      voice <id>                            Get details for a specific voice
      speak [--voice <id>] [-o <path>] <text>
                                            Text-to-speech (uses default voice if --voice omitted)
      default-voice [--name <name>]         Resolve and display the default voice
      version                               Show version
      help                                  Show this help

    Environment:
      ELEVENLABS_API_KEY                    Required. Your ElevenLabs API key.
    """)
}

func formatError(_ error: any Error) -> String {
    guard let elError = error as? ElevenLabsError else {
        return error.localizedDescription
    }
    switch elError {
    case .invalidAPIKey:
        return "Invalid API key. Check your ELEVENLABS_API_KEY."
    case .httpError(let statusCode, let body):
        var msg = "HTTP \(statusCode)"
        if let body { msg += ": \(body)" }
        return msg
    case .rateLimited(let retryAfter):
        var msg = "Rate limited."
        if let seconds = retryAfter { msg += " Retry after \(seconds)s." }
        return msg
    case .quotaExceeded:
        return "API quota exceeded."
    case .voiceNotFound(let detail):
        return "Voice not found: \(detail)"
    case .invalidRequest(let detail):
        return "Invalid request: \(detail)"
    case .decodingError(let underlying):
        return "Decoding error: \(underlying.localizedDescription)"
    case .networkError(let underlying):
        return "Network error: \(underlying.localizedDescription)"
    case .cachingError(let underlying):
        return "Caching error: \(underlying.localizedDescription)"
    case .defaultVoiceNotFound(let name):
        return "Default voice not found: \(name)"
    }
}
