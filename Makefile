.PHONY: all test lint format

all: lint test

test:
	@for file in tests/*_spec.lua; do \
		echo "Running $$file..."; \
		nix run . -- --headless -u scripts/init.lua -c "PlenaryBustedFile $$file" -c 'qa!'; \
	done

lint:
	nix run .#luacheck -- lua/ plugin/ tests/

format:
	nix run .#stylua -- lua/ plugin/ tests/
