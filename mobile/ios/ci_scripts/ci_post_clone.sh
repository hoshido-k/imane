#!/bin/sh

# Xcode Cloud post-clone script for Flutter
# This script runs after Xcode Cloud clones the repository

set -e

echo "=== Starting Flutter setup for Xcode Cloud ==="

# Navigate to the Flutter project root (one level up from ios/)
cd "$CI_PRIMARY_REPOSITORY_PATH/mobile"

# Install Flutter SDK
echo "Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# Verify Flutter installation
echo "Flutter version:"
flutter --version

# Precache iOS artifacts
echo "Precaching iOS artifacts..."
flutter precache --ios

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Generate Flutter build files (this creates Generated.xcconfig)
echo "Generating Flutter build files..."
flutter build ios --config-only --release --no-codesign

# Navigate to iOS directory
cd ios

# Install CocoaPods dependencies
echo "Installing CocoaPods dependencies..."
pod install --repo-update

echo "=== Flutter setup complete ==="
