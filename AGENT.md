# Copilot Agent Workflow for LexiCards

## Build & Test Gate (Pre-push)

Before pushing any code, run the full verification suite locally. These are the
same three commands `.github/workflows/ci.yml` runs, in the same order, so a
green local run and a green pipeline mean the same thing:

```bash
make lint   # swift-format, strict — fails on any finding
make test   # Swift Testing suite
make build  # Release configuration
```

`make build` is the one that matters most, and it builds **Release** on purpose.

## Why Release Build Matters

A past CI failure was a Swift compiler optimizer crash (`EarlyPerfInliner` on
`MovableHostingView.deinit`) that only appears in Release builds. Debug builds
passed, so a Debug-only gate would have let it through.

The CI workflow builds Release on every push and pull request, so this class of
failure is now caught on `master` rather than at release time.

## Formatting

Formatting is Apple's `swift-format`, configured in `.swift-format`. It ships
with the Xcode toolchain — there is nothing to install, and no separately
versioned formatter that can drift against CI. Use `make format` to apply and
`make lint` to check.

## Releasing

Releases are tag-driven (`v*`). `.github/workflows/release.yml` verifies the tag
matches `MARKETING_VERSION` before building, so a mistyped tag fails the release
instead of publishing an asset the Homebrew cask cannot resolve. `make release`
packages `dist/LexiCards-<version>.zip`, named from the version inside the built
bundle.

See DEVELOPMENT.org for the full pre-push checklist and architecture notes.
