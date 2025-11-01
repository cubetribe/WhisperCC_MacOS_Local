#!/bin/bash

# Configure Xcode Project for Optimized Release Builds
# Sets up build configurations for distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

PROJECT_NAME="WhisperLocalMacOs"
XCODEPROJ_PATH="${PROJECT_NAME}.xcodeproj"

if [ ! -d "$XCODEPROJ_PATH" ]; then
    echo "Error: Xcode project not found at $XCODEPROJ_PATH"
    echo "Please run this script from the macos/ directory"
    exit 1
fi

echo -e "${BLUE}⚙️  Xcode Release Configuration Script${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

print_info "Configuring $PROJECT_NAME for optimized release builds"

# Function to update build setting
update_build_setting() {
    local setting_name="$1"
    local setting_value="$2"
    local configuration="$3"
    
    print_info "Setting $setting_name = $setting_value for $configuration"
    
    # Use PlistBuddy to update the project.pbxproj file
    # This is a simplified approach - in practice, you might want to use xcodeproj gem or similar
    
    # For now, we'll create a script that shows what settings should be configured
    echo "    $setting_name = $setting_value" >> "/tmp/build_settings_$configuration.txt"
}

# Create temporary files to store build settings
rm -f /tmp/build_settings_*.txt

print_info "Generating Release build configuration..."

# Release Configuration Settings
update_build_setting "SWIFT_OPTIMIZATION_LEVEL" "-O" "Release"
update_build_setting "GCC_OPTIMIZATION_LEVEL" "s" "Release"
update_build_setting "SWIFT_COMPILATION_MODE" "wholemodule" "Release"
update_build_setting "STRIP_INSTALLED_PRODUCT" "YES" "Release"
update_build_setting "SEPARATE_STRIP" "YES" "Release"
update_build_setting "COPY_PHASE_STRIP" "NO" "Release"
update_build_setting "DEBUG_INFORMATION_FORMAT" "dwarf-with-dsym" "Release"
update_build_setting "ENABLE_HARDENED_RUNTIME" "YES" "Release"
update_build_setting "OTHER_CODE_SIGN_FLAGS" "--timestamp" "Release"
update_build_setting "CODE_SIGN_STYLE" "Automatic" "Release"
update_build_setting "CODE_SIGN_IDENTITY" "Apple Development" "Release"
update_build_setting "MACOSX_DEPLOYMENT_TARGET" "12.0" "Release"
update_build_setting "ARCHS" "arm64 x86_64" "Release"
update_build_setting "ONLY_ACTIVE_ARCH" "NO" "Release"
update_build_setting "VALID_ARCHS" "arm64 x86_64" "Release"
update_build_setting "SUPPORTED_PLATFORMS" "macosx" "Release"
update_build_setting "SDKROOT" "macosx" "Release"
update_build_setting "COMBINE_HIDPI_IMAGES" "YES" "Release"
update_build_setting "INFOPLIST_KEY_LSMinimumSystemVersion" "12.0" "Release"

# Optimization settings
update_build_setting "DEAD_CODE_STRIPPING" "YES" "Release"
update_build_setting "PRESERVE_DEAD_CODE_INITS_AND_TERMS" "NO" "Release"
update_build_setting "GCC_GENERATE_DEBUGGING_SYMBOLS" "YES" "Release"
update_build_setting "SWIFT_SERIALIZE_DEBUGGING_OPTIONS" "NO" "Release"

