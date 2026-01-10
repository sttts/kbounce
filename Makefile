# KBounce Build Makefile
#
# Usage:
#   make mac          - Export macOS app
#   make mac-pkg      - Create macOS installer package
#   make mac-upload   - Upload to Mac App Store
#   make ios          - Export iOS app
#   make ios-upload   - Upload to iOS App Store
#   make web          - Export web build
#   make all          - Build all platforms
#   make clean        - Remove build artifacts

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

# App Store Connect credentials (use app-specific password stored in keychain)
# Store with: xcrun notarytool store-credentials "AC_PASSWORD" --apple-id "your@email.com" --team-id "TEAM_ID"
ASC_CREDENTIALS := AC_PASSWORD

.PHONY: all mac mac-pkg mac-upload ios ios-archive ios-ipa ios-upload web clean help version

help:
	@echo "KBounce Build Targets:"
	@echo "  make mac          - Export macOS app"
	@echo "  make mac-pkg      - Create macOS installer package (.pkg)"
	@echo "  make mac-upload   - Upload to Mac App Store Connect"
	@echo "  make ios          - Export iOS app"
	@echo "  make ios-upload   - Upload to iOS App Store Connect"
	@echo "  make web          - Export web build"
	@echo "  make all          - Build all platforms"
	@echo "  make clean        - Remove build artifacts"

all: mac ios web

# Version file generation (always regenerated)
version:
	@echo "==> Generating version file ($(VERSION))..."
	@mkdir -p $(dir $(VERSION_FILE))
	@echo 'class_name Version' > $(VERSION_FILE)
	@echo 'const TAG = "$(VERSION)"' >> $(VERSION_FILE)

# macOS targets
mac: version $(MAC_APP)

$(MAC_APP):
	@echo "==> Exporting macOS app..."
	@mkdir -p $(MAC_DIR)
	$(GODOT) --headless --export-release "macOS" $(MAC_APP)
	@echo "==> Verifying code signature..."
	codesign -dv --verbose=2 $(MAC_APP)
	@echo "==> macOS app exported to $(MAC_APP)"

mac-pkg: $(MAC_PKG)

$(MAC_PKG): $(MAC_APP)
	@echo "==> Creating macOS installer package..."
	productbuild \
		--component $(MAC_APP) /Applications \
		--sign "$(MAC_INSTALLER_IDENTITY)" \
		$(MAC_PKG)
	@echo "==> Validating package..."
	xcrun altool --validate-app -f $(MAC_PKG) -t macos --apiKey $(ASC_CREDENTIALS) || true
	@echo "==> macOS package created: $(MAC_PKG)"

mac-upload: $(MAC_PKG)
	@echo "==> Uploading to Mac App Store Connect..."
	xcrun altool --upload-app -f $(MAC_PKG) -t macos --apiKey $(ASC_CREDENTIALS)
	@echo "==> Upload complete!"

# iOS targets
ios: version $(IOS_XCODEPROJ)

$(IOS_XCODEPROJ):
	@echo "==> Exporting iOS Xcode project..."
	@mkdir -p $(IOS_DIR)
	$(GODOT) --headless --export-release "iOS" $(IOS_DIR)/$(APP_NAME)
	@echo "==> Xcode project exported to $(IOS_XCODEPROJ)"

ios-archive: $(IOS_XCODEPROJ)
	@echo "==> Building iOS archive..."
	xcodebuild -project $(IOS_XCODEPROJ) -scheme $(APP_NAME) \
		-configuration Release -archivePath $(IOS_ARCHIVE) \
		-allowProvisioningUpdates archive
	@echo "==> Archive created: $(IOS_ARCHIVE)"

ios-ipa: $(IOS_ARCHIVE)
	@echo "==> Exporting IPA..."
	xcodebuild -exportArchive -archivePath $(IOS_ARCHIVE) \
		-exportOptionsPlist export_options.plist \
		-exportPath $(IOS_DIR) -allowProvisioningUpdates
	@echo "==> IPA exported to $(IOS_DIR)"

ios-upload: ios-ipa
	@echo "==> Uploading to iOS App Store Connect..."
	xcrun altool --upload-app -f $(IOS_IPA) -t ios --apiKey $(ASC_CREDENTIALS)
	@echo "==> Upload complete!"

# Web target
web: version
	@echo "==> Exporting web build..."
	@mkdir -p $(WEB_DIR)
	$(GODOT) --headless --export-release "Web" $(WEB_DIR)/kbounce.html
	@echo "==> Web build exported to $(WEB_DIR)/"

# Clean
clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(MAC_DIR)
	rm -rf $(IOS_DIR)
	rm -rf $(WEB_DIR)/*.html $(WEB_DIR)/*.js $(WEB_DIR)/*.wasm $(WEB_DIR)/*.pck
	rm -f $(VERSION_FILE)
	@echo "==> Clean complete"

# Utility targets
verify-mac:
	@echo "==> Verifying macOS app signature..."
	codesign -dv --verbose=4 $(MAC_APP)
	@echo "==> Checking entitlements..."
	codesign -d --entitlements - $(MAC_APP)

check-certs:
	@echo "==> Available signing identities:"
	security find-identity -v -p codesigning
	@echo ""
	@echo "==> Installer identities:"
	security find-identity -v | grep "Installer"
