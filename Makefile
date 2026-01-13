# KBounce Build Makefile
#
# Required environment variables (set in .env, run: source .env):
#   GODOT - Path to Godot executable
#   TEAM_ID - Apple Developer Team ID
#   MAC_APP_IDENTITY - Apple Distribution signing identity
#   MAC_DEV_IDENTITY - Apple Development signing identity
#   MAC_INSTALLER_IDENTITY - Mac installer signing identity
#   LEADERBOARD_API_URL - Leaderboard API base URL

# Configuration
APP_NAME := KBounce
BUNDLE_ID := app.kbounce
GODOT ?= godot

# Version: use git describe, allow override via VERSION env var for CI
# CI usage: make web VERSION=${{ github.ref_name }}
VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo "dev")
APPLE_VERSION := $(patsubst v%,%,$(VERSION))
VERSION_FILE := scripts/version.gd
CONFIG_FILE := scripts/config.gd
EXPORT_PRESETS := export_presets.cfg

# Directories
EXPORT_DIR := ../export
MAC_DIR := $(EXPORT_DIR)/mac
IOS_DIR := $(EXPORT_DIR)/ios
WEB_DIR := build

# Output files
MAC_APP := $(MAC_DIR)/$(APP_NAME).app
MAC_PKG := $(MAC_DIR)/$(APP_NAME).pkg
IOS_XCODEPROJ := $(IOS_DIR)/$(APP_NAME).xcodeproj
IOS_ARCHIVE := $(IOS_DIR)/$(APP_NAME).xcarchive
IOS_IPA := $(IOS_DIR)/$(APP_NAME).ipa

# Provisioning
MAC_PROVISIONING_PROFILE := provisioning/mac.provisionprofile

# App Store Connect API credentials (loaded from credentials.mk)
# Create credentials.mk with:
#   API_KEY_ID := your_key_id
#   API_ISSUER_ID := your_issuer_id
# Place .p8 key in ~/.private_keys/AuthKey_<API_KEY_ID>.p8
-include credentials.mk

.PHONY: all test mac mac-dev mac-pkg mac-upload mac-transporter ios ios-dev ios-sim ios-archive ios-xcode ios-ipa ios-upload ios-transporter web clean help version config export-presets verify-mac check-certs icons iphone-screenshots ipad-screenshots mac-screenshots

help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: mac ios web ## Build all platforms

test: ## Run unit tests
	$(GODOT) --headless --script tests/test_runner.gd

$(VERSION_FILE): version ;

version:
	@mkdir -p $(dir $(VERSION_FILE))
	@echo 'class_name Version' > $(VERSION_FILE).tmp
	@echo 'const TAG = "$(VERSION)"' >> $(VERSION_FILE).tmp
	@if ! cmp -s $(VERSION_FILE).tmp $(VERSION_FILE); then \
		echo "==> Updating version file ($(VERSION))..."; \
		mv $(VERSION_FILE).tmp $(VERSION_FILE); \
	else \
		rm $(VERSION_FILE).tmp; \
	fi

$(CONFIG_FILE): config ;

config:
	@mkdir -p $(dir $(CONFIG_FILE))
	@echo 'class_name Config' > $(CONFIG_FILE).tmp
	@echo 'const LEADERBOARD_API_URL = "$(LEADERBOARD_API_URL)"' >> $(CONFIG_FILE).tmp
	@if ! cmp -s $(CONFIG_FILE).tmp $(CONFIG_FILE); then \
		echo "==> Updating config file..."; \
		mv $(CONFIG_FILE).tmp $(CONFIG_FILE); \
	else \
		rm $(CONFIG_FILE).tmp; \
	fi

$(EXPORT_PRESETS): export-presets ;

export-presets:
	@envsubst < $(EXPORT_PRESETS).template > $(EXPORT_PRESETS).tmp
	@if ! cmp -s $(EXPORT_PRESETS).tmp $(EXPORT_PRESETS); then \
		echo "==> Updating export presets..."; \
		mv $(EXPORT_PRESETS).tmp $(EXPORT_PRESETS); \
	else \
		rm $(EXPORT_PRESETS).tmp; \
	fi

# macOS targets
mac: $(MAC_APP) ## Export macOS app

