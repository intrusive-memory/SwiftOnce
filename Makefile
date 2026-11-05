# SwiftOnce Makefile
# ElevenLabs API client package.

SCHEME = SwiftOnce-Package
DESTINATION = platform=macOS,arch=arm64
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
XCFLAGS = -skipPackagePluginValidation -skipMacroValidation

.PHONY: all build test test-integration resolve clean help

all: build

# Resolve all SPM package dependencies via xcodebuild
resolve:
	xcodebuild -resolvePackageDependencies -scheme $(SCHEME) -destination '$(DESTINATION)' $(XCFLAGS)
	@echo "Package dependencies resolved."

# Library build via xcodebuild
build: resolve
	xcodebuild build -scheme $(SCHEME) -destination '$(DESTINATION)' $(XCFLAGS)
	@echo "Build complete."

# Unit tests only (never makes live ElevenLabs calls)
test: resolve
	xcodebuild test -scheme $(SCHEME) -destination '$(DESTINATION)' $(XCFLAGS) -only-testing:SwiftOnceTests

# Integration tests (live calls; requires ELEVENLABS_API_KEY)
test-integration: resolve
	xcodebuild test -scheme $(SCHEME) -destination '$(DESTINATION)' $(XCFLAGS) -only-testing:SwiftOnceIntegrationTests

# Clean build artifacts
clean:
	rm -rf .build
	rm -rf $(DERIVED_DATA)/SwiftOnce-*

help:
	@echo "SwiftOnce Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  resolve           - Resolve all SPM package dependencies"
	@echo "  build             - Library build with xcodebuild (default)"
	@echo "  test              - Run unit tests (SwiftOnceTests only)"
	@echo "  test-integration  - Run live integration tests (needs ELEVENLABS_API_KEY)"
	@echo "  clean             - Clean build artifacts"
	@echo "  help              - Show this help"
	@echo ""
	@echo "All builds use: -destination '$(DESTINATION)'"
