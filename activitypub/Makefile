.SUFFIXES:

.PHONY: genkey run inbox outbox followers following

usage:
	@echo "usage: make TARGET"
	@echo
	@echo "targets:"
	@echo "  genkey    - generate new private and public keys"
	@echo "  run       - start the web server"
	@echo "  inbox     - show the inbox contents"
	@echo "  output    - show the outbox contents"
	@echo "  followers - show the followes contents"
	@echo "  following - show the following contents"

run:
	@carton exec 'plackup -E development -R lib --port 3000  bin/app.pl'

inbox:
	@carton exec 'catmandu export inbox to YAML'

output:
	@carton exec 'catmandu export output to YAML'

followers:
	@carton exec 'catmandu export followers to YAML'

following:
	@carton exec 'catmandu export following to YAML'

genkey: keys/private.pem keys/public.pem

keys/private.pem:
	openssl genrsa -out keys/private.pem 2048

keys/public.pem: keys/private.pem
	openssl rsa -in keys/private.pem -outform PEM -pubout -out keys/public.pem
