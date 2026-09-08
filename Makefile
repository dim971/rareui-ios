SIMULATOR ?= iPhone 17 Pro
DERIVED := .build/showcase
PROJECT := Showcase/RareUIShowcase.xcodeproj

.PHONY: test build lint format showcase project clean

test:
	swift test

build:
	swift build

lint:
	swiftformat --lint .
	swiftlint lint --quiet

format:
	swiftformat .

project:
	cd Showcase && xcodegen generate

showcase: project
	xcodebuild -project $(PROJECT) -scheme RareUIShowcase \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-derivedDataPath $(DERIVED) build
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	xcrun simctl install booted "$(DERIVED)/Build/Products/Debug-iphonesimulator/RareUIShowcase.app"
	xcrun simctl launch booted io.github.dim971.rareui.showcase

clean:
	rm -rf .build Showcase/RareUIShowcase.xcodeproj
