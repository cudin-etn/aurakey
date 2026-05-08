#!/bin/bash

# Build Release version of Aurakey with Developer ID code signing
# Output will be copied to ./Release/Aurakey.app and ./Release/Aurakey.dmg

set -e  # Exit on error

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "📄 Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
ENABLE_CODESIGN=${ENABLE_CODESIGN:-true}  # Set to false to disable code signing
ENABLE_NOTARIZE=${ENABLE_NOTARIZE:-false}  # Set to true to enable notarization
ENABLE_DMG=${ENABLE_DMG:-true}  # Set to false to skip DMG creation
# Smart defaults: If notarizing, assume it's a full release
if [ "$ENABLE_NOTARIZE" = true ]; then
    # Auto-enable Sparkle signing for notarized releases
    ENABLE_SPARKLE_SIGN=${ENABLE_SPARKLE_SIGN:-true}
    # Auto-enable GitHub release for notarized builds (unless explicitly disabled)
    ENABLE_GITHUB_RELEASE=${ENABLE_GITHUB_RELEASE:-true}
else
    # For development builds, keep conservative defaults
    ENABLE_SPARKLE_SIGN=${ENABLE_SPARKLE_SIGN:-true}
    ENABLE_GITHUB_RELEASE=${ENABLE_GITHUB_RELEASE:-false}
fi

BUNDLE_ID="com.tdev.Aurakey"
APP_NAME="Aurakey"
DMG_NAME="Aurakey.dmg"
DMG_VOLUME_NAME="Aurakey"
REPO_URL="https://github.com/cudin/aurakey"
SPARKLE_BIN="/tmp/Sparkle-2.9.0/bin"

