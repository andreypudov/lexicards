APP        := LexiCards
CONFIG     := Release
APP_BUNDLE := build/$(CONFIG)/$(APP).app
DIST_DIR   := dist

# The certificate to sign with, by name. Empty keeps Xcode's own signing, so
# only a release has to have the certificate.
#
# A plain xcodebuild build adds get-task-allow, which lets a debugger attach, so
# a signed build re-signs the app without it. The entitlements are read back
# from the app rather than kept in a file, so the sandbox settings stay in one
# place. CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO is not a shortcut for this: it
# drops the sandbox entitlements too.
SIGN_IDENTITY ?=

# Use the full Xcode toolchain even when xcode-select points at the
# Command Line Tools.
ifneq (,$(findstring CommandLineTools,$(shell xcode-select -p)))
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
endif

.PHONY: build test format lint install release clean

build:
	xcodebuild -project $(APP).xcodeproj -target $(APP) -configuration $(CONFIG) build \
		$(if $(SIGN_IDENTITY),CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" DEVELOPMENT_TEAM=)
ifneq ($(SIGN_IDENTITY),)
	codesign -d --entitlements - --xml $(APP_BUNDLE) > build/release.entitlements
	/usr/libexec/PlistBuddy -c "Delete :com.apple.security.get-task-allow" build/release.entitlements || true
	codesign --force --sign "$(SIGN_IDENTITY)" --entitlements build/release.entitlements --timestamp=none $(APP_BUNDLE)
endif

# Apple's formatter, bundled with the toolchain — no install, no dependency.
# Configuration is in .swift-format.
format:
	xcrun swift-format format --in-place --recursive --configuration .swift-format $(APP) $(APP)Tests

# The same rules, reported rather than applied. Fails on any finding, so CI can
# gate on it.
lint:
	xcrun swift-format lint --strict --recursive --configuration .swift-format $(APP) $(APP)Tests

test:
	xcodebuild test -project $(APP).xcodeproj -scheme $(APP) -destination 'platform=macOS'

install: build
	rm -rf /Applications/$(APP).app
	ditto $(APP_BUNDLE) /Applications/$(APP).app
	@echo "Installed /Applications/$(APP).app"

release: build
	mkdir -p $(DIST_DIR)
	@version=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(APP_BUNDLE)/Contents/Info.plist); \
	ditto -c -k --sequesterRsrc --keepParent $(APP_BUNDLE) $(DIST_DIR)/$(APP)-$$version.zip; \
	echo "Created $(DIST_DIR)/$(APP)-$$version.zip"

clean:
	rm -rf build $(DIST_DIR)
