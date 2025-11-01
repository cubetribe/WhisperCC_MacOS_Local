#!/bin/bash

# Version Management Script for WhisperLocal macOS App
# Handles semantic versioning, Info.plist updates, and git tagging

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
INFO_PLIST="$PROJECT_NAME/Info.plist"
VERSION_FILE="../VERSION"
CHANGELOG_FILE="../CHANGELOG.md"

# Usage function
usage() {
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  current                    - Show current version"
    echo "  bump <type>               - Bump version (major|minor|patch)"
    echo "  set <version>             - Set specific version (e.g., 1.2.3)"
    echo "  tag                       - Create git tag for current version"
    echo "  release <type> [message]  - Full release workflow (bump + tag + changelog)"
    echo ""
    echo "Examples:"
    echo "  $0 current"
    echo "  $0 bump patch"
    echo "  $0 set 1.0.0"
    echo "  $0 release minor 'Add new transcription features'"
    exit 1
}

# Get current version from Info.plist
get_current_version() {
    if [ -f "$INFO_PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0"
    else
        echo "1.0.0"
    fi
}

# Get build number from Info.plist
get_build_number() {
    if [ -f "$INFO_PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1"
    else
        echo "1"
    fi
}

# Validate semantic version format
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format: $version"
        print_info "Version must be in format: MAJOR.MINOR.PATCH (e.g., 1.2.3)"
        exit 1
    fi
}

# Parse semantic version into components
parse_version() {
    local version="$1"
    echo "$version" | sed 's/\./ /g'
}

# Bump version based on type
bump_version() {
    local current_version="$1"
    local bump_type="$2"
    
    read -r major minor patch <<< "$(parse_version "$current_version")"
    
    case "$bump_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            print_error "Invalid bump type: $bump_type"
            print_info "Use: major, minor, or patch"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Update Info.plist with new version
update_info_plist() {
    local new_version="$1"
    local build_number="$2"
    
    if [ ! -f "$INFO_PLIST" ]; then
        print_error "Info.plist not found at $INFO_PLIST"
        exit 1
    fi
    
    print_info "Updating Info.plist..."
    /usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $new_version" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set CFBundleVersion $build_number" "$INFO_PLIST"
    
    print_status "Info.plist updated to version $new_version (build $build_number)"
}

# Update VERSION file
update_version_file() {
    local new_version="$1"
    echo "$new_version" > "$VERSION_FILE"
    print_status "VERSION file updated"
}

# Generate build number (timestamp-based)
generate_build_number() {
    date +"%Y%m%d%H%M"
}

# Create git tag
create_git_tag() {
    local version="$1"
    local message="$2"
    local tag_name="v$version"
    
    # Check if tag already exists
    if git tag -l | grep -q "^$tag_name$"; then
        print_warning "Tag $tag_name already exists"
        return
    fi
    
    print_info "Creating git tag: $tag_name"
    
    if [ -n "$message" ]; then
        git tag -a "$tag_name" -m "$message"
    else
        git tag -a "$tag_name" -m "Release $tag_name"
    fi
    
    print_status "Git tag $tag_name created"
}

# Update changelog
update_changelog() {
    local version="$1"
    local message="$2"
    local date=$(date '+%Y-%m-%d')
    
    if [ ! -f "$CHANGELOG_FILE" ]; then
        print_info "Creating new changelog file"
        cat > "$CHANGELOG_FILE" << EOF
# Changelog

All notable changes to WhisperLocal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
    fi
    
    # Create temporary file with new entry
    local temp_changelog="/tmp/changelog_temp.md"
    local header_written=false
    
    while IFS= read -r line; do
        if [ "$header_written" = false ] && [[ "$line" =~ ^##[[:space:]] ]]; then
            # Insert new version entry before first existing version
            echo "## [$version] - $date" >> "$temp_changelog"
            echo "" >> "$temp_changelog"
            if [ -n "$message" ]; then
                echo "### Changed" >> "$temp_changelog"
                echo "- $message" >> "$temp_changelog"
            else
                echo "### Changed" >> "$temp_changelog"
                echo "- Version bump to $version" >> "$temp_changelog"
            fi
            echo "" >> "$temp_changelog"
            header_written=true
        fi
        echo "$line" >> "$temp_changelog"
    done < "$CHANGELOG_FILE"
    
    # If no existing version entries found, add after header
    if [ "$header_written" = false ]; then
        echo "" >> "$CHANGELOG_FILE"
        echo "## [$version] - $date" >> "$CHANGELOG_FILE"
        echo "" >> "$CHANGELOG_FILE"
        if [ -n "$message" ]; then
            echo "### Changed" >> "$CHANGELOG_FILE"
            echo "- $message" >> "$CHANGELOG_FILE"
        else
            echo "### Changed" >> "$CHANGELOG_FILE"
            echo "- Version bump to $version" >> "$CHANGELOG_FILE"
        fi
        echo "" >> "$CHANGELOG_FILE"
    else
        mv "$temp_changelog" "$CHANGELOG_FILE"
    fi
    
    print_status "Changelog updated"
}

# Main command processing
case "$1" in
    "current")
        current_version=$(get_current_version)
        build_number=$(get_build_number)
        echo "Current version: $current_version (build $build_number)"
        ;;
        
    "bump")
        if [ -z "$2" ]; then
            print_error "Bump type required"
            usage
        fi
        
        current_version=$(get_current_version)
        new_version=$(bump_version "$current_version" "$2")
        build_number=$(generate_build_number)
        
        print_info "Bumping version from $current_version to $new_version"
        
        update_info_plist "$new_version" "$build_number"
        update_version_file "$new_version"
        
        print_status "Version bumped to $new_version"
        ;;
        
    "set")
        if [ -z "$2" ]; then
            print_error "Version required"
            usage
        fi
        
        validate_version "$2"
        build_number=$(generate_build_number)
        
        print_info "Setting version to $2"
        
        update_info_plist "$2" "$build_number"
        update_version_file "$2"
        
        print_status "Version set to $2"
        ;;
        
    "tag")
        current_version=$(get_current_version)
        create_git_tag "$current_version" "$2"
        ;;
        
    "release")
        if [ -z "$2" ]; then
            print_error "Release type required"
            usage
        fi
        
        current_version=$(get_current_version)
        new_version=$(bump_version "$current_version" "$2")
        build_number=$(generate_build_number)
        message="$3"
        
        print_info "Creating release $new_version"
        
        # Update version files
        update_info_plist "$new_version" "$build_number"
        update_version_file "$new_version"
        update_changelog "$new_version" "$message"
        
        # Commit changes
        print_info "Committing version changes..."
        git add "$INFO_PLIST" "$VERSION_FILE" "$CHANGELOG_FILE"
        git commit -m "Release v$new_version

${message:+$message

}🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        
        # Create tag
        create_git_tag "$new_version" "$message"
        
        print_status "Release $new_version completed!"
        print_info "Next steps:"
        echo "  1. Push changes: git push origin main"
        echo "  2. Push tags: git push origin v$new_version"
        echo "  3. Build release: ./build_release.sh"
        echo "  4. Create GitHub release with DMG"
        ;;
        
    *)
        print_error "Unknown command: $1"
        usage
        ;;
esac

print_status "Version management completed"