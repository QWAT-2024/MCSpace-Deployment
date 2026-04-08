#!/bin/sh
set -e

echo "▶️ Flutter CI Setup Starting..."

# Use the Xcode Cloud repo path
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Download Flutter SDK directly (no Homebrew)
FLUTTER_VERSION="3.29.3"  # Change to your Flutter version
echo "▶️ Downloading Flutter $FLUTTER_VERSION..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch $FLUTTER_VERSION /tmp/flutter 2>/dev/null || \
git clone https://github.com/flutter/flutter.git --depth 1 --tag $FLUTTER_VERSION /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"

# Disable analytics
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true

echo "▶️ Flutter version:"
flutter --version

echo "▶️ Running flutter pub get..."
flutter pub get --no-example

echo "▶️ Installing CocoaPods dependencies..."
cd ios

# Update CocoaPods repo if needed
echo "▶️ Updating CocoaPods repositories..."
pod repo update --silent 2>/dev/null || true

# Run pod install with proper flags
echo "▶️ Installing pods..."
pod install

echo "✅ CI Post Clone Complete!"