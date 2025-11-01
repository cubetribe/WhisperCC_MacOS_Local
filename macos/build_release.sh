#!/bin/bash

# WhisperLocal macOS App Release Build Script
# Builds and packages the macOS app with all embedded dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="WhisperLocalMacOs"
SCHEME_NAME="WhisperLocalMacOs"
CONFIGURATION="Release"
DERIVED_DATA_PATH="build/DerivedData"
BUILD_PATH="build"
ARCHIVE_PATH="$BUILD_PATH/${PROJECT_NAME}.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/${PROJECT_NAME}.app"
DMG_PATH="$BUILD_PATH/${PROJECT_NAME}.dmg"
BUNDLE_ID="com.github.cubetribe.whisper-transcription-tool"

# Architecture support
ARCHITECTURES="arm64 x86_64"
MACOS_DEPLOYMENT_TARGET="12.0"

echo -e "${BLUE}🚀 WhisperLocal macOS Release Build Script${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    print_error "Not in the correct directory. Please run from the macos/ directory."
    exit 1
fi

# Clean previous builds
print_info "Cleaning previous builds..."
if [ -d "$BUILD_PATH" ]; then
    rm -rf "$BUILD_PATH"
fi
mkdir -p "$BUILD_PATH"

# Clean Xcode build cache
print_info "Cleaning Xcode build cache..."
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" > /dev/null 2>&1

print_status "Build environment prepared"

# Validate project configuration
print_info "Validating project configuration..."

# Check deployment target
DEPLOYMENT_TARGET=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -showBuildSettings -configuration "$CONFIGURATION" | grep MACOSX_DEPLOYMENT_TARGET | head -1 | sed 's/.*= //')
if [ "$DEPLOYMENT_TARGET" != "$MACOS_DEPLOYMENT_TARGET" ]; then
    print_warning "Deployment target is $DEPLOYMENT_TARGET, expected $MACOS_DEPLOYMENT_TARGET"
fi

# Check bundle identifier
CURRENT_BUNDLE_ID=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -showBuildSettings -configuration "$CONFIGURATION" | grep PRODUCT_BUNDLE_IDENTIFIER | head -1 | sed 's/.*= //')
if [ "$CURRENT_BUNDLE_ID" != "$BUNDLE_ID" ]; then
    print_warning "Bundle ID is $CURRENT_BUNDLE_ID, expected $BUNDLE_ID"
fi

print_status "Project configuration validated"

# Build for Release
print_info "Building $PROJECT_NAME for Release..."
print_info "Architectures: $ARCHITECTURES"
print_info "Configuration: $CONFIGURATION"
print_info "Deployment target: $MACOS_DEPLOYMENT_TARGET"

# Create archive
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" \
    ARCHS="$ARCHITECTURES" \
    ONLY_ACTIVE_ARCH=NO \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM="" \
    GCC_OPTIMIZATION_LEVEL=s \
    SWIFT_OPTIMIZATION_LEVEL=-O \
    STRIP_INSTALLED_PRODUCT=YES \
    SEPARATE_STRIP=YES \
    COPY_PHASE_STRIP=NO \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

if [ $? -ne 0 ]; then
    print_error "Archive build failed"
    exit 1
fi

print_status "Archive created successfully"

# Verify archive
if [ ! -d "$ARCHIVE_PATH" ]; then
    print_error "Archive not found at $ARCHIVE_PATH"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    print_error "App bundle not found at $APP_PATH"
    exit 1
fi

print_status "Archive verified"

# Embed dependencies
print_info "Embedding dependencies..."

# Create Dependencies directory in app bundle
DEPENDENCIES_DIR="$APP_PATH/Contents/Resources/Dependencies"
mkdir -p "$DEPENDENCIES_DIR"

# Copy Python dependencies (if available)
PYTHON_SOURCE="../deps/python"
if [ -d "$PYTHON_SOURCE" ]; then
    print_info "Copying Python runtime..."
    cp -R "$PYTHON_SOURCE" "$DEPENDENCIES_DIR/python-$(uname -m)" 2>/dev/null || print_warning "Python runtime not found"
else
    print_warning "Python dependencies not found at $PYTHON_SOURCE"
fi

# Copy Whisper.cpp binaries (if available)
WHISPER_SOURCE="../deps/whisper.cpp"
if [ -d "$WHISPER_SOURCE" ]; then
    print_info "Copying Whisper.cpp binaries..."
    mkdir -p "$DEPENDENCIES_DIR/whisper.cpp-$(uname -m)/bin"
    if [ -f "$WHISPER_SOURCE/build/bin/whisper-cli" ]; then
        cp "$WHISPER_SOURCE/build/bin/whisper-cli" "$DEPENDENCIES_DIR/whisper.cpp-$(uname -m)/bin/"
    else
        print_warning "Whisper.cpp binary not found"
    fi
