PREFIX ?= /usr/local
SYSCONFDIR ?= /etc

.PHONY: build man install uninstall test clean

build:
	python3 -m py_compile snooze

# gzip -n: no embedded filename/timestamp, so the compressed man page is
# byte-identical across rebuilds (matches Debian's reproducible-builds and
# lintian's manpage-not-compressed-with-max-compression expectations).
man:
	mkdir -p target/man
	gzip -9 -n -c packaging/snooze.1 > target/man/snooze.1.gz

install: man
	install -Dm755 snooze $(DESTDIR)$(PREFIX)/sbin/snooze
	install -Dm644 target/man/snooze.1.gz $(DESTDIR)$(PREFIX)/share/man/man1/snooze.1.gz
	install -Dm644 etc/bash_completion.d/snooze $(DESTDIR)$(PREFIX)/share/bash-completion/completions/snooze
	install -Dm644 etc/snooze.conf.example $(DESTDIR)$(SYSCONFDIR)/snooze.conf.example

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/sbin/snooze
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/snooze.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/bash-completion/completions/snooze
	rm -f $(DESTDIR)$(SYSCONFDIR)/snooze.conf.example

test: build

clean:
	rm -rf target __pycache__
