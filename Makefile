VERSION ?= 0.1.0

.PHONY: build app clean test

build:
	swift build -c release

app:
	VERSION=$(VERSION) ./scripts/build-app.sh

test:
	swift test

clean:
	rm -rf build/
	swift package clean
