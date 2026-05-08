#!/usr/bin/env swift

import Foundation
import CryptoKit

/// Script to generate/update appcast.xml for Sparkle auto-updates.
/// Called by GitHub Actions after a new release is published.
///
/// Usage: swift update_appcast.swift <version> <build> <zip-path> <private-key>

guard CommandLine.arguments.count == 5 else {
    print("Usage: update_appcast.swift <version> <build> <zip-path> <private-key>")
    exit(1)
}

let version = CommandLine.arguments[1]
let build = CommandLine.arguments[2]
let zipPath = CommandLine.arguments[3]
let privateKeyBase64 = CommandLine.arguments[4]

// Read the zip file
guard let zipData = FileManager.default.contents(atPath: zipPath) else {
    print("Error: Cannot read file at \(zipPath)")
    exit(1)
}

// Sign with Ed25519
guard let keyData = Data(base64Encoded: privateKeyBase64) else {
    print("Error: Invalid private key")
    exit(1)
}

let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
let signature = try privateKey.signature(for: zipData)
let signatureBase64 = signature.base64EncodedString()
let fileSize = zipData.count
let filename = URL(fileURLWithPath: zipPath).lastPathComponent

let appcast = """
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Aurakey Appcast</title>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        <item>
            <title>Version \(version)</title>
            <sparkle:version>\(build)</sparkle:version>
            <sparkle:shortVersionString>\(version)</sparkle:shortVersionString>
            <enclosure
                url="https://github.com/cudin-etn/aurakey/releases/download/v\(version)/\(filename)"
                sparkle:edSignature="\(signatureBase64)"
                length="\(fileSize)"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
"""

let appcastPath = "appcast.xml"
try appcast.write(toFile: appcastPath, atomically: true, encoding: .utf8)
print("✅ appcast.xml generated at \(appcastPath)")
print("   Signature: \(signatureBase64)")
print("   Length: \(fileSize)")
