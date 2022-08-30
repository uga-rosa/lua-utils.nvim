.PHONY: integration
integration: fmt luacheck vusted

.PHONY: fmt
fmt:
	./utils/stylua --config-path ./stylua.toml --glob 'lua/**/*.lua' -- lua

.PHONY: luacheck
luacheck:
	luacheck ./lua

.PHONY: vusted
vusted:
	vusted ./lua
