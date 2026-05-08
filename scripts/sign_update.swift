#!/usr/bin/env swift

import Foundation
import CryptoKit
import ArgumentParser

struct SignUpdate: ParsableCommand {
    @Argument(help: "Path to the file to sign")
    var filePath: String

    @Option(name: .long, help: "Ed25519 private key file (Base64-encoded)")
    var privateKeyFile: String?

    @Option(name: .long, help: "Ed25519 private key (Base64 string)")
    var privateKey: String?

    mutating func run() throws {
        guard let keyString = privateKey ?? (privateKeyFile.flatMap { try? String(contentsOfFile: $0, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) }) else {
            print("Error: Provide private key via --private-key or --private-key-file")
            throw ExitCode(1)
        }

        guard let keyData = Data(base64Encoded: keyString) else {
            print("Error: Invalid private key (not valid Base64)")
            throw ExitCode(1)
        }

        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)

        guard let fileData = FileManager.default.contents(atPath: filePath) else {
            print("Error: Cannot read file at \(filePath)")
            throw ExitCode(1)
        }

        let signature = try privateKey.signature(for: fileData)
        let signatureBase64 = signature.base64EncodedString()

        let fileSize = fileData.count
        let fileURL = URL(fileURLWithPath: filePath)
        let filename = fileURL.lastPathComponent

        print("""
        <enclosure
            url="https://github.com/cudin-etn/aurakey/releases/download/v{VERSION}/\(filename)"
            sparkle:edSignature="\(signatureBase64)"
            length="\(fileSize)"
            type="application/octet-stream"
        />
        """)
    }
}

SignUpdate.main()
