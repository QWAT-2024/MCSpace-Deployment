#!/bin/sh
set -e

echo "▶️ Flutter CI Setup Starting..."

# Use the Xcode Cloud repo path
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Download Flutter SDK directly (no Homebrew)
FLUTTER_VERSION="3.29.3"  # Change to your Flutter version
git clone https://github.com/flutter/flutter.git --depth 1 --branch $FLUTTER_VERSION /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"

echo "▶️ Flutter version:"
flutter --version --suppress-analytics

echo "▶️ Running flutter pub get..."
flutter pub get

echo "▶️ Installing CocoaPods dependencies..."
cd ios
pod install --repo-update

echo "✅ Done!"