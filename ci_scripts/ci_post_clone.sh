#!/bin/sh
set -e

echo "▶️ Setting up Flutter for Xcode Cloud..."

# Install Homebrew non-interactively
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH (Apple Silicon path on Xcode Cloud)
export PATH="/opt/homebrew/bin:$PATH"

# Install Flutter
brew install --quiet flutter

# Verify flutter
flutter --version

# Go to repo root (ci_scripts is inside ios/, so go up two levels)
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Get packages — this generates Flutter/Generated.xcconfig
flutter pub get

# Install pods
cd ios
pod install --repo-update