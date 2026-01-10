# KBounce Build Makefile

# Configuration
GODOT ?= godot
APP_NAME := KBounce
BUNDLE_ID := app.kbounce
TEAM_ID := QUY34Y5C3U

# Version: use git describe, allow override via VERSION env var for CI
# CI usage: make web VERSION=${{ github.ref_name }}
VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo "dev")
VERSION_FILE := scripts/version.gd

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

# Signing identities (adjust these to match your certificates)
MAC_APP_IDENTITY := 3rd Party Mac Developer Application: Stefan Schimanski ($(TEAM_ID))
MAC_INSTALLER_IDENTITY := 3rd Party Mac Developer Installer: Stefan Schimanski ($(TEAM_ID))

# App Store Connect API credentials (loaded from credentials.mk)
# Create credentials.mk with:
#   API_KEY_ID := your_key_id
#   API_ISSUER_ID := your_issuer_id
# Place .p8 key in ~/.private_keys/AuthKey_<API_KEY_ID>.p8
-include credentials.mk

.PHONY: all mac mac-pkg mac-upload mac-transporter ios ios-archive ios-ipa ios-upload ios-transporter web clean help version verify-mac check-certs

help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: mac ios web ## Build all platforms

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

# macOS targets
mac: $(MAC_APP) ## Export macOS app

$(MAC_APP): $(VERSION_FILE)
	@echo "==> Exporting macOS app..."
	@mkdir -p $(MAC_DIR)
	$(GODOT) --headless --export-release "macOS" $(MAC_APP)
	@echo "==> Verifying code signature..."
	codesign -dv --verbose=2 $(MAC_APP)
	@echo "==> macOS app exported to $(MAC_APP)"

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

$(IOS_XCODEPROJ): $(VERSION_FILE)
	@echo "==> Exporting iOS Xcode project..."
	@mkdir -p $(IOS_DIR)
	$(GODOT) --headless --export-release "iOS" $(IOS_DIR)/$(APP_NAME)
	@echo "==> Xcode project exported to $(IOS_XCODEPROJ)"

ios-archive: $(IOS_XCODEPROJ) ## Build iOS archive
	@echo "==> Patching Xcode project for automatic signing..."
	@sed -i '' 's/"Apple Distribution"/"Apple Development"/g' $(IOS_XCODEPROJ)/project.pbxproj
	@echo "==> Patching version to $(VERSION)..."
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(IOS_DIR)/$(APP_NAME)/$(APP_NAME)-Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" $(IOS_DIR)/$(APP_NAME)/$(APP_NAME)-Info.plist
	@echo "==> Building iOS archive..."
	xcodebuild -project $(IOS_XCODEPROJ) -scheme $(APP_NAME) \
		-configuration Release -archivePath $(IOS_ARCHIVE) \
		-allowProvisioningUpdates archive
	@echo "==> Archive created: $(IOS_ARCHIVE)"

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
web: $(VERSION_FILE) ## Export web build
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
	rm -f $(VERSION_FILE)
	@echo "==> Clean complete"

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
