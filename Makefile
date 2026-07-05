# Bitpack OS Pro - Source-tree style installer

PREFIX_ROOT ?=

.PHONY: all install
all:
	@echo "Use 'make install PREFIX_ROOT=<root> ' to install Bitpack components"

install:
	@if [ -z "$(PREFIX_ROOT)" ]; then \
		echo "PREFIX_ROOT is required"; \
		exit 1; \
	fi

	# Ensure target dirs
	mkdir -p "$(PREFIX_ROOT)/usr/bin" \
		"$(PREFIX_ROOT)/usr/local/bin" \
		"$(PREFIX_ROOT)/usr/local/bitpack" \
		"$(PREFIX_ROOT)/usr/share/applications" \
		"$(PREFIX_ROOT)/usr/share/backgrounds" \
		"$(PREFIX_ROOT)/etc/bitpack"

	# BPSH tool
	install -m 0755 src/bin/bp/main.sh "$(PREFIX_ROOT)/usr/bin/bp"

	# Settings app
	install -m 0755 src/usr.sbin/bitpack-admin/main.py "$(PREFIX_ROOT)/usr/local/bin/bitpack-settings"

	# Desktop entry
	install -m 0644 src/share/applications/bitpack-settings.desktop "$(PREFIX_ROOT)/usr/share/applications/bitpack-settings.desktop"

	# System defaults / wallpapers placeholder
	if [ -f src/etc/bitpack/defaults ]; then \
		install -m 0644 src/etc/bitpack/defaults "$(PREFIX_ROOT)/etc/bitpack/defaults"; \
	fi


