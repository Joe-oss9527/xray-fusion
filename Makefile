SHELL := /usr/bin/env bash
SRC   := $(shell git ls-files '*.sh' 'bin/*' 'commands/*' 'lib/*' 'modules/**/*' 2>/dev/null)

.PHONY: lint test
lint:
	@shellcheck -S style -x $(SRC)

test:
	@bats -r tests
