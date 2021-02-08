.SUFFIXES:

.PHONY: genkey

usage:
	@echo "usage: make TARGET"
	@echo
	@echo "targets:"
	@echo "  genkey"

genkey: keys/private.pem keys/public.pem

keys/private.pem:
	openssl genrsa -out keys/private.pem 2048

keys/public.pem: keys/private.pem
	openssl rsa -in keys/private.pem -outform PEM -pubout -out keys/public.pem
