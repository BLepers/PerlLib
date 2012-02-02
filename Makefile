TO_DIR=/usr/local/lib/site_perl

all: install

install:
	@echo Installing modules
	if ! test -d ${TO_DIR}; \
	then \
		sudo mkdir ${TO_DIR}; \
	fi
	sudo cp -r * ${TO_DIR}
