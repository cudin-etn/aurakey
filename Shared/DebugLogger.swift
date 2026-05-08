import Foundation

/// Centralized logger for Aurakey
/// Optimized for high-frequency logging without blocking
/// Uses fire-and-forget file writing for zero-blocking logging
class DebugLogger {

    static let shared = DebugLogger()

    private let logFileURL: URL

    var isLoggingEnabled: Bool = true

    var isVerboseLogging: Bool = false

    private let logQueue = DispatchQueue(label: "com.tdev.aurakey.logger", qos: .utility)

    private let writeLock = NSLock()

    private init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        logFileURL = homeDirectory.appendingPathComponent("Aurakey_Debug.log")
    }

    private func writeToFile(_ text: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            self.writeLock.lock()
            defer { self.writeLock.unlock() }

            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let line = "[\(timestamp)] \(text)\n"

            guard let data = line.data(using: .utf8) else { return }

            do {
                let handle = try FileHandle(forWritingTo: self.logFileURL)
                handle.seekToEndOfFile()
                handle.write(data)
                try handle.close()
            } catch {
            }
        }
    }

    func log(_ message: String, source: String = "", level: LogLevel = .info) {
        guard isLoggingEnabled else { return }

        let prefix = level.emoji
        let fullMessage: String
        if prefix.isEmpty {
            fullMessage = source.isEmpty ? message : "[\(source)] \(message)"
        } else {
            fullMessage = source.isEmpty ? "\(prefix) \(message)" : "\(prefix) [\(source)] \(message)"
        }

        switch level {
        case .error, .warning:
            writeToFile(fullMessage)
        case .info, .success:
            writeToFile(fullMessage)
        case .debug:
            if isVerboseLogging {
                writeToFile(fullMessage)
            }
        }
    }

    func info(_ message: String, source: String = "") {
        log(message, source: source, level: .info)
    }

    func warning(_ message: String, source: String = "") {
        log(message, source: source, level: .warning)
    }

    func error(_ message: String, source: String = "") {
        log(message, source: source, level: .error)
    }

    func success(_ message: String, source: String = "") {
        log(message, source: source, level: .success)
    }

    func debug(_ message: String, source: String = "") {
        guard isVerboseLogging else { return }
        log(message, source: source, level: .debug)
    }
}

// MARK: - Log Level

enum LogLevel {
    case info
    case warning
    case error
    case success
    case debug

    var emoji: String {
        switch self {
        case .info: return ""
        case .warning: return "[WARN]"
        case .error: return "[ERROR]"
        case .success: return "[OK]"
        case .debug: return "[DEBUG]"
        }
    }
}

// MARK: - Convenience Global Functions

@inline(__always)
func logInfo(_ message: String, source: String = "") {
    DebugLogger.shared.info(message, source: source)
}

@inline(__always)
func logWarning(_ message: String, source: String = "") {
    DebugLogger.shared.warning(message, source: source)
}

@inline(__always)
func logError(_ message: String, source: String = "") {
    DebugLogger.shared.error(message, source: source)
}

@inline(__always)
func logSuccess(_ message: String, source: String = "") {
    DebugLogger.shared.success(message, source: source)
}

@inline(__always)
func logDebug(_ message: String, source: String = "") {
    DebugLogger.shared.debug(message, source: source)
}

// MARK: - Aliases for SharedSettings compatibility

@inline(__always)
func sharedLogInfo(_ message: String, source: String = "") {
    logInfo(message, source: source)
}

@inline(__always)
func sharedLogWarning(_ message: String, source: String = "") {
    logWarning(message, source: source)
}

@inline(__always)
func sharedLogError(_ message: String, source: String = "") {
    logError(message, source: source)
}

@inline(__always)
func sharedLogSuccess(_ message: String, source: String = "") {
    logSuccess(message, source: source)
}

@inline(__always)
func sharedLogDebug(_ message: String, source: String = "") {
    logDebug(message, source: source)
}
