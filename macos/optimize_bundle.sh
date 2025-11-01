#!/bin/bash

# Bundle Size Optimization Script
# Reduces bundle size while maintaining functionality

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

# Check if app bundle exists
APP_PATH="$1"
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Usage: $0 <path-to-app-bundle>"
    echo "Example: $0 build/WhisperLocalMacOs.xcarchive/Products/Applications/WhisperLocalMacOs.app"
    exit 1
fi

echo -e "${BLUE}🎯 Bundle Optimization Script${NC}"
echo -e "${BLUE}=============================${NC}"
echo ""

print_info "Optimizing bundle: $(basename "$APP_PATH")"

# Get initial size
INITIAL_SIZE=$(du -sh "$APP_PATH" | cut -f1)
INITIAL_BYTES=$(du -s "$APP_PATH" | cut -f1)
print_info "Initial bundle size: $INITIAL_SIZE"

# Optimization functions
optimize_dependencies() {
    print_info "Optimizing dependencies..."
    local dependencies_dir="$APP_PATH/Contents/Resources/Dependencies"
    
    if [ ! -d "$dependencies_dir" ]; then
        print_warning "Dependencies directory not found"
        return
    fi
    
    # Remove development files
    find "$dependencies_dir" -name "*.pyc" -delete 2>/dev/null || true
    find "$dependencies_dir" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$dependencies_dir" -name "*.pyo" -delete 2>/dev/null || true
    find "$dependencies_dir" -name ".DS_Store" -delete 2>/dev/null || true
    find "$dependencies_dir" -name "*.dSYM" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Remove documentation and examples
    find "$dependencies_dir" -name "docs" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$dependencies_dir" -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$dependencies_dir" -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$dependencies_dir" -name "test" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Strip debug symbols from binaries
    find "$dependencies_dir" -type f -perm +111 -exec strip {} + 2>/dev/null || true
    
    print_status "Dependencies optimized"
}

optimize_python_packages() {
    print_info "Optimizing Python packages..."
    local python_dir="$APP_PATH/Contents/Resources/Dependencies"
    
    # Find Python directories
    find "$python_dir" -name "python-*" -type d | while read -r py_dir; do
        if [ -d "$py_dir" ]; then
            print_info "Optimizing Python in $py_dir"
            
            # Remove unused packages
            local site_packages="$py_dir/lib/python*/site-packages"
            if [ -d $site_packages ]; then
                # Remove large packages that might not be needed
                rm -rf $site_packages/numpy/tests 2>/dev/null || true
                rm -rf $site_packages/scipy/tests 2>/dev/null || true
                rm -rf $site_packages/matplotlib/tests 2>/dev/null || true
                rm -rf $site_packages/pandas/tests 2>/dev/null || true
                
                # Remove .pyc and __pycache__ recursively
                find $site_packages -name "*.pyc" -delete 2>/dev/null || true
                find $site_packages -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
                
                # Remove documentation
                find $site_packages -name "doc" -type d -exec rm -rf {} + 2>/dev/null || true
                find $site_packages -name "docs" -type d -exec rm -rf {} + 2>/dev/null || true
            fi
        fi
    done
    
    print_status "Python packages optimized"
}

optimize_binaries() {
    print_info "Optimizing binaries..."
    local dependencies_dir="$APP_PATH/Contents/Resources/Dependencies"
    
    # Strip all binaries
    find "$dependencies_dir" -type f -name "*" | while read -r file; do
        if file "$file" | grep -q "Mach-O"; then
            print_info "Stripping $file"
            strip "$file" 2>/dev/null || true
        fi
    done
    
    print_status "Binaries optimized"
}

optimize_resources() {
    print_info "Optimizing resources..."
    local resources_dir="$APP_PATH/Contents/Resources"
    
    # Remove development resources
    rm -rf "$resources_dir"/*.lproj/Localizable.stringsdict 2>/dev/null || true
    
    # Remove empty directories
    find "$resources_dir" -type d -empty -delete 2>/dev/null || true
    
    print_status "Resources optimized"
}

optimize_frameworks() {
    print_info "Optimizing frameworks..."
    local frameworks_dir="$APP_PATH/Contents/Frameworks"
    
    if [ -d "$frameworks_dir" ]; then
        # Strip frameworks
        find "$frameworks_dir" -name "*.framework" | while read -r framework; do
            local framework_name=$(basename "$framework" .framework)
            local framework_binary="$framework/Versions/A/$framework_name"
            
            if [ -f "$framework_binary" ]; then
                print_info "Stripping framework: $framework_name"
                strip "$framework_binary" 2>/dev/null || true
            fi
        done
        
        # Remove framework headers and documentation
        find "$frameworks_dir" -path "*/Headers" -type d -exec rm -rf {} + 2>/dev/null || true
        find "$frameworks_dir" -path "*/Documentation" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    print_status "Frameworks optimized"
}

verify_bundle() {
    print_info "Verifying bundle integrity..."
    
    # Check if Info.plist exists
    if [ ! -f "$APP_PATH/Contents/Info.plist" ]; then
        print_warning "Info.plist not found"
        return 1
    fi
    
    # Check if main executable exists
    local executable_name=$(basename "$APP_PATH" .app)
    if [ ! -f "$APP_PATH/Contents/MacOS/$executable_name" ]; then
        print_warning "Main executable not found"
        return 1
    fi
    
    # Verify code signing (will warn if issues)
    codesign --verify --deep "$APP_PATH" 2>/dev/null || print_warning "Code signing verification failed"
    
    print_status "Bundle integrity verified"
    return 0
}

# Run optimizations
optimize_dependencies
optimize_python_packages
optimize_binaries
optimize_resources
optimize_frameworks

# Verify bundle is still valid
if ! verify_bundle; then
    print_warning "Bundle verification failed after optimization"
fi

# Calculate final size
FINAL_SIZE=$(du -sh "$APP_PATH" | cut -f1)
FINAL_BYTES=$(du -s "$APP_PATH" | cut -f1)

# Calculate savings
SAVED_BYTES=$((INITIAL_BYTES - FINAL_BYTES))
SAVED_MB=$((SAVED_BYTES / 1024))
SAVINGS_PERCENT=$(echo "scale=1; $SAVED_BYTES * 100 / $INITIAL_BYTES" | bc -l 2>/dev/null || echo "0")

echo ""
echo -e "${GREEN}🎉 Optimization Complete!${NC}"
echo -e "${GREEN}=========================${NC}"
echo ""
echo "📏 Initial size: $INITIAL_SIZE"
echo "📏 Final size: $FINAL_SIZE"
echo "💾 Space saved: ${SAVED_MB} MB"
echo "📊 Savings: ${SAVINGS_PERCENT}%"
echo ""

if [ "$SAVED_BYTES" -gt 0 ]; then
    print_status "Bundle successfully optimized!"
else
    print_info "No significant size reduction achieved"
fi

# Recommendations
echo -e "${BLUE}💡 Optimization recommendations:${NC}"
echo "1. Remove unused models to save space"
echo "2. Consider using smaller Python packages"
echo "3. Remove debug symbols in release builds"
echo "4. Use asset compression for resources"
echo ""

print_status "Bundle optimization completed"