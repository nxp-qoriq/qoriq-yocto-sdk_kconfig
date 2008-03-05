# ===========================================================================
# Kernel configuration targets
# These targets are used from top-level makefile

PHONY += oldconfig xconfig gconfig menuconfig config silentoldconfig update-po-config
HOSTCC := cc
HOSTCXX := c++
HOSTCFLAGS := -O2 -DPROJECT=\"Topaz\" -DPROJECTADJ=\"Topaz\" -I"$(obj)"
CONFIG_SHELL := sh
MKDIR := mkdir -p

Kconfig := $(srctree)/Kconfig

xconfig: $(obj)/qconf
	@$(MKDIR) $(srctree)/include/config
	$< $(Kconfig)

gconfig: $(obj)/gconf
	@$(MKDIR) $(srctree)/include/config
	$< $(Kconfig)

menuconfig: $(obj)/mconf
	@$(MKDIR) $(srctree)/include/config
	$< $(Kconfig)

config: $(obj)/conf
	@$(MKDIR) $(srctree)/include/config
	$< $(Kconfig)

oldconfig: $(obj)/conf
	@$(MKDIR) $(srctree)/include/config
	$< -o $(Kconfig)

silentoldconfig: $(obj)/conf
	@$(MKDIR) $(srctree)/include/config
	$< -s $(Kconfig)

# Create new linux.pot file
# Adjust charset to UTF-8 in .po file to accept UTF-8 in Kconfig files
# The symlink is used to repair a deficiency in arch/um
update-po-config: $(obj)/kxgettext $(obj)/gconf.glade.h
	$(Q)echo "  GEN config"
	$(Q)xgettext --default-domain=linux              \
	    --add-comments --keyword=_ --keyword=N_      \
	    --from-code=UTF-8                            \
	    --files-from=scripts/kconfig/POTFILES.in     \
	    --output $(obj)/config.pot
	$(Q)sed -i s/CHARSET/UTF-8/ $(obj)/config.pot
	$(Q)ln -fs Kconfig.i386 arch/um/Kconfig.arch
	$(Q)(for i in `ls arch/`;                        \
	    do                                           \
		echo "  GEN $$i";                        \
		$(obj)/kxgettext arch/$$i/Kconfig        \
		     >> $(obj)/config.pot;               \
	    done )
	$(Q)msguniq --sort-by-file --to-code=UTF-8 $(obj)/config.pot \
	    --output $(obj)/linux.pot
	$(Q)rm -f arch/um/Kconfig.arch
	$(Q)rm -f $(obj)/config.pot

PHONY += randconfig allyesconfig allnoconfig allmodconfig defconfig

randconfig: $(obj)/conf
	$< -r $(Kconfig)

allyesconfig: $(obj)/conf
	$< -y $(Kconfig)

allnoconfig: $(obj)/conf
	$< -n $(Kconfig)

allmodconfig: $(obj)/conf
	$< -m $(Kconfig)

defconfig: $(obj)/conf
ifeq ($(KBUILD_DEFCONFIG),)
	$< -d $(Kconfig)
else
	@echo "*** Default configuration is based on '$(KBUILD_DEFCONFIG)'"
	$(Q)$< -D arch/$(SRCARCH)/configs/$(KBUILD_DEFCONFIG) $(Kconfig)
endif

%_defconfig: $(obj)/conf
	$(Q)$< -D arch/$(SRCARCH)/configs/$@ $(Kconfig)

# Help text used by make help
help:
	@echo  '  config	  - Update current config utilising a line-oriented program'
	@echo  '  menuconfig	  - Update current config utilising a menu based program'
	@echo  '  xconfig	  - Update current config utilising a QT based front-end'
	@echo  '  gconfig	  - Update current config utilising a GTK based front-end'
	@echo  '  oldconfig	  - Update current config utilising a provided .config as base'
	@echo  '  silentoldconfig - Same as oldconfig, but quietly'
	@echo  '  randconfig	  - New config with random answer to all options'
	@echo  '  defconfig	  - New config with default answer to all options'
	@echo  '  allmodconfig	  - New config selecting modules when possible'
	@echo  '  allyesconfig	  - New config where all options are accepted with yes'
	@echo  '  allnoconfig	  - New config where all options are answered with no'

# lxdialog stuff
check-lxdialog  := $(srctree)/$(src)/lxdialog/check-lxdialog.sh

# Use recursively expanded variables so we do not call gcc unless
# we really need to do so. (Do not call gcc as part of make mrproper)
HOST_EXTRACFLAGS = $(shell $(CONFIG_SHELL) $(check-lxdialog) -ccflags)
HOST_LOADLIBES   = $(shell $(CONFIG_SHELL) $(check-lxdialog) -ldflags $(HOSTCC))
HOST_EXTRACFLAGS += -DLOCALE

$(obj)/%.o: $(src)/%.c
	@$(MKDIR) $(@D)
	$(HOSTCC) $(HOSTCFLAGS) -c $(HOST_EXTRACFLAGS) $< -o $@

