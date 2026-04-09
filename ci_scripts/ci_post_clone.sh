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

# Search for pubspec.yaml in current directory or subdirectories
echo "▶️ Searching for pubspec.yaml..."
if [ -f pubspec.yaml ]; then
    echo "✓ Found pubspec.yaml in $(pwd)"
elif [ -f flutter/pubspec.yaml ]; then
    echo "✓ Found pubspec.yaml in flutter/ subdirectory"
    cd flutter
elif [ -d MCSpace-Mobile-app-main ] && [ -f MCSpace-Mobile-app-main/pubspec.yaml ]; then
    echo "✓ Found pubspec.yaml in MCSpace-Mobile-app-main/ subdirectory"
    cd MCSpace-Mobile-app-main
else
    echo "❌ Error: pubspec.yaml not found!"
    echo "Current directory: $(pwd)"
    echo "Contents:"
    ls -la
    exit 1
fi

echo "▶️ Working directory: $(pwd)"

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
# In Xcode Cloud flattened layout, Flutter/ is at the repo root (not inside ios/).
# Flutter's xcode_backend.sh always looks for:
#   $FLUTTER_APPLICATION_PATH/ios/Flutter/AppFrameworkInfo.plist
# So with FLUTTER_APPLICATION_PATH=. we need ios/Flutter/ to exist and mirror Flutter/.
if [ -f Flutter/Generated.xcconfig ]; then
    echo "▶️ Patching Flutter/Generated.xcconfig (flattened layout)..."
    sed -i '' "s|FLUTTER_ROOT=.*|FLUTTER_ROOT=/tmp/flutter|g" Flutter/Generated.xcconfig
    sed -i '' "s|FLUTTER_APPLICATION_PATH=.*|FLUTTER_APPLICATION_PATH=.|g" Flutter/Generated.xcconfig
    echo "✓ Patched: FLUTTER_APPLICATION_PATH=."

    # Mirror Flutter/ into ios/Flutter/ so xcode_backend.sh finds AppFrameworkInfo.plist
    # at the expected path: ./ios/Flutter/AppFrameworkInfo.plist
    echo "▶️ Mirroring Flutter/ → ios/Flutter/ for flattened layout..."
    mkdir -p ios/Flutter
    cp -R Flutter/. ios/Flutter/
    echo "✓ Flutter/ contents copied to ios/Flutter/"

elif [ -f ios/Flutter/Generated.xcconfig ]; then
    echo "▶️ Patching ios/Flutter/Generated.xcconfig (standard layout)..."
    sed -i '' "s|FLUTTER_ROOT=.*|FLUTTER_ROOT=/tmp/flutter|g" ios/Flutter/Generated.xcconfig
    sed -i '' "s|FLUTTER_APPLICATION_PATH=.*|FLUTTER_APPLICATION_PATH=..|g" ios/Flutter/Generated.xcconfig
    echo "✓ Patched: FLUTTER_APPLICATION_PATH=.."
fi

# Show the patched config for debugging
echo "▶️ Generated.xcconfig contents:"
cat Flutter/Generated.xcconfig 2>/dev/null || cat ios/Flutter/Generated.xcconfig 2>/dev/null || echo "(not found)"

echo "▶️ Verifying AppFrameworkInfo.plist is reachable..."
ls ios/Flutter/AppFrameworkInfo.plist 2>/dev/null && echo "✓ AppFrameworkInfo.plist found" || echo "❌ MISSING: ios/Flutter/AppFrameworkInfo.plist"

# Verify assets directory to satisfy pubspec.yaml
if [ -d assets/images ]; then
    echo "✓ Found assets directory: $(ls assets/images | head -n 3)..."
else
    echo "▶️ Creating missing assets directory..."
    mkdir -p assets/images
fi

echo "▶️ Installing CocoaPods dependencies..."
# In standard Flutter layout, Podfile is inside ios/.
# In Xcode Cloud flattened layout, Podfile is at the repo root.
# Check for Podfile explicitly rather than checking if ios/ dir exists 
# (ios/ may exist now after we created it for the Flutter mirror above).
if [ -f ios/Podfile ]; then
    echo "▶️ Changing to ios directory (Podfile found there)..."
    cd ios
elif [ -f Podfile ]; then
    echo "✓ Podfile found in current directory (flattened layout), staying here."
else
    echo "❌ Error: Could not find Podfile in ios/ or current directory!"
    exit 1
fi

echo "▶️ Working directory for pod install: $(pwd)"
echo "▶️ Checking for .flutter-plugins-dependencies..."
ls -la ../.flutter-plugins-dependencies 2>/dev/null && echo "✓ Found in parent dir" || \
    ls -la .flutter-plugins-dependencies 2>/dev/null && echo "✓ Found in current dir" || \
    echo "❌ .flutter-plugins-dependencies NOT FOUND"

# Update CocoaPods repo to ensure fresh podspecs
echo "▶️ Updating CocoaPods repositories..."
pod repo update --silent 2>/dev/null || true

# Run pod install with repo-update flag to ensure fresh module specs
echo "▶️ Installing pods..."
pod install --repo-update

echo "✅ CI Post Clone Complete!"