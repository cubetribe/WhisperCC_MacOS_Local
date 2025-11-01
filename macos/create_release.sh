#!/bin/bash

# Automated Release Creation Script for WhisperLocal macOS App
# Handles the complete release pipeline from version bump to distribution

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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
PROJECT_NAME="WhisperLocalMacOs"
BUILD_PATH="build"
RELEASE_PATH="releases"
SIGNING_MODE="adhoc"  # Change to "developer" for distribution builds

# Usage function
usage() {
    echo "Usage: $0 <release_type> [release_message] [--sign=<mode>]"
    echo ""
    echo "Release types:"
    echo "  patch   - Bug fixes and minor improvements (x.x.N)"
    echo "  minor   - New features (x.N.x)"
    echo "  major   - Breaking changes or major releases (N.x.x)"
    echo ""
    echo "Options:"
    echo "  --sign=<mode>  - Code signing mode (adhoc|developer|distribution)"
    echo ""
    echo "Examples:"
    echo "  $0 patch 'Fix audio processing bug'"
    echo "  $0 minor 'Add new transcription features' --sign=developer"
    echo "  $0 major 'Version 2.0 with new UI' --sign=distribution"
    exit 1
}

# Parse command line arguments
RELEASE_TYPE="$1"
RELEASE_MESSAGE="$2"

# Parse options
for arg in "$@"; do
    case $arg in
        --sign=*)
            SIGNING_MODE="${arg#*=}"
            ;;
    esac
done

# Validate inputs
if [ -z "$RELEASE_TYPE" ]; then
    print_error "Release type is required"
    usage
fi

if [[ ! "$RELEASE_TYPE" =~ ^(patch|minor|major)$ ]]; then
    print_error "Invalid release type: $RELEASE_TYPE"
    usage
fi

if [[ ! "$SIGNING_MODE" =~ ^(adhoc|developer|distribution)$ ]]; then
    print_error "Invalid signing mode: $SIGNING_MODE"
    usage
fi

echo -e "${BLUE}🚀 WhisperLocal Release Creation Script${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

print_info "Release type: $RELEASE_TYPE"
print_info "Signing mode: $SIGNING_MODE"
if [ -n "$RELEASE_MESSAGE" ]; then
    print_info "Release message: $RELEASE_MESSAGE"
fi

# Pre-flight checks
pre_flight_checks() {
    print_info "Running pre-flight checks..."
    
    # Check if we're in the right directory
    if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        print_error "Not in the macos directory. Please run from macos/ directory."
        exit 1
    fi
    
    # Check git status
    if ! git diff-index --quiet HEAD --; then
        print_error "Working directory is not clean. Commit or stash changes first."
        echo "Uncommitted changes:"
        git status --porcelain
        exit 1
    fi
    
    # Check if on main branch
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ]; then
        print_warning "Not on main branch (current: $current_branch)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check for required tools
    command -v xcodebuild >/dev/null 2>&1 || { print_error "xcodebuild not found"; exit 1; }
    command -v hdiutil >/dev/null 2>&1 || { print_error "hdiutil not found"; exit 1; }
    command -v codesign >/dev/null 2>&1 || { print_error "codesign not found"; exit 1; }
    
    # Check dependencies
    if [ ! -d "../deps/whisper.cpp" ]; then
        print_warning "Whisper.cpp dependencies not found. Run install.sh first."
    fi
    
    print_status "Pre-flight checks passed"
}

# Create release directory structure
setup_release_directories() {
    print_info "Setting up release directories..."
    
    mkdir -p "$RELEASE_PATH"
    mkdir -p "$RELEASE_PATH/archives"
    mkdir -p "$RELEASE_PATH/dmg"
    mkdir -p "$RELEASE_PATH/notes"
    
    print_status "Release directories created"
}

