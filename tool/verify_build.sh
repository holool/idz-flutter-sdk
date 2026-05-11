#!/bin/bash
set -e

echo "=== IDz Flutter SDK Build Verification ==="
echo ""

# Navigate to SDK root (parent of tool/)
cd "$(dirname "$0")/.."
SDK_ROOT="$(pwd)"

# Step 1: SDK analyze
echo "--- [1/4] Running flutter analyze on SDK... ---"
flutter analyze
echo ""

# Step 2: SDK tests
echo "--- [2/4] Running unit tests... ---"
flutter test
echo ""

# Step 3: Example app analyze
echo "--- [3/4] Running flutter analyze on example app... ---"
cd "$SDK_ROOT/example"
flutter analyze
echo ""

# Step 4: Example app build APK
echo "--- [4/4] Building example APK... ---"
flutter build apk --debug
echo ""

echo "=== Build Verification Complete ==="
