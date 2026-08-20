# Copilot Agent Workflow for LexiCards

## Build & Test Gate (Pre-push)

Before pushing any code, run the full verification suite locally to catch compiler errors and optimizer crashes that may not surface until Release builds:

```bash
# 1. Check formatting
swiftformat LexiCards LexiCardsTests --lint

# 2. Run tests (Debug)
xcodebuild \
  -project LexiCards.xcodeproj \
  -scheme LexiCards \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test

# 3. Build Debug
xcodebuild \
  -project LexiCards.xcodeproj \
  -scheme LexiCards \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

# 4. Build Release (CRITICAL: catches optimizer crashes)
xcodebuild \
  -project LexiCards.xcodeproj \
  -scheme LexiCards \
  -configuration Release \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Why Release Build Matters

Recent CI failure was a Swift compiler optimizer crash (`EarlyPerfInliner` on `MovableHostingView.deinit`) that only appears in Release builds. Debug builds passed, so CI caught what local Debug testing missed.

**Always include Release build in local verification.**

See DEVELOPMENT.org for full pre-push checklist.
