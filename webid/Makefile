.SUFFIXES:

.PHONY: run

usage:
	@echo "usage: make TARGET"
	@echo
	@echo "targets:"
	@echo "  run       - start the web server"

run:
	@carton exec 'plackup -E development -R lib --port 3000  bin/app.pl'
