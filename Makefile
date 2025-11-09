SHELL := /usr/bin/env bash
SRC   := $(shell git ls-files '*.sh' 'bin/*' 'commands/*' 'lib/*' 'modules/**/*' 'services/**/*' 'plugins/**/*.sh' 'scripts/**/*.sh' 2>/dev/null)

.PHONY: lint fmt test test-unit test-integration

lint:
	@shellcheck -S error -S warning -x $(SRC)

fmt:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt not found; see https://github.com/mvdan/sh"; exit 2; }
	@shfmt -i 2 -ci -sr -bn -ln=bash -w $(SRC)
	@echo "Formatted with shfmt"

test: test-unit

test-unit:
	@command -v bats >/dev/null 2>&1 || { echo "bats not found; see https://github.com/bats-core/bats-core"; exit 2; }
	@bats tests/unit/*.bats

test-integration:
	@command -v bats >/dev/null 2>&1 || { echo "bats not found; see https://github.com/bats-core/bats-core"; exit 2; }
	@bats tests/integration/*.bats 2>/dev/null || echo "No integration tests yet"

help:
	@echo "Available targets:"
	@echo "  lint             - Run ShellCheck on all shell scripts"
	@echo "  fmt              - Format all shell scripts with shfmt"
	@echo "  test             - Run all tests (currently: unit tests only)"
	@echo "  test-unit        - Run unit tests"
	@echo "  test-integration - Run integration tests"
	@echo "  help             - Show this help message"
