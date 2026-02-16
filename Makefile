APP_NAME = Limiter
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: build run clean install uninstall

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"
	cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	@echo "Build complete: $(APP_BUNDLE)"

run: build
	open "$(APP_BUNDLE)"

install: build
	@pkill -f "$(APP_NAME).app" 2>/dev/null || true
	@sleep 1
	cp -r "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "Launching..."
	@open "$(INSTALL_DIR)/$(APP_BUNDLE)"

uninstall:
	@pkill -f "$(APP_NAME).app" 2>/dev/null || true
	@sleep 1
	rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "Uninstalled $(APP_NAME)"

clean:
	rm -rf .build "$(APP_BUNDLE)"