$(MAC_APP): $(VERSION_FILE) $(CONFIG_FILE) $(EXPORT_PRESETS)
	@echo "==> Exporting macOS app..."
	@mkdir -p $(MAC_DIR)
	$(GODOT) --headless --export-release "macOS" $(MAC_APP)
	@echo "==> Extracting entitlements..."
	@codesign -d --entitlements - --xml $(MAC_APP) > $(MAC_DIR)/entitlements.plist
	@/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $(TEAM_ID).$(BUNDLE_ID)" $(MAC_DIR)/entitlements.plist
	@/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $(TEAM_ID)" $(MAC_DIR)/entitlements.plist
	@echo "==> Patching version to $(APPLE_VERSION)..."
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(APPLE_VERSION)" $(MAC_APP)/Contents/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(APPLE_VERSION)" $(MAC_APP)/Contents/Info.plist
	@/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 11.0" $(MAC_APP)/Contents/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 11.0" $(MAC_APP)/Contents/Info.plist
	@echo "==> Embedding provisioning profile..."
	@cp $(MAC_PROVISIONING_PROFILE) $(MAC_APP)/Contents/embedded.provisionprofile
	@echo "==> Re-signing app after modifications..."
	codesign --force --options runtime --entitlements $(MAC_DIR)/entitlements.plist \
		--sign "$(MAC_APP_IDENTITY)" $(MAC_APP)
	@echo "==> Verifying code signature..."
	codesign -dv --verbose=2 $(MAC_APP)
	@echo "==> macOS app exported to $(MAC_APP)"

mac-dev: $(VERSION_FILE) $(CONFIG_FILE) $(EXPORT_PRESETS) ## Export macOS app for local development
	@echo "==> Exporting macOS dev app..."
	@mkdir -p $(MAC_DIR)
	@rm -rf $(MAC_APP)
	$(GODOT) --headless --export-release "macOS" $(MAC_APP)
	@echo "==> Extracting entitlements..."
	@codesign -d --entitlements - --xml $(MAC_APP) > $(MAC_DIR)/entitlements-dev.plist
	@echo "==> Patching version to $(APPLE_VERSION)..."
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(APPLE_VERSION)" $(MAC_APP)/Contents/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(APPLE_VERSION)" $(MAC_APP)/Contents/Info.plist
	@echo "==> Re-signing with development identity..."
	codesign --force --options runtime --entitlements $(MAC_DIR)/entitlements-dev.plist \
		--sign "$(MAC_DEV_IDENTITY)" $(MAC_APP)
	@echo "==> macOS dev app exported to $(MAC_APP)"

mac-pkg: $(MAC_PKG) ## Create macOS installer package (.pkg)

$(MAC_PKG): $(MAC_APP)
	@echo "==> Creating macOS installer package..."
	productbuild \
		--component $(MAC_APP) /Applications \
		--sign "$(MAC_INSTALLER_IDENTITY)" \
		$(MAC_PKG)
	@echo "==> Validating package..."
	xcrun altool --validate-app -f $(MAC_PKG) -t macos --apiKey $(API_KEY_ID) --apiIssuer $(API_ISSUER_ID) || true
	@echo "==> macOS package created: $(MAC_PKG)"

mac-upload: $(MAC_PKG) ## Upload to Mac App Store Connect
	@echo "==> Uploading to Mac App Store Connect..."
	xcrun altool --upload-app -f $(MAC_PKG) -t macos --apiKey $(API_KEY_ID) --apiIssuer $(API_ISSUER_ID)
	@echo "==> Upload complete!"

mac-transporter: $(MAC_PKG) ## Open PKG in Transporter
	@echo "==> Opening PKG in Transporter..."
	open -a Transporter $(MAC_PKG)

# iOS targets
ios: $(IOS_XCODEPROJ) ## Export iOS Xcode project

$(IOS_XCODEPROJ): $(VERSION_FILE) $(CONFIG_FILE) $(EXPORT_PRESETS)
	@echo "==> Exporting iOS Xcode project..."
	@mkdir -p $(IOS_DIR)
	$(GODOT) --headless --export-release "iOS" $(IOS_DIR)/$(APP_NAME)
	@echo "==> Xcode project exported to $(IOS_XCODEPROJ)"

