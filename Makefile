.DEFAULT_GOAL := build
UPX := $(shell upx --version 2>/dev/null)

.PHONY: clean build

clean:
	@rm -f .build/release
	@rm -rf .build/x86_64-apple-macosx
	@rm -rf .build/arm64-apple-macosx

build: clean
	@swift build -c release --arch x86_64
	@swift build -c release --arch arm64
ifdef UPX
	@upx .build/x86_64-apple-macosx/release/zoom-chat-publisher \
	-o .build/x86_64-apple-macosx/release/zoom-chat-publisher-smol
	@upx --brute .build/x86_64-apple-macosx/release/zoom-chat-publisher \
	-o .build/x86_64-apple-macosx/release/zoom-chat-publisher-smoler
else
	@echo "Skipping UPX compression. To enable compression: brew install upx"
endif

