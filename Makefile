CC = clang
CFLAGS = -O2 -Wall -Wextra -fobjc-arc
PREFIX ?= $(HOME)/.local
LAUNCH_AGENTS_DIR ?= $(HOME)/Library/LaunchAgents
LAUNCH_AGENT = $(LAUNCH_AGENTS_DIR)/net.malensek.dockhop.plist

dockhop: main.m
	$(CC) $(CFLAGS) main.m -o $@ -framework AppKit -framework Carbon

install: dockhop
	install -d "$(PREFIX)/bin"
	install -m 755 dockhop "$(PREFIX)/bin/dockhop"

install-launchagent: install
	install -d "$(LAUNCH_AGENTS_DIR)"
	install -m 644 net.malensek.dockhop.plist "$(LAUNCH_AGENT)"
	plutil -insert ProgramArguments.0 -string "$$(cd "$(PREFIX)" && pwd)/bin/dockhop" "$(LAUNCH_AGENT)"

remove-launchagent:
	@if launchctl print "gui/$$(id -u)/net.malensek.dockhop" >/dev/null 2>&1; then \
		launchctl bootout "gui/$$(id -u)/net.malensek.dockhop" || exit $$?; \
	fi
	rm -f "$(LAUNCH_AGENT)"

clean:
	rm -f dockhop

.PHONY: clean install install-launchagent remove-launchagent
