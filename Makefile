.PHONY: all test lint format

all: lint test

test:
	@for file in tests/*_spec.lua; do \
		echo "Running $$file..."; \
		nvim-pkms --headless -u scripts/init.lua -c "PlenaryBustedFile $$file" -c 'qa!'; \
	done

lint:
	luacheck -- lua/ plugin/ tests/

format:
	stylua -- lua/ plugin/ tests/
