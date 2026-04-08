#!/bin/sh

# Fail the script if any command fails
set -e

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Flutter using Homebrew
brew install flutter

# Go to project root
cd ../..

# Get Flutter packages (this generates Generated.xcconfig)
flutter pub get

# Install CocoaPods dependencies
cd ios
pod install