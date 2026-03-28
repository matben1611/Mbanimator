APP_NAME = Mbanimator
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
ICONSET = AppIcon.iconset

.PHONY: all build icon bundle run clean

all: bundle

build:
	swift build -c release

icon:
	swift scripts/create_icon.swift /tmp/icon_1024.png
	mkdir -p $(ICONSET)
	@for size in 16 32 128 256 512; do \
		sips -z $$size $$size /tmp/icon_1024.png --out "$(ICONSET)/icon_$${size}x$${size}.png" > /dev/null; \
		double=$$((size * 2)); \
		sips -z $$double $$double /tmp/icon_1024.png --out "$(ICONSET)/icon_$${size}x$${size}@2x.png" > /dev/null; \
	done
	iconutil -c icns $(ICONSET) -o AppIcon.icns
	rm -rf $(ICONSET)

bundle: build icon
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	@echo "Built: $(APP_BUNDLE)"

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf .build $(APP_BUNDLE) AppIcon.icns $(ICONSET)
