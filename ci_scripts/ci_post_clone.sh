#!/bin/sh
set -e

echo "▶️ Flutter CI Setup Starting..."

# Use the Xcode Cloud repo path, or calculate it from script location
if [ -z "$CI_PRIMARY_REPOSITORY_PATH" ]; then
    # If not set, navigate up from ci_scripts directory to project root
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    echo "▶️ CI_PRIMARY_REPOSITORY_PATH not set, using: $PROJECT_ROOT"
    cd "$PROJECT_ROOT"
else
    echo "▶️ Using CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
    cd "$CI_PRIMARY_REPOSITORY_PATH"
fi

# Verify we're in the right directory
if [ ! -f pubspec.yaml ]; then
    echo "❌ Error: pubspec.yaml not found in current directory!"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Download Flutter SDK directly (no Homebrew)
FLUTTER_VERSION="3.41.6"  # Change to your Flutter version
echo "▶️ Downloading Flutter $FLUTTER_VERSION..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch $FLUTTER_VERSION /tmp/flutter 2>/dev/null || \
git clone https://github.com/flutter/flutter.git --depth 1 --tag $FLUTTER_VERSION /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"
export FLUTTER_ROOT="/tmp/flutter"

# Disable analytics
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true

echo "▶️ Flutter version:"
flutter --version

echo "▶️ Running flutter pub get..."
flutter pub get --no-example
flutter precache --ios

# Patch Generated.xcconfig to fix hardcoded local paths for the CI environment
if [ -f Flutter/Generated.xcconfig ]; then
    echo "▶️ Patching Generated.xcconfig..."
    sed -i '' "s|FLUTTER_ROOT=.*|FLUTTER_ROOT=/tmp/flutter|g" Flutter/Generated.xcconfig
    sed -i '' "s|FLUTTER_APPLICATION_PATH=.*|FLUTTER_APPLICATION_PATH=.|g" Flutter/Generated.xcconfig
elif [ -f ios/Flutter/Generated.xcconfig ]; then
    echo "▶️ Patching ios/Flutter/Generated.xcconfig..."
    sed -i '' "s|FLUTTER_ROOT=.*|FLUTTER_ROOT=/tmp/flutter|g" ios/Flutter/Generated.xcconfig
    sed -i '' "s|FLUTTER_APPLICATION_PATH=.*|FLUTTER_APPLICATION_PATH=..|g" ios/Flutter/Generated.xcconfig
fi

# Verify assets directory to satisfy pubspec.yaml
if [ -d assets/images ]; then
    echo "✓ Found assets directory: $(ls assets/images | head -n 3)..."
else
    echo "▶️ Creating missing assets directory..."
    mkdir -p assets/images
fi

# Create a symbolic link for the ios directory so Flutter tools can find their files
# (This is needed because the deployment repo is flattened)
if [ ! -d ios ]; then
    echo "▶️ Creating ios directory symlink..."
    mkdir -p ios
    ln -s ../Flutter ios/Flutter
fi

echo "▶️ Installing CocoaPods dependencies..."
# Change to ios directory only if it exists and we aren't already there
if [ -d ios ]; then
    echo "▶️ Changing to ios directory..."
    cd ios
elif [ -f Podfile ]; then
    echo "✓ Already in directory with Podfile, staying here."
else
    echo "❌ Error: Could not find ios directory or Podfile!"
    exit 1
fi

# Update CocoaPods repo if needed
echo "▶️ Updating CocoaPods repositories..."
pod repo update --silent 2>/dev/null || true

# Run pod install with proper flags
echo "▶️ Installing pods..."
pod install

echo "✅ CI Post Clone Complete!"