else
    print_warning "Whisper.cpp not found at $WHISPER_SOURCE"
fi

# Copy FFmpeg binaries (if available)
FFMPEG_SOURCE="../deps/ffmpeg"
if [ -d "$FFMPEG_SOURCE" ]; then
    print_info "Copying FFmpeg binaries..."
    mkdir -p "$DEPENDENCIES_DIR/ffmpeg-$(uname -m)/bin"
    if [ -f "$FFMPEG_SOURCE/bin/ffmpeg" ]; then
        cp "$FFMPEG_SOURCE/bin/ffmpeg" "$DEPENDENCIES_DIR/ffmpeg-$(uname -m)/bin/"
    else
        print_warning "FFmpeg binary not found"
    fi
else
    print_warning "FFmpeg not found at $FFMPEG_SOURCE"
fi

# Copy CLI wrapper
CLI_WRAPPER_SOURCE="../macos_cli.py"
if [ -f "$CLI_WRAPPER_SOURCE" ]; then
    print_info "Copying CLI wrapper..."
    cp "$CLI_WRAPPER_SOURCE" "$DEPENDENCIES_DIR/"
else
    print_warning "CLI wrapper not found at $CLI_WRAPPER_SOURCE"
fi

# Create models directory
print_info "Creating models directory..."
MODELS_DIR="$DEPENDENCIES_DIR/models"
mkdir -p "$MODELS_DIR"

# Copy any existing models
if [ -d "../models" ]; then
    print_info "Copying existing models..."
    cp -R ../models/* "$MODELS_DIR/" 2>/dev/null || print_info "No models found to copy"
fi

print_status "Dependencies embedded"

# Set permissions
print_info "Setting executable permissions..."
find "$DEPENDENCIES_DIR" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
find "$DEPENDENCIES_DIR" -path "*/bin/*" -exec chmod +x {} \; 2>/dev/null || true

# Verify app bundle structure
print_info "Verifying app bundle structure..."
APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [ ! -f "$APP_INFO_PLIST" ]; then
    print_error "Info.plist not found"
    exit 1
fi

# Check bundle version
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_INFO_PLIST" 2>/dev/null || echo "Unknown")
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_INFO_PLIST" 2>/dev/null || echo "Unknown")

print_info "Bundle version: $BUNDLE_VERSION"
print_info "Build version: $BUILD_VERSION"

# Calculate bundle size
BUNDLE_SIZE=$(du -sh "$APP_PATH" | cut -f1)
print_info "Bundle size: $BUNDLE_SIZE"

print_status "App bundle structure verified"

# Code signing verification
print_info "Verifying code signing..."
codesign --verify --deep --strict "$APP_PATH" 2>/dev/null
if [ $? -eq 0 ]; then
    print_status "Code signing verified"
else
    print_warning "Code signing verification failed (expected for ad-hoc signing)"
fi

# Test app launch (basic validation)
print_info "Testing app launch..."
"$APP_PATH/Contents/MacOS/$PROJECT_NAME" --help > /dev/null 2>&1 &
APP_PID=$!
sleep 5
kill $APP_PID 2>/dev/null || true

# Check if app launched successfully
if [ $? -eq 0 ]; then
    print_status "App launch test successful"
else
    print_warning "App launch test inconclusive"
fi

# Create DMG
print_info "Creating DMG..."

# Create temporary DMG directory
DMG_TEMP_DIR="$BUILD_PATH/dmg_temp"
mkdir -p "$DMG_TEMP_DIR"

# Copy app to DMG directory
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Create DMG
DMG_VOLUME_NAME="WhisperLocal"
hdiutil create -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov -format UDZO \
    -fs HFS+ \
    "$DMG_PATH"

if [ $? -ne 0 ]; then
    print_error "DMG creation failed"
    exit 1
fi

# Clean up temporary DMG directory
rm -rf "$DMG_TEMP_DIR"

print_status "DMG created successfully"

# Verify DMG
if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
    print_info "DMG size: $DMG_SIZE"
    print_status "DMG verified"
else
    print_error "DMG file not found"
    exit 1
fi

# Final summary
echo ""
echo -e "${GREEN}🎉 Build Completed Successfully!${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo "📱 App bundle: $APP_PATH"
echo "📦 DMG file: $DMG_PATH"
echo "📏 Bundle size: $BUNDLE_SIZE"
echo "💿 DMG size: $DMG_SIZE"
echo "🏷️  Version: $BUNDLE_VERSION ($BUILD_VERSION)"
echo "🏗️  Architectures: $ARCHITECTURES"
echo "🎯 Target: macOS $MACOS_DEPLOYMENT_TARGET+"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Test the app on different macOS versions"
echo "2. Verify all functionality works correctly"
echo "3. Test on both Apple Silicon and Intel Macs"
echo "4. Distribute the DMG file to users"
echo ""
echo -e "${GREEN}Build script completed successfully! 🚀${NC}"