# Generate release notes
generate_release_notes() {
    local version="$1"
    local message="$2"
    local notes_file="$RELEASE_PATH/notes/v${version}.md"
    
    print_info "Generating release notes..."
    
    cat > "$notes_file" << EOF
# WhisperLocal v${version}

Release Date: $(date '+%B %d, %Y')

## What's New

${message:-"Version ${version} release with improvements and bug fixes."}

## Changes

$(git log --oneline --no-merges $(git describe --tags --abbrev=0 HEAD^)..HEAD 2>/dev/null | sed 's/^/- /' || echo "- Initial release")

## System Requirements

- macOS 12.0 (Monterey) or later
- Apple Silicon (M1/M2) or Intel processor
- 4GB RAM minimum (8GB recommended)
- 2GB free disk space

## Installation

1. Download the DMG file below
2. Open the DMG and drag WhisperLocal to Applications
3. Right-click the app and select "Open" on first launch
4. Follow the setup wizard to configure your preferences

## Known Issues

- First launch may show security warning (expected for ad-hoc signed builds)
- Large model downloads may take time depending on internet connection

---

**Checksums:**
- DMG SHA256: \`(will be generated after build)\`

**Support:**
- [GitHub Issues](https://github.com/your-username/whisper-clean/issues)
- [Documentation](https://github.com/your-username/whisper-clean/wiki)
EOF

    print_status "Release notes generated: $notes_file"
}

# Create GitHub release (if gh CLI is available)
create_github_release() {
    local version="$1"
    local dmg_file="$2"
    local notes_file="$3"
    
    if ! command -v gh >/dev/null 2>&1; then
        print_warning "GitHub CLI not found. Skipping GitHub release creation."
        return
    fi
    
    print_info "Creating GitHub release..."
    
    # Create release
    gh release create "v$version" \
        --title "WhisperLocal v$version" \
        --notes-file "$notes_file" \
        "$dmg_file"
    
    if [ $? -eq 0 ]; then
        print_status "GitHub release created successfully"
        print_info "Release URL: $(gh release view "v$version" --json url --jq .url)"
    else
        print_warning "Failed to create GitHub release"
    fi
}

# Calculate file checksums
calculate_checksums() {
    local dmg_file="$1"
    local version="$2"
    local checksums_file="$RELEASE_PATH/checksums_v${version}.txt"
    
    print_info "Calculating checksums..."
    
    if [ -f "$dmg_file" ]; then
        echo "WhisperLocal v${version} Checksums" > "$checksums_file"
        echo "=================================" >> "$checksums_file"
        echo "" >> "$checksums_file"
        echo "SHA256:" >> "$checksums_file"
        shasum -a 256 "$dmg_file" >> "$checksums_file"
        echo "" >> "$checksums_file"
        echo "MD5:" >> "$checksums_file"
        md5 "$dmg_file" >> "$checksums_file"
        
        # Update release notes with actual checksum
        local sha256_hash=$(shasum -a 256 "$dmg_file" | cut -d ' ' -f 1)
        local notes_file="$RELEASE_PATH/notes/v${version}.md"
        sed -i "" "s/(will be generated after build)/$sha256_hash/" "$notes_file"
        
        print_status "Checksums calculated and saved to $checksums_file"
    else
        print_warning "DMG file not found for checksum calculation"
    fi
}

# Archive release artifacts
archive_release() {
    local version="$1"
    local archive_dir="$RELEASE_PATH/archives/v${version}"
    
    print_info "Archiving release artifacts..."
    
    mkdir -p "$archive_dir"
    
    # Copy build artifacts
    if [ -d "$BUILD_PATH" ]; then
        cp -R "$BUILD_PATH"/*.dmg "$archive_dir/" 2>/dev/null || true
        cp -R "$BUILD_PATH"/*.xcarchive "$archive_dir/" 2>/dev/null || true
    fi
    
    # Copy release notes and checksums
    cp "$RELEASE_PATH/notes/v${version}.md" "$archive_dir/" 2>/dev/null || true
    cp "$RELEASE_PATH/checksums_v${version}.txt" "$archive_dir/" 2>/dev/null || true
    
    print_status "Release artifacts archived to $archive_dir"
}

# Main release process
main() {
    print_info "Starting release creation process..."
    
    # Run pre-flight checks
    pre_flight_checks
    
    # Setup directories
    setup_release_directories
    
    # Create version and tag
    print_info "Creating version $RELEASE_TYPE..."
    chmod +x version_management.sh
    ./version_management.sh release "$RELEASE_TYPE" "$RELEASE_MESSAGE"
    
    # Get the new version
    NEW_VERSION=$(./version_management.sh current | grep "Current version:" | cut -d ':' -f 2 | cut -d ' ' -f 2)
    print_status "New version: $NEW_VERSION"
    
    # Generate release notes
    generate_release_notes "$NEW_VERSION" "$RELEASE_MESSAGE"
    
    # Build the application
    print_info "Building application..."
    chmod +x build_release.sh
    ./build_release.sh
    
    if [ $? -ne 0 ]; then
        print_error "Build failed"
        exit 1
    fi
    
    # Code signing
    if [ -d "$BUILD_PATH/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app" ]; then
        print_info "Code signing application..."
        chmod +x code_signing.sh
        ./code_signing.sh "$SIGNING_MODE" "$BUILD_PATH/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"
    fi
    
    # Bundle optimization
    if [ -d "$BUILD_PATH/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app" ]; then
        print_info "Optimizing bundle..."
        chmod +x optimize_bundle.sh
        ./optimize_bundle.sh "$BUILD_PATH/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"
    fi
    
    # Copy DMG to releases directory
    DMG_SOURCE="$BUILD_PATH/${PROJECT_NAME}.dmg"
    DMG_TARGET="$RELEASE_PATH/dmg/WhisperLocal-v${NEW_VERSION}.dmg"
    
    if [ -f "$DMG_SOURCE" ]; then
        cp "$DMG_SOURCE" "$DMG_TARGET"
        print_status "DMG copied to releases directory"
    else
        print_error "DMG file not found"
        exit 1
    fi
    
    # Calculate checksums
    calculate_checksums "$DMG_TARGET" "$NEW_VERSION"
    
    # Archive artifacts
    archive_release "$NEW_VERSION"
    
    # Create GitHub release
    create_github_release "$NEW_VERSION" "$DMG_TARGET" "$RELEASE_PATH/notes/v${NEW_VERSION}.md"
    
    # Final summary
    echo ""
    echo -e "${GREEN}🎉 Release Creation Complete!${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo ""
    echo "📦 Release: v$NEW_VERSION"
    echo "💿 DMG: $DMG_TARGET"
    echo "📋 Notes: $RELEASE_PATH/notes/v${NEW_VERSION}.md"
    echo "🔐 Signing: $SIGNING_MODE"
    echo "📁 Archive: $RELEASE_PATH/archives/v${NEW_VERSION}/"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Test the release build on different macOS versions"
    echo "2. Update documentation and website"
    echo "3. Announce the release"
    echo ""
    
    if [ "$SIGNING_MODE" = "adhoc" ]; then
        echo -e "${YELLOW}Note: Ad-hoc signed build will show security warnings.${NC}"
        echo -e "${YELLOW}For distribution, use --sign=developer or --sign=distribution${NC}"
    fi
    
    print_status "Release creation completed successfully! 🚀"
}

# Run main function
main