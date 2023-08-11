.DEFAULT_GOAL := build
UPX := $(shell upx --version 2>/dev/null)

.PHONY: clean build

clean:
	@rm .build/release
	@rm -rf .build/x86_64-apple-macosx
	@rm -rf .build/arm64-apple-macosx

build: clean
	@swift build -c release --arch x86_64
	@swift build -c release --arch arm64
ifdef UPX
	@upx --ultra-brute .build/x86_64-apple-macosx/release/zoom-chat-event-publisher
else
	@echo "Skipping UPX compression. To enable compression: brew install upx"
endif