$(obj)/%.o: $(src)/%.cc
	@$(MKDIR) $(@D)
	$(HOSTCXX) $(HOSTCFLAGS) -c $(HOST_EXTRACFLAGS) $< -o $@

# ===========================================================================
# Shared Makefile for the various kconfig executables:
# conf:	  Used for defconfig, oldconfig and related targets
# mconf:  Used for the mconfig target.
#         Utilizes the lxdialog package
# qconf:  Used for the xconfig target
#         Based on QT which needs to be installed to compile it
# gconf:  Used for the gconfig target
#         Based on GTK which needs to be installed to compile it
# object files used by all kconfig flavours

lxdialog := lxdialog/checklist.o lxdialog/util.o lxdialog/inputbox.o
lxdialog += lxdialog/textbox.o lxdialog/yesno.o lxdialog/menubox.o

conf-objs	:= conf.o zconf.tab.o
$(obj)/conf: $(conf-objs:%=$(obj)/%)
	$(HOSTCC) $^ -o $@

mconf-objs	:= mconf.o zconf.tab.o $(lxdialog)
$(obj)/mconf: $(mconf-objs:%=$(obj)/%)
	$(HOSTCC) $^ $(HOST_LOADLIBES) -o $@

kxgettext-objs	:= kxgettext.o zconf.tab.o
$(obj)/kxgettext: $(kxgettext-objs:%=$(obj)/%)
	$(HOSTCC) $^ -o $@

hostprogs-y := conf qconf gconf kxgettext

ifeq ($(MAKECMDGOALS),menuconfig)
	hostprogs-y += mconf
endif

ifeq ($(MAKECMDGOALS),xconfig)
	qconf-target := 1
endif
ifeq ($(MAKECMDGOALS),gconfig)
	gconf-target := 1
endif


ifeq ($(qconf-target),1)
qconf-objs	:= qconf.o kconfig_load.o zconf.tab.o
endif

ifeq ($(gconf-target),1)
gconf-objs	:= gconf.o kconfig_load.o zconf.tab.o
endif

clean-files	:= lkc_defs.h qconf.moc .tmp_qtcheck \
		   .tmp_gtkcheck zconf.tab.c lex.zconf.c zconf.hash.c gconf.glade.h
clean-files     += mconf qconf gconf
clean-files     += config.pot linux.pot

# Check that we have the required ncurses stuff installed for lxdialog (menuconfig)
PHONY += $(obj)/dochecklxdialog
$(addprefix $(obj)/,$(lxdialog)): $(obj)/dochecklxdialog
$(obj)/dochecklxdialog:
	$(Q)$(CONFIG_SHELL) $(check-lxdialog) -check $(HOSTCC) $(HOST_EXTRACFLAGS) $(HOST_LOADLIBES)

always := dochecklxdialog

# generated files seem to need this to find local include files
$(obj)/lex.zconf.o: $(obj)/lex.zconf.c
	@$(MKDIR) $(@D)
	$(HOSTCC) $(HOSTCFLAGS) -c -I$(src) $(HOST_EXTRACFLAGS) $< -o $@

$(obj)/zconf.tab.o: $(obj)/zconf.tab.c
	$(HOSTCC) $(HOSTCFLAGS) -c -I$(src) $(HOST_EXTRACFLAGS) $< -o $@


$(obj)/qconf.o: $(src)/qconf.cc
	@$(MKDIR) $(@D)
	$(HOSTCXX) $(HOSTCFLAGS) -c $(HOST_EXTRACFLAGS) $(KC_QT_CFLAGS) -D LKC_DIRECT_LINK $< -o $@

$(obj)/qconf: $(qconf-objs:%=$(obj)/%) $(obj)/.tmp_qtcheck
	$(HOSTCXX) $(KC_QT_LIBS) -ldl $(qconf-objs:%=$(obj)/%) -o $@

$(obj)/gconf.o: $(src)/gconf.c
	@$(MKDIR) $(@D)
	$(HOSTCC) $(HOSTCFLAGS) -c $(HOST_EXTRACFLAGS) -D LKC_DIRECT_LINK \
	`pkg-config --cflags gtk+-2.0 gmodule-2.0 libglade-2.0` $< -o $@

$(obj)/gconf: $(gconf-objs:%=$(obj)/%)
	$(HOSTCC) `pkg-config --libs gtk+-2.0 gmodule-2.0 libglade-2.0` \
	$^ -o $@

ifeq ($(qconf-target),1)
$(obj)/.tmp_qtcheck: $(src)/Makefile
-include $(obj)/.tmp_qtcheck

