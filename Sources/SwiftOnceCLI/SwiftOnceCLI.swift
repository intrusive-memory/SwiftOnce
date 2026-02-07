import Foundation
import SwiftOnce

@main
struct SwiftOnceCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "help"

        // Commands that don't require an API key
        switch command {
        case "version":
            printOutput("SwiftOnce \(SwiftOnce.version)")
            return
        case "help", "--help", "-h":
            printUsage()
            return
        default:
            break
        }

        guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !apiKey.isEmpty else {
            printError("Error: ELEVENLABS_API_KEY environment variable is not set.")
            exit(1)
        }

        do {
            switch command {
            case "voices":
                try await listVoices(apiKey: apiKey, args: Array(args.dropFirst()))
            case "search":
                try await searchVoices(apiKey: apiKey, args: Array(args.dropFirst()))
            case "voice":
                try await getVoice(apiKey: apiKey, args: Array(args.dropFirst()))
            case "speak":
                try await speakText(apiKey: apiKey, args: Array(args.dropFirst()))
            case "default-voice":
                try await showDefaultVoice(apiKey: apiKey, args: Array(args.dropFirst()))
            default:
                printError("Unknown command: \(command)")
                printUsage()
                exit(1)
            }
        } catch {
            printError("Error: \(formatError(error))")
            exit(1)
        }
    }
}
