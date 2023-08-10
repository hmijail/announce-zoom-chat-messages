.DEFAULT_GOAL := build

.PHONY: build
build:
	@swift build -c release --arch x86_64
	@swift build -c release --arch arm64

