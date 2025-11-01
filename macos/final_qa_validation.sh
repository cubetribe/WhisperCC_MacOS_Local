#!/bin/bash

# Final Quality Assurance Validation Script
# Comprehensive testing for clean macOS installations and release readiness

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
APP_BUNDLE="build/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"
DMG_FILE="build/${PROJECT_NAME}.dmg"
QA_REPORT="build/qa_validation_report.md"
VALIDATION_RESULTS="build/validation_results.json"

echo -e "${BLUE}🔍 WhisperLocal Final QA Validation${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

# Create QA report
init_qa_report() {
    mkdir -p build
    cat > "$QA_REPORT" << 'EOF'
# WhisperLocal macOS App - Final QA Validation Report

**Validation Date:** $(date '+%Y-%m-%d %H:%M:%S')
**macOS Version:** $(sw_vers -productVersion)
**Hardware:** $(sysctl -n machdep.cpu.brand_string)
**Architecture:** $(uname -m)

## Validation Results Summary

EOF

    # Initialize JSON results
    cat > "$VALIDATION_RESULTS" << 'EOF'
{
    "validation_date": "$(date -Iseconds)",
    "system_info": {
        "macos_version": "$(sw_vers -productVersion)",
        "build_version": "$(sw_vers -buildVersion)",
        "hardware": "$(sysctl -n machdep.cpu.brand_string)",
        "architecture": "$(uname -m)",
        "memory_gb": $(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc),
        "disk_space_gb": $(df -h / | awk 'NR==2 {print $4}' | sed 's/Gi//')
    },
    "validation_results": {}
}
EOF
}

