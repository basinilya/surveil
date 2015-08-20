prefix = /usr/local
bindir = $(prefix)/bin
rulesdir = /etc/udev/rules.d
DESTDIR =
INSTALL = install

all:
	echo nothin

install: all
	$(INSTALL) -m755 camreplug $(DESTDIR)$(bindir)/
	$(INSTALL) -m755 mycycle $(DESTDIR)$(bindir)/
	$(INSTALL) -m755 my_stk1160_pal.sh $(DESTDIR)$(bindir)/
	$(INSTALL) -m644 85-my_stk1160_pal.rules $(DESTDIR)$(rulesdir)/
