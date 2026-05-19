SHELL := /bin/zsh

.PHONY: test test-coverage lint format sonar-coverage

test:
	Scripts/test.sh

test-coverage:
	Scripts/test.sh --coverage

format:
	Scripts/swiftformat.sh

lint:
	Scripts/swiftformat.sh --lint
	Scripts/swiftlint.sh

sonar-coverage: test-coverage
	mkdir -p build/coverage
	Scripts/xccov_to_sonar_generic.sh \
		build/coverage/sonar-generic-coverage.xml \
		"$(PWD)" \
		build/test-results/VAEThumbnailKit.xcresult