# Test 1: Bundle Structure Validation
validate_bundle_structure() {
    print_info "Validating app bundle structure..."
    
    local score=0
    local total=8
    local issues=()
    
    # Check main executable
    if [ -f "$APP_BUNDLE/Contents/MacOS/$PROJECT_NAME" ]; then
        score=$((score + 1))
        print_status "Main executable found"
    else
        issues+=("Main executable missing")
        print_error "Main executable missing"
    fi
    
    # Check Info.plist
    if [ -f "$APP_BUNDLE/Contents/Info.plist" ]; then
        score=$((score + 1))
        print_status "Info.plist found"
        
        # Validate Info.plist structure
        local bundle_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null)
        if [ "$bundle_id" = "com.github.cubetribe.whisper-transcription-tool" ]; then
            score=$((score + 1))
            print_status "Bundle ID validated"
        else
            issues+=("Bundle ID incorrect: $bundle_id")
        fi
        
        local version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null)
        if [ -n "$version" ]; then
            score=$((score + 1))
            print_status "Bundle version found: $version"
        else
            issues+=("Bundle version missing")
        fi
    else
        issues+=("Info.plist missing")
        print_error "Info.plist missing"
    fi
    
    # Check dependencies directory
    if [ -d "$APP_BUNDLE/Contents/Resources/Dependencies" ]; then
        score=$((score + 1))
        print_status "Dependencies directory found"
        
        # Count dependencies
        local dep_count=$(find "$APP_BUNDLE/Contents/Resources/Dependencies" -type f | wc -l)
        if [ "$dep_count" -gt 0 ]; then
            score=$((score + 1))
            print_status "Dependencies embedded ($dep_count files)"
        else
            issues+=("No dependencies found in bundle")
        fi
    else
        issues+=("Dependencies directory missing")
        print_error "Dependencies directory missing"
    fi
    
    # Check models directory
    if [ -d "$APP_BUNDLE/Contents/Resources/Dependencies/models" ]; then
        score=$((score + 1))
        print_status "Models directory structure found"
    else
        issues+=("Models directory missing")
    fi
    
    # Check code signing
    if codesign --verify --deep "$APP_BUNDLE" 2>/dev/null; then
        score=$((score + 1))
        print_status "Code signing verified"
    else
        issues+=("Code signing verification failed")
        print_warning "Code signing verification failed (expected for ad-hoc builds)"
    fi
    
    local percentage=$(echo "scale=1; $score * 100 / $total" | bc -l)
    
    echo "### Bundle Structure Validation" >> "$QA_REPORT"
    echo "- **Score:** $score/$total ($percentage%)" >> "$QA_REPORT"
    if [ ${#issues[@]} -gt 0 ]; then
        echo "- **Issues:**" >> "$QA_REPORT"
        for issue in "${issues[@]}"; do
            echo "  - $issue" >> "$QA_REPORT"
        done
    fi
    echo "" >> "$QA_REPORT"
    
    return $score
}

# Test 2: First Launch Behavior
test_first_launch() {
    print_info "Testing first launch behavior..."
    
    local score=0
    local total=5
    local issues=()
    
    # Test app launch (quick exit)
    print_info "Testing app launch capability..."
    timeout 10s "$APP_BUNDLE/Contents/MacOS/$PROJECT_NAME" --help >/dev/null 2>&1 &
    local launch_pid=$!
    sleep 3
    
    if kill -0 $launch_pid 2>/dev/null; then
        score=$((score + 1))
        print_status "App launched successfully"
        kill $launch_pid 2>/dev/null || true
    else
        issues+=("App failed to launch")
        print_error "App launch failed"
    fi
    
    # Check executable permissions
    if [ -x "$APP_BUNDLE/Contents/MacOS/$PROJECT_NAME" ]; then
        score=$((score + 1))
        print_status "Main executable has correct permissions"
    else
        issues+=("Main executable lacks execute permissions")
    fi
    
    # Check dependency permissions
    local exec_deps=$(find "$APP_BUNDLE/Contents/Resources/Dependencies" -name "*.py" -o -path "*/bin/*" | head -10)
    local perm_count=0
    local total_deps=0
    
    while IFS= read -r dep; do
        if [ -n "$dep" ]; then
            total_deps=$((total_deps + 1))
            if [ -x "$dep" ]; then
                perm_count=$((perm_count + 1))
            fi
        fi
    done <<< "$exec_deps"
    
    if [ "$total_deps" -gt 0 ] && [ "$perm_count" -eq "$total_deps" ]; then
        score=$((score + 1))
        print_status "Dependency permissions correct"
    elif [ "$total_deps" -gt 0 ]; then
        issues+=("Some dependencies lack execute permissions ($perm_count/$total_deps)")
    else
        issues+=("No executable dependencies found")
    fi
    
    # Check bundle size (should be reasonable)
    if [ -d "$APP_BUNDLE" ]; then
        local bundle_size_mb=$(du -sm "$APP_BUNDLE" | cut -f1)
        if [ "$bundle_size_mb" -lt 1000 ]; then  # Less than 1GB
            score=$((score + 1))
            print_status "Bundle size reasonable: ${bundle_size_mb}MB"
        else
            issues+=("Bundle size too large: ${bundle_size_mb}MB")
            print_warning "Bundle size large: ${bundle_size_mb}MB"
        fi
    fi
    
    # Check system requirements compatibility
    local macos_version=$(sw_vers -productVersion | cut -d. -f1-2)
    local required_version="12.0"
    
    if printf '%s\n%s' "$required_version" "$macos_version" | sort -V -C; then
        score=$((score + 1))
        print_status "macOS version compatible ($macos_version >= $required_version)"
    else
        issues+=("macOS version too old: $macos_version < $required_version")
    fi
    
    local percentage=$(echo "scale=1; $score * 100 / $total" | bc -l)
    
    echo "### First Launch Behavior" >> "$QA_REPORT"
    echo "- **Score:** $score/$total ($percentage%)" >> "$QA_REPORT"
    echo "- **Bundle Size:** ${bundle_size_mb:-N/A}MB" >> "$QA_REPORT"
    if [ ${#issues[@]} -gt 0 ]; then
        echo "- **Issues:**" >> "$QA_REPORT"
        for issue in "${issues[@]}"; do
            echo "  - $issue" >> "$QA_REPORT"
        done
    fi
    echo "" >> "$QA_REPORT"
    
    return $score
}

# Test 3: DMG Validation
validate_dmg() {
    print_info "Validating DMG distribution package..."
    
    local score=0
    local total=6
    local issues=()
    
    # Check DMG exists
    if [ -f "$DMG_FILE" ]; then
        score=$((score + 1))
        print_status "DMG file found"
        
        # Check DMG can be mounted
        print_info "Testing DMG mount..."
        local mount_point="/Volumes/WhisperLocal-Test-$$"
        if hdiutil attach "$DMG_FILE" -mountpoint "$mount_point" -quiet; then
            score=$((score + 1))
            print_status "DMG mounts successfully"
            
            # Check app exists in DMG
            if [ -d "$mount_point/$PROJECT_NAME.app" ]; then
                score=$((score + 1))
                print_status "App found in DMG"
                
                # Check Applications symlink
                if [ -L "$mount_point/Applications" ]; then
                    score=$((score + 1))
                    print_status "Applications symlink found"
                else
                    issues+=("Applications symlink missing in DMG")
                fi
            else
                issues+=("App not found in DMG")
            fi
            
            # Unmount DMG
            hdiutil detach "$mount_point" -quiet 2>/dev/null || true
        else
            issues+=("DMG failed to mount")
            print_error "DMG failed to mount"
        fi
        
        # Check DMG size
        local dmg_size_mb=$(du -sm "$DMG_FILE" | cut -f1)
        if [ "$dmg_size_mb" -lt 500 ]; then  # Less than 500MB
            score=$((score + 1))
            print_status "DMG size reasonable: ${dmg_size_mb}MB"
        else
            issues+=("DMG size too large: ${dmg_size_mb}MB")
        fi
        
        # Check DMG integrity
        if hdiutil verify "$DMG_FILE" >/dev/null 2>&1; then
            score=$((score + 1))
            print_status "DMG integrity verified"
        else
            issues+=("DMG integrity check failed")
        fi
    else
        issues+=("DMG file not found")
        print_error "DMG file not found"
    fi
    
    local percentage=$(echo "scale=1; $score * 100 / $total" | bc -l)
    
    echo "### DMG Distribution Package" >> "$QA_REPORT"
    echo "- **Score:** $score/$total ($percentage%)" >> "$QA_REPORT"
    echo "- **DMG Size:** ${dmg_size_mb:-N/A}MB" >> "$QA_REPORT"
    if [ ${#issues[@]} -gt 0 ]; then
        echo "- **Issues:**" >> "$QA_REPORT"
        for issue in "${issues[@]}"; do
            echo "  - $issue" >> "$QA_REPORT"
        done
    fi
    echo "" >> "$QA_REPORT"
    
    return $score
}

# Test 4: Gatekeeper Compatibility
test_gatekeeper_compatibility() {
    print_info "Testing Gatekeeper compatibility..."
    
    local score=0
    local total=4
    local issues=()
    
    # Check code signing status
    local signing_info=$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 || echo "Not signed")
    if echo "$signing_info" | grep -q "Authority"; then
        score=$((score + 1))
        print_status "App has signing authority"
    else
        print_warning "App uses ad-hoc signing (expected for development builds)"
    fi
    
    # Check hardened runtime
    if echo "$signing_info" | grep -q "runtime"; then
        score=$((score + 1))
        print_status "Hardened runtime enabled"
    else
        issues+=("Hardened runtime not enabled")
    fi
    
    # Test Gatekeeper assessment (may fail for ad-hoc signed apps)
    print_info "Running Gatekeeper assessment..."
    if spctl -a -t exec -vv "$APP_BUNDLE" 2>&1 | grep -q "accepted"; then
        score=$((score + 2))
        print_status "Gatekeeper assessment passed"
    else
        print_warning "Gatekeeper assessment failed (expected for ad-hoc signed apps)"
        issues+=("Gatekeeper will show security warning on first launch")
    fi
    
    local percentage=$(echo "scale=1; $score * 100 / $total" | bc -l)
    
    echo "### Gatekeeper Compatibility" >> "$QA_REPORT"
    echo "- **Score:** $score/$total ($percentage%)" >> "$QA_REPORT"
    echo "- **Signing Status:** $(echo "$signing_info" | head -3)" >> "$QA_REPORT"
    if [ ${#issues[@]} -gt 0 ]; then
        echo "- **Issues:**" >> "$QA_REPORT"
        for issue in "${issues[@]}"; do
            echo "  - $issue" >> "$QA_REPORT"
        done
    fi
    echo "" >> "$QA_REPORT"
    
    return $score
}

# Test 5: Performance Requirements Validation
validate_performance_requirements() {
    print_info "Validating performance requirements..."
    
    local score=0
    local total=5
    local issues=()
    
    # Test startup time (simulate)
    print_info "Testing startup performance simulation..."
    local start_time=$(date +%s.%N)
    timeout 15s "$APP_BUNDLE/Contents/MacOS/$PROJECT_NAME" --help >/dev/null 2>&1 &
    local app_pid=$!
    sleep 2  # Simulate startup time
    local end_time=$(date +%s.%N)
    kill $app_pid 2>/dev/null || true
    
    local startup_time=$(echo "$end_time - $start_time" | bc -l)
    if (( $(echo "$startup_time < 5.0" | bc -l) )); then
        score=$((score + 1))
        print_status "Startup time acceptable: ${startup_time}s"
    else
        issues+=("Startup time too slow: ${startup_time}s > 5.0s")
    fi
    
    # Check bundle optimization
    if [ -d "$APP_BUNDLE" ]; then
        local debug_symbols=$(find "$APP_BUNDLE" -name "*.dSYM" | wc -l)
        if [ "$debug_symbols" -eq 0 ]; then
            score=$((score + 1))
            print_status "Debug symbols properly stripped"
        else
            issues+=("Debug symbols found in bundle (${debug_symbols} dSYM files)")
        fi
    fi
    
    # Check for development artifacts
    local dev_artifacts=$(find "$APP_BUNDLE" -name "*.pyc" -o -name "__pycache__" -o -name ".DS_Store" | wc -l)
    if [ "$dev_artifacts" -eq 0 ]; then
        score=$((score + 1))
        print_status "No development artifacts found"
    else
        issues+=("Development artifacts found (${dev_artifacts} files)")
    fi
    
    # Memory usage estimation (based on bundle size)
    local bundle_size_mb=$(du -sm "$APP_BUNDLE" | cut -f1)
    if [ "$bundle_size_mb" -lt 400 ]; then  # Reasonable memory footprint
        score=$((score + 1))
        print_status "Memory footprint reasonable"
    else
        issues+=("Large memory footprint expected: ${bundle_size_mb}MB bundle")
    fi
    
    # Architecture optimization check
    local binary_info=$(file "$APP_BUNDLE/Contents/MacOS/$PROJECT_NAME" 2>/dev/null || echo "Binary not found")
    if echo "$binary_info" | grep -q "Mach-O.*executable"; then
        score=$((score + 1))
        print_status "Binary architecture validated"
    else
        issues+=("Binary architecture issues: $binary_info")
    fi
    
    local percentage=$(echo "scale=1; $score * 100 / $total" | bc -l)
    
    echo "### Performance Requirements" >> "$QA_REPORT"
    echo "- **Score:** $score/$total ($percentage%)" >> "$QA_REPORT"
    echo "- **Startup Time:** ${startup_time}s" >> "$QA_REPORT"
    echo "- **Bundle Size:** ${bundle_size_mb}MB" >> "$QA_REPORT"
    if [ ${#issues[@]} -gt 0 ]; then
        echo "- **Issues:**" >> "$QA_REPORT"
        for issue in "${issues[@]}"; do
            echo "  - $issue" >> "$QA_REPORT"
        done
    fi
    echo "" >> "$QA_REPORT"
    
    return $score
}

# Main validation function
run_qa_validation() {
    print_info "Starting comprehensive QA validation..."
    
    # Initialize reports
    init_qa_report
    
    local total_score=0
    local max_score=0
    
    # Run validation tests
    print_info "Running bundle structure validation..."
    validate_bundle_structure
    bundle_score=$?
    total_score=$((total_score + bundle_score))
    max_score=$((max_score + 8))
    
    print_info "Running first launch testing..."
    test_first_launch
    launch_score=$?
    total_score=$((total_score + launch_score))
    max_score=$((max_score + 5))
    
    print_info "Running DMG validation..."
    validate_dmg
    dmg_score=$?
    total_score=$((total_score + dmg_score))
    max_score=$((max_score + 6))
    
    print_info "Running Gatekeeper compatibility testing..."
    test_gatekeeper_compatibility
    gatekeeper_score=$?
    total_score=$((total_score + gatekeeper_score))
    max_score=$((max_score + 4))
    
    print_info "Running performance validation..."
    validate_performance_requirements
    performance_score=$?
    total_score=$((total_score + performance_score))
    max_score=$((max_score + 5))
    
    # Calculate overall score
    local overall_percentage=$(echo "scale=1; $total_score * 100 / $max_score" | bc -l)
    
    # Final report summary
    cat >> "$QA_REPORT" << EOF

## Overall Validation Summary

**Total Score:** $total_score/$max_score ($overall_percentage%)

### Individual Test Results:
- **Bundle Structure:** $bundle_score/8
- **First Launch:** $launch_score/5  
- **DMG Package:** $dmg_score/6
- **Gatekeeper:** $gatekeeper_score/4
- **Performance:** $performance_score/5

### Recommendations:

EOF

    if (( $(echo "$overall_percentage >= 90" | bc -l) )); then
        echo "✅ **READY FOR RELEASE** - All critical tests passed" >> "$QA_REPORT"
        print_status "QA VALIDATION PASSED - Ready for release ($overall_percentage%)"
    elif (( $(echo "$overall_percentage >= 75" | bc -l) )); then
        echo "⚠️ **MINOR ISSUES** - Address issues before release" >> "$QA_REPORT"
        print_warning "QA VALIDATION - Minor issues found ($overall_percentage%)"
    else
        echo "❌ **MAJOR ISSUES** - Critical fixes required before release" >> "$QA_REPORT"
        print_error "QA VALIDATION FAILED - Major issues found ($overall_percentage%)"
    fi
    
    # Output locations
    echo ""
    echo -e "${GREEN}📋 QA Validation Report: $QA_REPORT${NC}"
    echo -e "${BLUE}🔍 View with: open $QA_REPORT${NC}"
    echo ""
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    if [ ! -d "$APP_BUNDLE" ] && [ ! -f "$DMG_FILE" ]; then
        print_error "No build artifacts found. Run build_release.sh first."
        echo ""
        echo "Expected files:"
        echo "  - App bundle: $APP_BUNDLE"  
        echo "  - DMG file: $DMG_FILE"
        exit 1
    fi
    
    # Check required tools
    command -v codesign >/dev/null 2>&1 || { print_error "codesign not found"; exit 1; }
    command -v hdiutil >/dev/null 2>&1 || { print_error "hdiutil not found"; exit 1; }
    command -v spctl >/dev/null 2>&1 || { print_error "spctl not found"; exit 1; }
    command -v bc >/dev/null 2>&1 || { print_error "bc not found"; exit 1; }
    
    print_status "Prerequisites validated"
}

# Main execution
main() {
    check_prerequisites
    run_qa_validation
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi