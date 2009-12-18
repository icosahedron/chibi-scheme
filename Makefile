# -*- makefile-gmake -*-

.PHONY: all libs doc dist clean cleaner test install uninstall
.PRECIOUS: %.c

# install configuration

CC       ?= cc
PREFIX   ?= /usr/local
BINDIR   ?= $(PREFIX)/bin
LIBDIR   ?= $(PREFIX)/lib
SOLIBDIR ?= $(PREFIX)/lib
INCDIR   ?= $(PREFIX)/include/chibi
MODDIR   ?= $(PREFIX)/share/chibi
LIBDIR   ?= $(PREFIX)/lib/chibi

DESTDIR  ?=

GENSTUBS ?= ./tools/genstubs.scm

# system configuration - if not using GNU make, set PLATFORM and the
# following flags as necessary.

ifndef PLATFORM
ifeq ($(shell uname),Darwin)
PLATFORM=macosx
else
ifeq ($(shell uname -o),Msys)
PLATFORM=mingw
SOLIBDIR = $(BINDIR)
DIFFOPTS = -b
else
PLATFORM=unix
endif
endif
endif

ifeq ($(PLATFORM),macosx)
SO  = .dylib
EXE =
CLIBFLAGS = -dynamiclib
STATICFLAGS = -static-libgcc -DSEXP_USE_DL=0
else
ifeq ($(PLATFORM),mingw)
SO  = .dll
EXE = .exe
CC = gcc
CLIBFLAGS = -shared
CPPFLAGS += -DSEXP_USE_STRING_STREAMS=0 -DBUILDING_DLL -DSEXP_USE_DEBUG=0
LDFLAGS += -Wl,--out-implib,libchibi-scheme$(SO).a
else
SO  = .so
EXE =
CLIBFLAGS = -fPIC -shared
STATICFLAGS = -static -DSEXP_USE_DL=0
endif
endif

ifeq ($(USE_BOEHM),1)
SEXP_USE_BOEHM = 1
endif

ifeq ($(SEXP_USE_BOEHM),1)
GCLDFLAGS := -lgc
XCPPFLAGS := $(CPPFLAGS) -Iinclude -DSEXP_USE_BOEHM=1
else
GCLDFLAGS :=
XCPPFLAGS := $(CPPFLAGS) -Iinclude
endif

ifeq ($(SEXP_USE_DL),0)
XLDFLAGS  := $(LDFLAGS) $(GCLDFLAGS) -lm
XCFLAGS   := -Wall -DSEXP_USE_DL=0 -g3 $(CFLAGS)
else
XLDFLAGS  := $(LDFLAGS) $(GCLDFLAGS) -ldl -lm
XCFLAGS   := -Wall -g3 $(CFLAGS)
endif

########################################################################

all: chibi-scheme$(EXE) libs

COMPILED_LIBS := lib/srfi/27/rand$(SO) lib/srfi/33/bit$(SO) \
	lib/srfi/69/hash$(SO) lib/srfi/98/env$(SO) \
	lib/chibi/ast$(SO) lib/chibi/net$(SO) \
	lib/chibi/posix$(SO) lib/chibi/heap-stats$(SO)

libs: $(COMPILED_LIBS)

INCLUDES = include/chibi/sexp.h include/chibi/config.h include/chibi/install.h

include/chibi/install.h: Makefile
	echo '#define sexp_so_extension "'$(SO)'"' > $@
	echo '#define sexp_default_module_dir "'$(MODDIR)'"' >> $@
	echo '#define sexp_platform "'$(PLATFORM)'"' >> $@

sexp.o: sexp.c gc.c opt/bignum.c $(INCLUDES) Makefile
	$(CC) -c $(XCPPFLAGS) $(XCFLAGS) $(CLIBFLAGS) -o $@ $<

eval.o: eval.c opcodes.c opt/debug.c opt/simplify.c $(INCLUDES) include/chibi/eval.h Makefile
	$(CC) -c $(XCPPFLAGS) $(XCFLAGS) $(CLIBFLAGS) -o $@ $<

main.o: main.c $(INCLUDES) include/chibi/eval.h Makefile
	$(CC) -c $(XCPPFLAGS) $(XCFLAGS) -o $@ $<

libchibi-scheme$(SO): eval.o sexp.o
	$(CC) $(CLIBFLAGS) -o $@ $^ $(XLDFLAGS)

chibi-scheme$(EXE): main.o libchibi-scheme$(SO)
	$(CC) $(XCPPFLAGS) $(XCFLAGS) -o $@ $< -L. -lchibi-scheme

chibi-scheme-static$(EXE): main.o eval.o sexp.o
	$(CC) $(XCFLAGS) $(STATICFLAGS) -o $@ $^ $(XLDFLAGS)

%.c: %.stub chibi-scheme$(EXE) $(GENSTUBS)
	LD_LIBRARY_PATH=.:$(LD_LIBRARY_PATH) $(GENSTUBS) $<

lib/%$(SO): lib/%.c $(INCLUDES)
	-$(CC) $(CLIBFLAGS) $(XCPPFLAGS) $(XCFLAGS) -o $@ $< -L. -lchibi-scheme

clean:
	rm -f *.o *.i *.s *.8
	find lib -name \*$(SO) -exec rm -f '{}' \;
	rm -f tests/basic/*.out tests/basic/*.err

cleaner: clean
	rm -f chibi-scheme$(EXE) chibi-scheme-static$(EXE) $(COMPILED_LIBS) *$(SO) *.a include/chibi/install.h
	rm -rf *.dSYM

test-basic: chibi-scheme$(EXE)
	@for f in tests/basic/*.scm; do \
	    ./chibi-scheme$(EXE) $$f >$${f%.scm}.out 2>$${f%.scm}.err; \
	    if diff -q $(DIFFOPTS) $${f%.scm}.out $${f%.scm}.res; then \
	        echo "[PASS] $${f%.scm}"; \
	    else \
	        echo "[FAIL] $${f%.scm}"; \
	    fi; \
	done

test-numbers: all
	LD_LIBRARY_PATH=.:$(LD_LIBRARY_PATH) ./chibi-scheme$(EXE) tests/numeric-tests.scm

test-match: all
	LD_LIBRARY_PATH=.:$(LD_LIBRARY_PATH) ./chibi-scheme$(EXE) tests/match-tests.scm

test-loop: all
	LD_LIBRARY_PATH=.:$(LD_LIBRARY_PATH) ./chibi-scheme$(EXE) tests/loop-tests.scm

test: all
	LD_LIBRARY_PATH=.:$(LD_LIBRARY_PATH) ./chibi-scheme$(EXE) tests/r5rs-tests.scm

install: chibi-scheme$(EXE)
	mkdir -p $(DESTDIR)$(BINDIR)
	cp chibi-scheme$(EXE) $(DESTDIR)$(BINDIR)/
	mkdir -p $(DESTDIR)$(MODDIR)
	cp init.scm config.scm $(DESTDIR)$(MODDIR)/
	cp -r lib/ $(DESTDIR)$(MODDIR)/
	mkdir -p $(DESTDIR)$(INCDIR)
	cp $(INCLUDES) include/chibi/eval.h $(DESTDIR)$(INCDIR)/
	mkdir -p $(DESTDIR)$(LIBDIR)
	mkdir -p $(DESTDIR)$(SOLIBDIR)
	cp libchibi-scheme$(SO) $(DESTDIR)$(SOLIBDIR)/
	cp libchibi-scheme$(SO) $(DESTDIR)$(SOLIBDIR)/
	-cp libchibi-scheme.a $(DESTDIR)$(LIBDIR)/
	if type ldconfig >/dev/null 2>/dev/null; then ldconfig; fi

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/chibi-scheme$(EXE)
	rm -f $(DESTDIR)$(BINDIR)/chibi-scheme-static$(EXE)
	rm -f $(DESTDIR)$(SOLIBDIR)/libchibi-scheme$(SO)
	rm -f $(DESTDIR)$(LIBDIR)/libchibi-scheme$(SO).a
	cd $(DESTDIR)$(INCDIR) && rm -f $(INCLUDES) include/chibi/eval.h
	rm -rf $(DESTDIR)$(MODDIR)

dist: cleaner
	rm -f chibi-scheme-`cat VERSION`.tgz
	mkdir chibi-scheme-`cat VERSION`
	for f in `hg manifest`; do mkdir -p chibi-scheme-`cat VERSION`/`dirname $$f`; ln -s `pwd`/$$f chibi-scheme-`cat VERSION`/$$f; done
	tar cphzvf chibi-scheme-`cat VERSION`.tgz chibi-scheme-`cat VERSION`
	rm -rf chibi-scheme-`cat VERSION`
