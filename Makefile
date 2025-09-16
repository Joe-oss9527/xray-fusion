SHELL := /usr/bin/env bash
SRC   := $(shell git ls-files '*.sh' 'bin/*' 'commands/*' 'lib/*' 'modules/**/*' 'services/**/*' 'plugins/**/*' 2>/dev/null)

.PHONY: lint fmt
lint:
	@shellcheck -S style -x $(SRC)

fmt:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt not found; see https://github.com/mvdan/sh"; exit 2; }
	@shfmt -i 2 -ci -sr -bn -ln=bash -w $(SRC)
	@echo "Formatted with shfmt"