# Security settings
update_build_setting "ENABLE_STRICT_OBJC_MSGSEND" "YES" "Release"
update_build_setting "GCC_NO_COMMON_BLOCKS" "YES" "Release"
update_build_setting "CLANG_ANALYZER_NONNULL" "YES" "Release"
update_build_setting "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION" "YES_AGGRESSIVE" "Release"
update_build_setting "CLANG_CXX_LANGUAGE_STANDARD" "gnu++17" "Release"
update_build_setting "CLANG_ENABLE_MODULES" "YES" "Release"
update_build_setting "CLANG_ENABLE_OBJC_ARC" "YES" "Release"
update_build_setting "CLANG_ENABLE_OBJC_WEAK" "YES" "Release"
update_build_setting "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING" "YES" "Release"
update_build_setting "CLANG_WARN_BOOL_CONVERSION" "YES" "Release"
update_build_setting "CLANG_WARN_COMMA" "YES" "Release"
update_build_setting "CLANG_WARN_CONSTANT_CONVERSION" "YES" "Release"
update_build_setting "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS" "YES" "Release"
update_build_setting "CLANG_WARN_DIRECT_OBJC_ISA_USAGE" "YES_ERROR" "Release"
update_build_setting "CLANG_WARN_DOCUMENTATION_COMMENTS" "YES" "Release"
update_build_setting "CLANG_WARN_EMPTY_BODY" "YES" "Release"
update_build_setting "CLANG_WARN_ENUM_CONVERSION" "YES" "Release"
update_build_setting "CLANG_WARN_INFINITE_RECURSION" "YES" "Release"
update_build_setting "CLANG_WARN_INT_CONVERSION" "YES" "Release"
update_build_setting "CLANG_WARN_NON_LITERAL_NULL_CONVERSION" "YES" "Release"
update_build_setting "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF" "YES" "Release"
update_build_setting "CLANG_WARN_OBJC_LITERAL_CONVERSION" "YES" "Release"
update_build_setting "CLANG_WARN_OBJC_ROOT_CLASS" "YES_ERROR" "Release"
update_build_setting "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER" "YES" "Release"
update_build_setting "CLANG_WARN_RANGE_LOOP_ANALYSIS" "YES" "Release"
update_build_setting "CLANG_WARN_STRICT_PROTOTYPES" "YES" "Release"
update_build_setting "CLANG_WARN_SUSPICIOUS_MOVE" "YES" "Release"
update_build_setting "CLANG_WARN_UNGUARDED_AVAILABILITY" "YES_AGGRESSIVE" "Release"
update_build_setting "CLANG_WARN_UNREACHABLE_CODE" "YES" "Release"
update_build_setting "GCC_WARN_64_TO_32_BIT_CONVERSION" "YES" "Release"
update_build_setting "GCC_WARN_ABOUT_RETURN_TYPE" "YES_ERROR" "Release"
update_build_setting "GCC_WARN_UNDECLARED_SELECTOR" "YES" "Release"
update_build_setting "GCC_WARN_UNINITIALIZED_AUTOS" "YES_AGGRESSIVE" "Release"
update_build_setting "GCC_WARN_UNUSED_FUNCTION" "YES" "Release"
update_build_setting "GCC_WARN_UNUSED_VARIABLE" "YES" "Release"

# Swift settings
update_build_setting "SWIFT_VERSION" "5.0" "Release"
update_build_setting "SWIFT_STRICT_CONCURRENCY" "minimal" "Release"
update_build_setting "SWIFT_UPCOMING_FEATURE_CONCISE_MAGIC_FILE" "YES" "Release"
update_build_setting "SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY" "YES" "Release"
update_build_setting "SWIFT_UPCOMING_FEATURE_BARE_SLASH_REGEX_LITERALS" "YES" "Release"

print_status "Build configuration generated"

# Create Info.plist template
print_info "Creating Info.plist template..."

INFO_PLIST_PATH="$PROJECT_NAME/Info.plist"
if [ -f "$INFO_PLIST_PATH" ]; then
    print_info "Info.plist already exists, backing up..."
    cp "$INFO_PLIST_PATH" "$INFO_PLIST_PATH.backup.$(date +%Y%m%d_%H%M%S)"
fi