# Read version from Version.xcconfig (centralized version management)
XCCONFIG_FILE="$(pwd)/Version.xcconfig"
if [ -f "$XCCONFIG_FILE" ]; then
    CURRENT_VERSION=$(grep "^MARKETING_VERSION" "$XCCONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    BUILD_NUMBER=$(grep "^CURRENT_PROJECT_VERSION" "$XCCONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
else
    echo "❌ Error: Version.xcconfig not found"
    exit 1
fi


echo "🚀 Building Aurakey (Release configuration)..."

# Show build mode
if [ "$ENABLE_NOTARIZE" = true ]; then
    echo "📦 Full Release Mode (Notarization enabled)"
    echo "   ✅ Code signing"
    echo "   ✅ Notarization"
    echo "   ✅ Sparkle signing"
    [ "$ENABLE_GITHUB_RELEASE" = true ] && echo "   ✅ GitHub Release (auto-create)"
else
    echo "🔨 Development Build Mode"
    [ "$ENABLE_CODESIGN" = true ] && echo "   ✅ Code signing" || echo "   ⚠️  Code signing disabled"
    [ "$ENABLE_SPARKLE_SIGN" = true ] && echo "   ✅ Sparkle signing" || echo "   ⚠️  Sparkle signing disabled"
    [ "$ENABLE_GITHUB_RELEASE" = true ] && echo "   ✅ GitHub Release (auto-create)" || echo "   ⏭️  Manual release"
fi
echo ""

# Create Release directory
mkdir -p Release

# Detect Developer ID if code signing is enabled
if [ "$ENABLE_CODESIGN" = true ]; then
    echo "🔍 Detecting Developer ID certificate..."
    
    # Find Developer ID Application certificate
    DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')
    
    if [ -z "$DEVELOPER_ID" ]; then
        echo "⚠️  No Developer ID Application certificate found in keychain"
        echo "   Available certificates:"
        security find-identity -v -p codesigning
        echo ""
        echo "   Building without code signing..."
        ENABLE_CODESIGN=false
    else
        echo "✅ Found: $DEVELOPER_ID"
        
        # Extract Team ID from certificate
        TEAM_ID=$(echo "$DEVELOPER_ID" | sed -E 's/.*\(([A-Z0-9]+)\).*/\1/')
        echo "✅ Team ID: $TEAM_ID"
    fi
fi

# Clean previous build
echo "🧹 Cleaning previous build..."
xcodebuild -project Aurakey.xcodeproj -scheme Aurakey -configuration Release -derivedDataPath ./build clean

# Build with or without code signing
echo "🔨 Building Universal Binary (Intel + Apple Silicon)..."

if [ "$ENABLE_CODESIGN" = true ]; then
    echo "🔐 Code signing enabled with: $DEVELOPER_ID"
    xcodebuild -project Aurakey.xcodeproj \
      -scheme Aurakey \
      -configuration Release \
      -derivedDataPath ./build \
      -arch x86_64 -arch arm64 \
      ONLY_ACTIVE_ARCH=NO \
      PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
      CODE_SIGN_STYLE=Automatic \
      DEVELOPMENT_TEAM="$TEAM_ID" \
      CODE_SIGNING_REQUIRED=YES \
      CODE_SIGNING_ALLOWED=YES \
      OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
      build
else
    echo "⚠️  Code signing disabled"
    xcodebuild -project Aurakey.xcodeproj \
      -scheme Aurakey \
      -configuration Release \
      -derivedDataPath ./build \
      -arch x86_64 -arch arm64 \
      ONLY_ACTIVE_ARCH=NO \
      PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
      CODE_SIGN_STYLE=Manual \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      build
fi

# Copy to Release directory
echo "📦 Copying to ./Release/Aurakey.app..."
rm -rf Release/Aurakey.app
cp -R "./build/Build/Products/Release/Aurakey.app" Release/

# Sign Sparkle framework's nested components (IMPORTANT: must be done before signing main app)
if [ "$ENABLE_CODESIGN" = true ]; then
    echo "🔐 Signing Sparkle framework components..."
    
    SPARKLE_FW="Release/Aurakey.app/Contents/Frameworks/Sparkle.framework/Versions/B"
    
    # Sign XPC Services first (deepest level)
    if [ -d "$SPARKLE_FW/XPCServices/Installer.xpc" ]; then
        echo "   Signing Installer.xpc..."
        codesign --force --sign "$DEVELOPER_ID" \
            --timestamp \
            --options=runtime \
            "$SPARKLE_FW/XPCServices/Installer.xpc"
        echo "   ✅ Installer.xpc signed"
    fi
    
    if [ -d "$SPARKLE_FW/XPCServices/Downloader.xpc" ]; then
        echo "   Signing Downloader.xpc..."
        codesign --force --sign "$DEVELOPER_ID" \
            --timestamp \
            --options=runtime \
            "$SPARKLE_FW/XPCServices/Downloader.xpc"
        echo "   ✅ Downloader.xpc signed"
    fi
    
    # Sign Updater.app
    if [ -d "$SPARKLE_FW/Updater.app" ]; then
        echo "   Signing Updater.app..."
        codesign --force --sign "$DEVELOPER_ID" \
            --timestamp \
            --options=runtime \
            "$SPARKLE_FW/Updater.app"
        echo "   ✅ Updater.app signed"
    fi
    
    # Sign Autoupdate binary
    if [ -f "$SPARKLE_FW/Autoupdate" ]; then
        echo "   Signing Autoupdate binary..."
        codesign --force --sign "$DEVELOPER_ID" \
            --timestamp \
            --options=runtime \
            "$SPARKLE_FW/Autoupdate"
        echo "   ✅ Autoupdate signed"
    fi
    
    # Finally, sign the entire Sparkle.framework
    if [ -d "Release/Aurakey.app/Contents/Frameworks/Sparkle.framework" ]; then
        echo "   Signing Sparkle.framework..."
        codesign --force --sign "$DEVELOPER_ID" \
            --timestamp \
            --options=runtime \
            "Release/Aurakey.app/Contents/Frameworks/Sparkle.framework"
        echo "   ✅ Sparkle.framework signed"
    fi
    
    echo "✅ Sparkle framework components signed"
fi

# Re-sign Aurakey.app after modifying nested frameworks
if [ "$ENABLE_CODESIGN" = true ]; then
    echo "🔐 Re-signing Aurakey.app after framework modifications..."
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp \
        --options=runtime \
        --entitlements "Aurakey/AurakeyRelease.entitlements" \
        Release/Aurakey.app
    echo "✅ Aurakey.app re-signed"
else
    # Ad-hoc sign with correct identifier (required for Accessibility permissions)
    # IMPORTANT: Include entitlements to preserve App Group for data sharing
    echo "🔐 Ad-hoc signing with correct bundle identifier..."
    codesign --force --sign - --identifier "$BUNDLE_ID" --entitlements "Aurakey/AurakeyRelease.entitlements" Release/Aurakey.app
    echo "✅ Ad-hoc signed with identifier: $BUNDLE_ID"
fi

# Verify code signature
echo "🔍 Verifying code signature..."
codesign -vvv --strict Release/Aurakey.app
echo "✅ Code signature verified"

# Display signature info
echo ""
echo "📝 Signature details:"
codesign -dvvv Release/Aurakey.app 2>&1 | grep -E "(Authority|Identifier|TeamIdentifier|Timestamp)"



# ============================================
# Cleanup build folder
# ============================================
# IMPORTANT: Remove built apps from build folder to prevent LaunchServices
# from finding duplicate versions
echo ""
echo "🧹 Cleaning up build folder..."
rm -rf "./build/Build/Products/Release/Aurakey.app"
echo "✅ Build folder cleaned"


# ============================================
# Create DMG with Applications folder symlink
# ============================================
if [ "$ENABLE_DMG" = true ]; then
    echo ""
    echo "💿 Creating DMG installer..."
    
    # Create temporary directory for DMG contents
    DMG_TEMP_DIR=$(mktemp -d)
    DMG_SOURCE_DIR="$DMG_TEMP_DIR/$DMG_VOLUME_NAME"
    mkdir -p "$DMG_SOURCE_DIR"
    
    # Copy app to temp directory
    cp -R "Release/Aurakey.app" "$DMG_SOURCE_DIR/"
    
    # Create symbolic link to Applications folder
    ln -s /Applications "$DMG_SOURCE_DIR/Applications"
    
    # Remove old DMG if exists
    rm -f "Release/$DMG_NAME"
    
    # Create DMG
    echo "📀 Creating DMG file..."
    hdiutil create \
        -volname "$DMG_VOLUME_NAME" \
        -srcfolder "$DMG_SOURCE_DIR" \
        -ov \
        -format UDZO \
        "Release/$DMG_NAME"
    
    # Sign DMG if code signing is enabled
    if [ "$ENABLE_CODESIGN" = true ]; then
        echo "🔐 Signing DMG..."
        codesign --sign "$DEVELOPER_ID" --timestamp "Release/$DMG_NAME"
        echo "✅ DMG signed"
    fi
    
    # Cleanup temp directory
    rm -rf "$DMG_TEMP_DIR"
    
    echo "✅ DMG created: Release/$DMG_NAME"
fi


# ============================================
# Notarization
# ============================================
if [ "$ENABLE_NOTARIZE" = true ] && [ "$ENABLE_CODESIGN" = true ]; then
    echo ""
    echo "📤 Starting notarization process..."
    
    # Check for required environment variables
    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
        echo "❌ Notarization requires the following environment variables:"
        echo "   APPLE_ID          - Your Apple ID email"
        echo "   APPLE_APP_PASSWORD - App-specific password"
        echo "   APPLE_TEAM_ID     - Your Apple Developer Team ID"
        echo ""
        echo "   Set these in .env file or export them before running this script."
        echo "   See .env.example for reference."
        exit 1
    fi
    
    # Determine what to notarize (prefer DMG if available)
    if [ "$ENABLE_DMG" = true ] && [ -f "Release/$DMG_NAME" ]; then
        NOTARIZE_TARGET="Release/$DMG_NAME"
        echo "📦 Notarizing DMG: $NOTARIZE_TARGET"
    else
        # Create a zip for notarization if DMG is not available
        echo "📦 Creating zip for notarization..."
        NOTARIZE_TARGET="Release/Aurakey.zip"
        ditto -c -k --keepParent "Release/Aurakey.app" "$NOTARIZE_TARGET"
    fi
    
    # Submit for notarization and capture output
    # NOTE: notarytool may return non-zero exit code on failure,
    # so we temporarily disable set -e to capture output and handle errors ourselves
    echo "⏳ Submitting to Apple for notarization (this may take several minutes)..."
    set +e
    NOTARIZE_OUTPUT=$(xcrun notarytool submit "$NOTARIZE_TARGET" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait 2>&1)
    NOTARIZE_EXIT=$?
    set -e
    
    echo "$NOTARIZE_OUTPUT"
    
    if [ $NOTARIZE_EXIT -ne 0 ] && ! echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
        echo ""
        echo "⚠️  notarytool exited with code $NOTARIZE_EXIT"
        
        # Check for 403 agreement error — no point continuing
        if echo "$NOTARIZE_OUTPUT" | grep -q "HTTP status code: 403"; then
            echo ""
            echo "❌ Apple Developer agreement expired or missing!"
            echo ""
            echo "💡 Fix: Go to https://developer.apple.com/account"
            echo "   and accept the updated agreement, then re-run this script."
            exit 1
        fi
    fi
    
    # Extract submission ID
    SUBMISSION_ID=$(echo "$NOTARIZE_OUTPUT" | grep -E "^\s*id:" | head -1 | awk '{print $2}')
    
    # Check if notarization was successful
    if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
        echo "✅ Notarization accepted!"
        
        # Staple the notarization ticket
        echo "📎 Stapling notarization ticket..."
        if [ "$ENABLE_DMG" = true ] && [ -f "Release/$DMG_NAME" ]; then
            xcrun stapler staple "Release/$DMG_NAME"
            echo "✅ DMG notarized and stapled"
        fi
        
        # Also staple the app
        xcrun stapler staple "Release/Aurakey.app"
        echo "✅ App notarized and stapled"
        
        # Clean up zip if we created one
        if [ -f "Release/Aurakey.zip" ]; then
            rm -f "Release/Aurakey.zip"
        fi
        
        # Verify notarization
        echo ""
        echo "🔍 Verifying notarization..."
        spctl -a -vvv -t install "Release/Aurakey.app"
        if [ "$ENABLE_DMG" = true ] && [ -f "Release/$DMG_NAME" ]; then
            spctl -a -vvv -t install "Release/$DMG_NAME"
        fi
        echo "✅ Notarization verified"
    else
        echo ""
        echo "❌ Notarization failed!"
        
        # Fetch detailed log from Apple
        if [ -n "$SUBMISSION_ID" ]; then
            echo ""
            echo "📋 Fetching detailed error log from Apple..."
            echo "   Submission ID: $SUBMISSION_ID"
            echo ""
            xcrun notarytool log "$SUBMISSION_ID" \
                --apple-id "$APPLE_ID" \
                --team-id "$APPLE_TEAM_ID" \
                --password "$APPLE_APP_PASSWORD"
        fi
        
        echo ""
        echo "💡 Common issues:"
        echo "   - Missing hardened runtime (--options=runtime)"
        echo "   - Unsigned nested code or frameworks"
        echo "   - Missing timestamp in signature"
        echo "   - Invalid entitlements"
    fi
fi

# ============================================
# Sparkle Signing (for auto-update)
# ============================================
if [ "$ENABLE_SPARKLE_SIGN" = true ] && [ "$ENABLE_DMG" = true ] && [ -f "Release/$DMG_NAME" ]; then
    echo ""
    echo "🔐 Sparkle Signing for Auto-Update..."
    
    # Check if Sparkle tools exist
    if [ ! -d "$SPARKLE_BIN" ]; then
        echo "📥 Downloading Sparkle tools (v2.9.0)..."
        curl -L https://github.com/sparkle-project/Sparkle/releases/download/2.9.0/Sparkle-2.9.0.tar.xz -o /tmp/Sparkle-2.9.0.tar.xz
        rm -rf /tmp/Sparkle-2.9.0
        mkdir -p /tmp/Sparkle-2.9.0
        tar -xf /tmp/Sparkle-2.9.0.tar.xz -C /tmp/Sparkle-2.9.0
        echo "✅ Sparkle tools downloaded"
    fi
    
    # Check for private key
    if [ -z "$SPARKLE_PRIVATE_KEY" ]; then
        echo "⚠️  SPARKLE_PRIVATE_KEY not found in .env"
        echo "   Attempting to retrieve from Keychain..."
        
        SPARKLE_PRIVATE_KEY=$(security find-generic-password -s "https://sparkle-project.org" -a "ed25519" -w 2>/dev/null || echo "")
        
        if [ -z "$SPARKLE_PRIVATE_KEY" ]; then
            echo "❌ Error: Sparkle private key not found"
            echo ""
            echo "   To generate keys, run:"
            echo "   $SPARKLE_BIN/generate_keys"
            echo ""
            echo "   Then add SPARKLE_PRIVATE_KEY to .env file"
            echo "   Or skip Sparkle signing with: ENABLE_SPARKLE_SIGN=false"
            exit 1
        else
            echo "✅ Retrieved private key from Keychain"
        fi
    fi
    
    # Sign DMG with EdDSA signature
    # NOTE: sign_update may return non-zero exit code even on success,
    # so we temporarily disable set -e to capture output and handle errors ourselves
    echo "🔏 Signing DMG with EdDSA key..."
    SPARKLE_KEY_FILE=$(mktemp)
    echo "$SPARKLE_PRIVATE_KEY" > "$SPARKLE_KEY_FILE"
    set +e
    SPARKLE_OUTPUT=$("$SPARKLE_BIN/sign_update" "Release/$DMG_NAME" --ed-key-file "$SPARKLE_KEY_FILE" 2>&1)
    SPARKLE_EXIT=$?
    set -e
    rm -f "$SPARKLE_KEY_FILE"
    
    if [ $SPARKLE_EXIT -ne 0 ] && [ -z "$SPARKLE_OUTPUT" ]; then
        echo "❌ Error: sign_update failed with exit code $SPARKLE_EXIT"
        echo "   Output: $SPARKLE_OUTPUT"
        exit 1
    fi
    
    # Extract signature from output
    # The output might be in different formats:
    # 1. Just the signature: "ud+UXzlYN4y7cIgbyOYZB3Nq1zjCgV0g0p+Xg7LGpcri9+HO+FEHhBPKPNWzPzDjXevVv5vZ0Sfv4372TOdDBA=="
    # 2. XML attribute format: sparkle:edSignature="ud+UXzlYN4y7cIgbyOYZB3Nq1zjCgV0g0p+Xg7LGpcri9+HO+FEHhBPKPNWzPzDjXevVv5vZ0Sfv4372TOdDBA==" length="8298463"
    
    # Try to extract from XML attribute format first
    if echo "$SPARKLE_OUTPUT" | grep -q 'sparkle:edSignature='; then
        SPARKLE_SIGNATURE=$(echo "$SPARKLE_OUTPUT" | grep 'sparkle:edSignature=' | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/' | tail -1)
    else
        # Fallback: assume it's just the signature (old format)
        SPARKLE_SIGNATURE=$(echo "$SPARKLE_OUTPUT" | grep -v "^$" | tail -1)
    fi
    
    if [ -z "$SPARKLE_SIGNATURE" ]; then
        echo "❌ Error: Failed to generate Sparkle signature"
        echo "   Output from sign_update:"
        echo "$SPARKLE_OUTPUT"
        exit 1
    fi
    
    echo "✅ DMG signed with Sparkle EdDSA signature"
    echo "   Signature: ${SPARKLE_SIGNATURE:0:50}..."
    
    # Save signature to file for GitHub release upload
    echo "$SPARKLE_SIGNATURE" > "Release/signature.txt"
    echo "✅ Signature saved to: Release/signature.txt"
    echo "   ⚠️  IMPORTANT: Upload this file to GitHub Release along with Aurakey.dmg"
    
    # Export signature for reference
    export SPARKLE_SIGNATURE
fi


# ============================================
# GitHub Release (Automatic)
# ============================================
if [ "$ENABLE_GITHUB_RELEASE" = true ]; then
    echo ""
    echo "🚀 Creating GitHub Release..."

    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo "❌ Error: GitHub CLI (gh) not found"
        echo "   Install with: brew install gh"
        echo "   Or skip with: ENABLE_GITHUB_RELEASE=false"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        echo "❌ Error: Not authenticated with GitHub"
        echo "   Run: gh auth login"
        echo "   Or skip with: ENABLE_GITHUB_RELEASE=false"
        exit 1
    fi

    # Version already read from Version.xcconfig at the top of the script
    RELEASE_TAG="v$CURRENT_VERSION-$BUILD_NUMBER"

    echo "📋 Release details:"
    echo "   Version: $CURRENT_VERSION"
    echo "   Build: $BUILD_NUMBER"
    echo "   Tag: $RELEASE_TAG"

    # Check if release already exists
    if gh release view "$RELEASE_TAG" &> /dev/null; then
        echo "⚠️  Release $RELEASE_TAG already exists"
        echo "   Options:"
        echo "   1. Delete existing release: gh release delete $RELEASE_TAG"
        echo "   2. Skip auto-release: ENABLE_GITHUB_RELEASE=false"
        echo "   3. Update version in Version.xcconfig"
        exit 1
    fi

    # Check if DMG exists
    if [ ! -f "Release/$DMG_NAME" ]; then
        echo "❌ Error: DMG not found at Release/$DMG_NAME"
        echo "   Enable DMG creation with: ENABLE_DMG=true"
        exit 1
    fi

    # Prepare release notes
    RELEASE_NOTES_FILE="Release/release_notes.md"

    # Check if user provided custom release notes
    if [ -f ".release_notes.md" ]; then
        echo "📝 Using custom release notes from .release_notes.md"
        cp ".release_notes.md" "$RELEASE_NOTES_FILE"
    else
        # Generate release notes from latest commit message
        echo "📝 Generating release notes from latest commit..."

        # Get latest commit message (subject + body)
        COMMIT_SUBJECT=$(git log -1 --pretty=format:"%s")
        COMMIT_BODY=$(git log -1 --pretty=format:"%b")

        # Create release notes header
        echo "## What's New" > "$RELEASE_NOTES_FILE"
        echo "" >> "$RELEASE_NOTES_FILE"

        # Add commit subject as main change
        echo "$COMMIT_SUBJECT" >> "$RELEASE_NOTES_FILE"

        # Add commit body if available (detailed description)
        if [ -n "$COMMIT_BODY" ]; then
            echo "" >> "$RELEASE_NOTES_FILE"
            echo "$COMMIT_BODY" >> "$RELEASE_NOTES_FILE"
        fi
    fi

    # Display release notes
    echo ""
    echo "📄 Release Notes:"
    cat "$RELEASE_NOTES_FILE"
    echo ""

    # Create version.json with version info for appcast generation
    echo "📝 Creating version.json..."
    cat > "Release/version.json" << EOF
{
    "version": "$CURRENT_VERSION",
    "build": "$BUILD_NUMBER",
    "tag": "$RELEASE_TAG"
}
EOF
    echo "✅ version.json created"

    # Create release with assets
    echo "📤 Creating GitHub release..."

    UPLOAD_FILES="Release/$DMG_NAME Release/version.json"

    # Add signature file if available
    if [ -f "Release/signature.txt" ]; then
        UPLOAD_FILES="$UPLOAD_FILES Release/signature.txt"
        echo "   Uploading: $DMG_NAME + version.json + signature.txt"
    else
        echo "   Uploading: $DMG_NAME + version.json"
    fi

    # Create release
    gh release create "$RELEASE_TAG" $UPLOAD_FILES \
        --title "Aurakey v$CURRENT_VERSION (Build $BUILD_NUMBER)" \
        --notes-file "$RELEASE_NOTES_FILE" \
        --repo "$REPO_URL"

    if [ $? -eq 0 ]; then
        echo "✅ GitHub Release created successfully!"
        echo "   URL: $REPO_URL/releases/tag/$RELEASE_TAG"
        echo ""
        echo "🔄 GitHub Actions will now:"
        echo "   1. Generate appcast.xml from releases"
        echo "   2. Deploy to GitHub Pages"
        echo "   3. Enable auto-update for users"
        echo ""
        echo "   Monitor at: $REPO_URL/actions"
    else
        echo "❌ Failed to create GitHub release"
        exit 1
    fi

    # Clean up
    rm -f "$RELEASE_NOTES_FILE"
    rm -f "Release/version.json"
fi


# Clear macOS launch services cache
echo ""
echo "🧹 Clearing macOS cache..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user

echo ""
echo "✅ Build successful!"

echo ""
echo "✅ Done! Release build is ready at:"
echo "   $(pwd)/Release/Aurakey.app"
if [ "$ENABLE_DMG" = true ]; then
    echo "   $(pwd)/Release/$DMG_NAME"
fi

echo ""
echo "📊 App size:"
du -sh Release/Aurakey.app
if [ "$ENABLE_DMG" = true ] && [ -f "Release/$DMG_NAME" ]; then
    echo ""
    echo "📀 DMG size:"
    du -sh "Release/$DMG_NAME"
fi

echo ""
echo "🏗️  Architecture:"
lipo -info Release/Aurakey.app/Contents/MacOS/Aurakey
echo ""

if [ "$ENABLE_CODESIGN" = true ]; then
    echo "🔐 Code signing: ENABLED"
    echo "   Certificate: $DEVELOPER_ID"
else
    echo "⚠️  Code signing: DISABLED"
fi

if [ "$ENABLE_NOTARIZE" = true ] && [ "$ENABLE_CODESIGN" = true ]; then
    echo "📤 Notarization: COMPLETED"
fi

if [ "$ENABLE_SPARKLE_SIGN" = true ] && [ -n "$SPARKLE_SIGNATURE" ]; then
    echo "🔐 Sparkle Signing: ENABLED"
    echo "   EdDSA signature generated"
fi

if [ "$ENABLE_GITHUB_RELEASE" = true ]; then
    echo "🚀 GitHub Release: CREATED"
    echo "   Version: $CURRENT_VERSION"
    echo "   Build: $BUILD_NUMBER"
    echo "   Tag: v$CURRENT_VERSION-$BUILD_NUMBER"
    echo "   URL: $REPO_URL/releases/tag/v$CURRENT_VERSION-$BUILD_NUMBER"
fi

echo ""
echo "💡 Usage:"
echo "   Default (with code signing + DMG):    ./build_release.sh"
echo "   Without code signing:                 ENABLE_CODESIGN=false ./build_release.sh"
echo "   Without DMG:                          ENABLE_DMG=false ./build_release.sh"
echo "   With notarization (full release):     ENABLE_NOTARIZE=true ./build_release.sh"
echo "   Without Sparkle signing:              ENABLE_SPARKLE_SIGN=false ./build_release.sh"
echo "   With GitHub release:                  ENABLE_GITHUB_RELEASE=true ./build_release.sh"
echo ""
echo "📝 For notarization, create .env file with:"
echo "   APPLE_ID=your-apple-id@example.com"
echo "   APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
echo "   APPLE_TEAM_ID=XXXXXXXXXX"
echo ""
echo "🔐 For Sparkle auto-update, add to .env:"
echo "   SPARKLE_PRIVATE_KEY=your-private-key-here"
echo "   (Or it will be retrieved from Keychain automatically)"
if [ "$ENABLE_GITHUB_RELEASE" != true ]; then
    echo ""
    echo "📋 Next steps for manual release:"
    echo "   1. Create GitHub Release (include version.json + signature.txt for auto-update):"
    echo "      # Create version.json first:"
    echo "      echo '{\"version\": \"$CURRENT_VERSION\", \"build\": \"$BUILD_NUMBER\"}' > Release/version.json"
    echo ""
    echo "      gh release create v$CURRENT_VERSION-$BUILD_NUMBER Release/Aurakey.dmg Release/version.json Release/signature.txt \\"
    echo "         --title \"Aurakey v$CURRENT_VERSION (Build $BUILD_NUMBER)\" \\"
    echo "         --notes \"Your release notes here\""
    echo ""
    echo "   2. Or enable automatic release:"
    echo "      ENABLE_GITHUB_RELEASE=true ./build_release.sh"
    echo ""
    echo "   3. GitHub Actions will automatically:"
    echo "      - Generate appcast.xml with EdDSA signature"
    echo "      - Deploy to GitHub Pages for Sparkle auto-updates"
    echo "      - Users will receive update notification"
    echo ""
    echo "   ⚠️  IMPORTANT: signature.txt MUST be uploaded for updates to work!"
    echo ""
    echo "   📖 See .github/QUICK_SETUP.md for GitHub Pages setup"
else
    echo ""
    echo "✅ Release automation complete!"
    echo "   Monitor GitHub Actions for appcast generation"
    echo "   📖 See .github/QUICK_SETUP.md for GitHub Pages setup"
fi