# QT needs some extra effort...
$(obj)/.tmp_qtcheck:
	@$(MKDIR) $(@D)
	@set -e; echo "  CHECK   qt"; dir=""; pkg=""; \
	pkg-config --exists qt 2> /dev/null && pkg=qt; \
	pkg-config --exists qt-mt 2> /dev/null && pkg=qt-mt; \
	if [ -n "$$pkg" ]; then \
	  cflags="\$$(shell pkg-config $$pkg --cflags)"; \
	  libs="\$$(shell pkg-config $$pkg --libs)"; \
	  moc="\$$(shell pkg-config $$pkg --variable=prefix)/bin/moc"; \
	  dir="$$(pkg-config $$pkg --variable=prefix)"; \
	else \
	  for d in $$QTDIR /usr/share/qt* /usr/lib/qt*; do \
	    if [ -f $$d/include/qconfig.h ]; then dir=$$d; break; fi; \
	  done; \
	  if [ -z "$$dir" ]; then \
	    echo "*"; \
	    echo "* Unable to find the QT3 installation. Please make sure that"; \
	    echo "* the QT3 development package is correctly installed and"; \
	    echo "* either install pkg-config or set the QTDIR environment"; \
	    echo "* variable to the correct location."; \
	    echo "*"; \
	    false; \
	  fi; \
	  libpath=$$dir/lib; lib=qt; osdir=""; \
	  $(HOSTCXX) -print-multi-os-directory > /dev/null 2>&1 && \
	    osdir=x$$($(HOSTCXX) -print-multi-os-directory); \
	  test -d $$libpath/$$osdir && libpath=$$libpath/$$osdir; \
	  test -f $$libpath/libqt-mt.so && lib=qt-mt; \
	  cflags="-I$$dir/include"; \
	  libs="-L$$libpath -Wl,-rpath,$$libpath -l$$lib"; \
	  moc="$$dir/bin/moc"; \
	fi; \
	if [ ! -x $$dir/bin/moc -a -x /usr/bin/moc ]; then \
	  echo "*"; \
	  echo "* Unable to find $$dir/bin/moc, using /usr/bin/moc instead."; \
	  echo "*"; \
	  moc="/usr/bin/moc"; \
	fi; \
	echo "KC_QT_CFLAGS=$$cflags" > $@; \
	echo "KC_QT_LIBS=$$libs" >> $@; \
	echo "KC_QT_MOC=$$moc" >> $@
endif

$(obj)/gconf.o: $(obj)/.tmp_gtkcheck

ifeq ($(gconf-target),1)
-include $(obj)/.tmp_gtkcheck

# GTK needs some extra effort, too...
$(obj)/.tmp_gtkcheck:
	@$(MKDIR) $(@D)
	@if `pkg-config --exists gtk+-2.0 gmodule-2.0 libglade-2.0`; then		\
		if `pkg-config --atleast-version=2.0.0 gtk+-2.0`; then			\
			touch $@;								\
		else									\
			echo "*"; 							\
			echo "* GTK+ is present but version >= 2.0.0 is required.";	\
			echo "*";							\
			false;								\
		fi									\
	else										\
		echo "*"; 								\
		echo "* Unable to find the GTK+ installation. Please make sure that"; 	\
		echo "* the GTK+ 2.0 development package is correctly installed..."; 	\
		echo "* You need gtk+-2.0, glib-2.0 and libglade-2.0."; 		\
		echo "*"; 								\
		false;									\
	fi
endif

$(obj)/zconf.tab.o: $(obj)/lex.zconf.c $(obj)/zconf.hash.c

$(obj)/kconfig_load.o: $(obj)/lkc_defs.h

$(obj)/qconf.o: $(obj)/qconf.moc $(obj)/lkc_defs.h

$(obj)/gconf.o: $(obj)/lkc_defs.h

$(obj)/%.moc: $(src)/%.h
	@$(MKDIR) $(@D)
	$(KC_QT_MOC) -i $< -o $@

$(obj)/lkc_defs.h: $(src)/lkc_proto.h
	@$(MKDIR) $(@D)
	sed < $< > $@ 's/P(\([^,]*\),.*/#define \1 (\*\1_p)/'

# Extract gconf menu items for I18N support
$(obj)/gconf.glade.h: $(obj)/gconf.glade
	intltool-extract --type=gettext/glade $(obj)/gconf.glade

###
# The following requires flex/bison/gperf
# By default we use the _shipped versions, uncomment the following line if
# you are modifying the flex/bison src.
# LKC_GENPARSER := 1

ifdef LKC_GENPARSER

$(obj)/zconf.tab.c: $(src)/zconf.y
$(obj)/lex.zconf.c: $(src)/zconf.l
$(obj)/zconf.hash.c: $(src)/zconf.gperf

%.tab.c: %.y
	bison -l -b $* -p $(notdir $*) $<
	cp $@ $@_shipped

lex.%.c: %.l
	flex -L -P$(notdir $*) -o$@ $<
	cp $@ $@_shipped

%.hash.c: %.gperf
	gperf < $< > $@
	cp $@ $@_shipped

else
$(obj)/%:: $(src)/%_shipped
	cp -af $< $@
endif