cat > "$INFO_PLIST_PATH" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    
    <!-- Document types for audio/video files -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>mp3</string>
                <string>wav</string>
                <string>m4a</string>
                <string>flac</string>
                <string>aac</string>
                <string>ogg</string>
            </array>
            <key>CFBundleTypeIconFile</key>
            <string>AudioFile</string>
            <key>CFBundleTypeName</key>
            <string>Audio File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.audio</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>mp4</string>
                <string>mov</string>
                <string>avi</string>
                <string>mkv</string>
                <string>webm</string>
            </array>
            <key>CFBundleTypeIconFile</key>
            <string>VideoFile</string>
            <key>CFBundleTypeName</key>
            <string>Video File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.movie</string>
            </array>
        </dict>
    </array>
    
    <!-- Exported UTIs -->
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeDescription</key>
            <string>Transcription Text File</string>
            <key>UTTypeIconFile</key>
            <string>TranscriptionFile</string>
            <key>UTTypeIdentifier</key>
            <string>com.github.cubetribe.whisper-transcription-tool.transcription</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>txt</string>
                    <string>srt</string>
                    <string>vtt</string>
                </array>
            </dict>
        </dict>
    </array>
    
    <!-- Privacy permissions -->
    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs microphone access to transcribe audio recordings.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>This app needs access to save transcription files to your Desktop.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>This app needs access to save transcription files to your Documents folder.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>This app needs access to save transcription files to your Downloads folder.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>This app needs access to save transcription files to external drives.</string>
    
    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>huggingface.co</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <false/>
                <key>NSExceptionMinimumTLSVersion</key>
                <string>TLSv1.2</string>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <true/>
            </dict>
        </dict>
    </dict>
    
    <!-- App Category -->
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    
    <!-- Copyright -->
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 WhisperLocal. All rights reserved.</string>
</dict>
</plist>
EOF

print_status "Info.plist template created"

# Display configuration summary
echo ""
echo -e "${GREEN}🎯 Configuration Summary${NC}"
echo -e "${GREEN}========================${NC}"
echo ""

if [ -f "/tmp/build_settings_Release.txt" ]; then
    echo -e "${BLUE}Release Build Settings:${NC}"
    echo "• Optimization Level: -Os (Size)"
    echo "• Swift Optimization: -O (Speed)"
    echo "• Architectures: arm64, x86_64" 
    echo "• Deployment Target: macOS 12.0+"
    echo "• Code Signing: Automatic"
    echo "• Hardened Runtime: Enabled"
    echo "• Debug Symbols: Separate dSYM"
    echo "• Strip Symbols: Yes"
    echo ""
fi

echo -e "${BLUE}Next Steps:${NC}"
echo "1. Open $XCODEPROJ_PATH in Xcode"
echo "2. Go to Project Settings → Build Settings"
echo "3. Apply the Release configuration settings:"

if [ -f "/tmp/build_settings_Release.txt" ]; then
    echo ""
    echo -e "${YELLOW}Build Settings to Configure:${NC}"
    cat "/tmp/build_settings_Release.txt"
fi

echo ""
echo "4. Verify Info.plist configuration in $INFO_PLIST_PATH"
echo "5. Test the Release build configuration"
echo "6. Run the build_release.sh script to create distribution builds"
echo ""

# Clean up temporary files
rm -f /tmp/build_settings_*.txt

print_status "Xcode project configuration completed"

echo ""
echo -e "${BLUE}📋 Manual Configuration Required:${NC}"
echo "Due to the complexity of Xcode project files, some settings must be configured manually:"
echo ""
echo "1. Open Xcode project: $XCODEPROJ_PATH"
echo "2. Select the project in the navigator"
echo "3. Select the target: $PROJECT_NAME"
echo "4. Go to 'Build Settings' tab"
echo "5. Set the following for Release configuration:"
echo "   • Optimization Level (GCC_OPTIMIZATION_LEVEL): Optimize for Size [-Os]"
echo "   • Swift Optimization Level: Optimize for Speed [-O]"
echo "   • Architectures: arm64, x86_64"
echo "   • macOS Deployment Target: 12.0"
echo "   • Code Signing Identity: Apple Development (or your preferred)"
echo "   • Enable Hardened Runtime: Yes"
echo ""
echo "6. Go to 'Signing & Capabilities' tab"
echo "7. Configure signing settings for your distribution needs"
echo ""

print_status "Configuration script completed - manual Xcode setup required"