ios-dev: $(IOS_XCODEPROJ) ## Patch iOS project for real device development
	@echo "==> Patching Xcode project for device development..."
	@sed -i '' 's/"Apple Distribution"/"Apple Development"/g' $(IOS_XCODEPROJ)/project.pbxproj
	@echo "==> iOS project patched. Open $(IOS_XCODEPROJ) in Xcode."

ios-sim: $(IOS_XCODEPROJ) ## Patch iOS project for simulator (x86_64 via Rosetta)
	@echo "==> Patching Xcode project for simulator..."
	@sed -i '' 's/"Apple Distribution"/"Apple Development"/g' $(IOS_XCODEPROJ)/project.pbxproj
	@perl -i -pe 's/ARCHS = "arm64";/ARCHS = "arm64 x86_64";/' $(IOS_XCODEPROJ)/project.pbxproj
	@perl -i -pe 's/(ARCHS = "arm64 x86_64";)/$$1\n\t\t\t\t"EXCLUDED_ARCHS[sdk=iphonesimulator*]" = arm64;\n\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";/' $(IOS_XCODEPROJ)/project.pbxproj
	@echo "==> iOS project patched. Open $(IOS_XCODEPROJ) in Xcode."
	@echo "==> NOTE: Use iOS 18.x runtime (Rosetta) and show both architectures."

ios-archive: $(IOS_XCODEPROJ) ## Build iOS archive
	@echo "==> Patching Xcode project for automatic signing..."
	@sed -i '' 's/"Apple Distribution"/"Apple Development"/g' $(IOS_XCODEPROJ)/project.pbxproj
	@echo "==> Patching version to $(APPLE_VERSION)..."
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(APPLE_VERSION)" $(IOS_DIR)/$(APP_NAME)/$(APP_NAME)-Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(APPLE_VERSION)" $(IOS_DIR)/$(APP_NAME)/$(APP_NAME)-Info.plist
	@echo "==> Building iOS archive..."
	xcodebuild -project $(IOS_XCODEPROJ) -scheme $(APP_NAME) \
		-configuration Release -archivePath $(IOS_ARCHIVE) \
		-allowProvisioningUpdates archive
	@echo "==> Archive created: $(IOS_ARCHIVE)"

ios-xcode: ios-archive ## Build archive and open in Xcode
	@echo "==> Opening archive in Xcode..."
	open $(IOS_ARCHIVE)

ios-ipa: ios-archive ## Export iOS IPA
	@echo "==> Exporting IPA..."
	xcodebuild -exportArchive -archivePath $(IOS_ARCHIVE) \
		-exportOptionsPlist export_options.plist \
		-exportPath $(IOS_DIR) -allowProvisioningUpdates
	@echo "==> IPA exported to $(IOS_DIR)"

ios-upload: ios-ipa ## Upload to iOS App Store Connect
	@echo "==> Uploading to iOS App Store Connect..."
	xcrun altool --upload-app -f $(IOS_IPA) -t ios --apiKey $(API_KEY_ID) --apiIssuer $(API_ISSUER_ID)
	@echo "==> Upload complete!"

ios-transporter: ios-ipa ## Open IPA in Transporter
	@echo "==> Opening IPA in Transporter..."
	open -a Transporter $(IOS_IPA)

# Web target
web: $(VERSION_FILE) $(CONFIG_FILE) ## Export web build
	@echo "==> Exporting web build..."
	@mkdir -p $(WEB_DIR)
	$(GODOT) --headless --export-release "Web" $(WEB_DIR)/kbounce.html
	@echo "==> Web build exported to $(WEB_DIR)/"

