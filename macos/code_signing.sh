#!/bin/bash

# Code Signing and Notarization Script
# Handles code signing for Gatekeeper compatibility

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
SIGNING_MODE="${1:-adhoc}"  # adhoc, developer, or distribution
APP_PATH="$2"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Usage: $0 <signing_mode> <path-to-app-bundle>"
    echo ""
    echo "Signing modes:"
    echo "  adhoc       - Ad-hoc signing (local testing)"
    echo "  developer   - Developer ID signing (distribution outside App Store)"
    echo "  distribution - App Store distribution signing"
    echo ""
    echo "Example: $0 adhoc build/WhisperLocalMacOs.xcarchive/Products/Applications/WhisperLocalMacOs.app"
    exit 1
fi

echo -e "${BLUE}🔐 Code Signing Script${NC}"
echo -e "${BLUE}=====================${NC}"
echo ""

print_info "Signing mode: $SIGNING_MODE"
print_info "App bundle: $(basename "$APP_PATH")"

# Function to find signing identity
find_signing_identity() {
    local mode="$1"
    
    case "$mode" in
        "adhoc")
            echo "-"
            ;;
        "developer")
            # Find Developer ID Application certificate
            local identity=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*") //' | sed 's/ .*//')
            if [ -n "$identity" ]; then
                echo "$identity"
            else
                print_warning "Developer ID certificate not found, using ad-hoc signing"
                echo "-"
            fi
            ;;
        "distribution")
            # Find Mac App Store certificate
            local identity=$(security find-identity -v -p codesigning | grep "3rd Party Mac Developer Application" | head -1 | sed 's/.*") //' | sed 's/ .*//')
            if [ -n "$identity" ]; then
                echo "$identity"
            else
                print_warning "App Store certificate not found, using ad-hoc signing"
                echo "-"
            fi
            ;;
        *)
            print_error "Invalid signing mode: $mode"
            exit 1
            ;;
    esac
}

# Function to sign a single binary
sign_binary() {
    local binary_path="$1"
    local identity="$2"
    local entitlements="$3"
    
    print_info "Signing: $(basename "$binary_path")"
    
    local sign_args=(
        --sign "$identity"
        --force
        --timestamp
        --options runtime
        --verbose
    )
    
    if [ -n "$entitlements" ] && [ -f "$entitlements" ]; then
        sign_args+=(--entitlements "$entitlements")
    fi
    
    codesign "${sign_args[@]}" "$binary_path"
}

# Create entitlements file
create_entitlements() {
    local entitlements_path="$1"
    
    cat > "$entitlements_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
EOF
}

# Main signing process
main() {
    local identity=$(find_signing_identity "$SIGNING_MODE")
    local entitlements_file="/tmp/WhisperLocal.entitlements"
    
    print_info "Using signing identity: $identity"
    
    # Create entitlements file
    create_entitlements "$entitlements_file"
    print_status "Entitlements file created"
    
    # Remove existing signatures
    print_info "Removing existing signatures..."
    codesign --remove-signature "$APP_PATH" 2>/dev/null || true
    
    # Sign embedded dependencies first
    local dependencies_dir="$APP_PATH/Contents/Resources/Dependencies"
    if [ -d "$dependencies_dir" ]; then
        print_info "Signing embedded dependencies..."
        
        # Sign Python executables
        find "$dependencies_dir" -name "python*" -type f -perm +111 | while read -r python_exec; do
            sign_binary "$python_exec" "$identity" ""
        done
        
        # Sign Whisper.cpp binaries
        find "$dependencies_dir" -path "*/whisper.cpp-*/bin/*" -type f | while read -r whisper_bin; do
            sign_binary "$whisper_bin" "$identity" ""
        done
        
        # Sign FFmpeg binaries
        find "$dependencies_dir" -path "*/ffmpeg-*/bin/*" -type f | while read -r ffmpeg_bin; do
            sign_binary "$ffmpeg_bin" "$identity" ""
        done
        
        print_status "Dependencies signed"
    fi
    
    # Sign frameworks
    local frameworks_dir="$APP_PATH/Contents/Frameworks"
    if [ -d "$frameworks_dir" ]; then
        print_info "Signing frameworks..."
        find "$frameworks_dir" -name "*.framework" | while read -r framework; do
            sign_binary "$framework" "$identity" ""
        done
        print_status "Frameworks signed"
    fi
    
    # Sign main app bundle
    print_info "Signing main application..."
    sign_binary "$APP_PATH" "$identity" "$entitlements_file"
    
    # Verify signature
    print_info "Verifying signatures..."
    codesign --verify --deep --strict "$APP_PATH"
    
    if [ $? -eq 0 ]; then
        print_status "Code signing verification successful"
    else
        print_error "Code signing verification failed"
        exit 1
    fi
    
    # Display signature information
    print_info "Signature information:"
    codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "(Authority|TeamIdentifier|Identifier|Format)" || true
    
    # Check Gatekeeper compatibility
    if [ "$identity" != "-" ]; then
        print_info "Checking Gatekeeper compatibility..."
        spctl -a -t exec -vv "$APP_PATH" 2>&1 | head -5 || print_warning "Gatekeeper check inconclusive"
    else
        print_warning "Ad-hoc signing - Gatekeeper will show warnings"
    fi
    
    # Clean up
    rm -f "$entitlements_file"
    
    print_status "Code signing completed successfully"
    
    # Display next steps
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    
    if [ "$identity" = "-" ]; then
        echo "• Ad-hoc signed app will show security warnings"
        echo "• Users need to right-click and select 'Open' on first launch"
        echo "• Consider getting a Developer ID certificate for distribution"
    elif [ "$SIGNING_MODE" = "developer" ]; then
        echo "• App is signed with Developer ID"
        echo "• Consider notarizing for better user experience"
        echo "• Run: xcrun notarytool submit --apple-id <email> --password <app-password> --team-id <team-id> <app-path>"
    elif [ "$SIGNING_MODE" = "distribution" ]; then
        echo "• App is ready for App Store submission"
        echo "• Upload using Xcode or Application Loader"
    fi
    
    echo ""
}

# Run main function
main

print_status "Code signing script completed"