# Clean
clean: ## Remove build artifacts
	@echo "==> Cleaning build artifacts..."
	rm -rf $(MAC_DIR)
	rm -rf $(IOS_DIR)
	rm -rf $(WEB_DIR)/*.html $(WEB_DIR)/*.js $(WEB_DIR)/*.wasm $(WEB_DIR)/*.pck
	rm -f $(VERSION_FILE) $(CONFIG_FILE)
	@echo "==> Clean complete"

# Icon generation
ICON_SRC := icon-grey-1024.png
IOS_ICON_SIZES := 20 29 40 58 60 76 80 87 120 152 167 180 1024

icons: ## Generate iOS icons and macOS icns from grey source
	@echo "==> Generating iOS icons from $(ICON_SRC)..."
	@mkdir -p ios_icons
	@for size in $(IOS_ICON_SIZES); do \
		sips -z $$size $$size $(ICON_SRC) --out ios_icons/icon-$$size.png >/dev/null; \
	done
	@echo "==> Generating macOS icns..."
	@mkdir -p icon.iconset
	@sips -z 16 16 $(ICON_SRC) --out icon.iconset/icon_16x16.png >/dev/null
	@sips -z 32 32 $(ICON_SRC) --out icon.iconset/icon_16x16@2x.png >/dev/null
	@sips -z 32 32 $(ICON_SRC) --out icon.iconset/icon_32x32.png >/dev/null
	@sips -z 64 64 $(ICON_SRC) --out icon.iconset/icon_32x32@2x.png >/dev/null
	@sips -z 128 128 $(ICON_SRC) --out icon.iconset/icon_128x128.png >/dev/null
	@sips -z 256 256 $(ICON_SRC) --out icon.iconset/icon_128x128@2x.png >/dev/null
	@sips -z 256 256 $(ICON_SRC) --out icon.iconset/icon_256x256.png >/dev/null
	@sips -z 512 512 $(ICON_SRC) --out icon.iconset/icon_256x256@2x.png >/dev/null
	@sips -z 512 512 $(ICON_SRC) --out icon.iconset/icon_512x512.png >/dev/null
	@sips -z 1024 1024 $(ICON_SRC) --out icon.iconset/icon_512x512@2x.png >/dev/null
	@iconutil -c icns icon.iconset -o icon.icns
	@rm -rf icon.iconset
	@echo "==> Icons generated"

# Screenshot processing
IPHONE_SCREENSHOT_SIZE := 2778x1284
IPAD_SCREENSHOT_SIZE := 2732x2048

iphone-screenshots: ## Resize screenshots for iPhone App Store (2778x1284)
	@echo "==> Resizing iPhone screenshots..."
	@mkdir -p $(EXPORT_DIR)/screenshots/iphone/output
	@i=1; for f in $(EXPORT_DIR)/screenshots/iphone/input/*.png; do \
		magick "$$f" -resize $(IPHONE_SCREENSHOT_SIZE)! -alpha off $(EXPORT_DIR)/screenshots/iphone/output/screenshot-$$i.png; \
		echo "  $$f -> screenshot-$$i.png"; \
		i=$$((i+1)); \
	done
	@echo "==> Screenshots resized to $(IPHONE_SCREENSHOT_SIZE)"

ipad-screenshots: ## Resize screenshots for iPad App Store (2732x2048)
	@echo "==> Resizing iPad screenshots..."
	@mkdir -p $(EXPORT_DIR)/screenshots/ipad/output
	@i=1; for f in $(EXPORT_DIR)/screenshots/ipad/input/*.png; do \
		magick "$$f" -resize $(IPAD_SCREENSHOT_SIZE)! -alpha off $(EXPORT_DIR)/screenshots/ipad/output/screenshot-$$i.png; \
		echo "  $$f -> screenshot-$$i.png"; \
		i=$$((i+1)); \
	done
	@echo "==> Screenshots resized to $(IPAD_SCREENSHOT_SIZE)"

MAC_SCREENSHOT_SIZE := 2880x1800

mac-screenshots: ## Resize screenshots for Mac App Store (2880x1800, crops 64px menu)
	@echo "==> Resizing Mac screenshots..."
	@mkdir -p $(EXPORT_DIR)/screenshots/mac/output
	@i=1; for f in $(EXPORT_DIR)/screenshots/mac/input/*.png; do \
		magick "$$f" -crop +0+64 -resize $(MAC_SCREENSHOT_SIZE)! -alpha off $(EXPORT_DIR)/screenshots/mac/output/screenshot-$$i.png; \
		echo "  $$f -> screenshot-$$i.png"; \
		i=$$((i+1)); \
	done
	@echo "==> Screenshots resized to $(MAC_SCREENSHOT_SIZE)"

# Utility targets
verify-mac: ## Verify macOS app signature
	@echo "==> Verifying macOS app signature..."
	codesign -dv --verbose=4 $(MAC_APP)
	@echo "==> Checking entitlements..."
	codesign -d --entitlements - $(MAC_APP)

check-certs: ## List available signing identities
	@echo "==> Available signing identities:"
	security find-identity -v -p codesigning
	@echo ""
	@echo "==> Installer identities:"
	security find-identity -v | grep "Installer"
