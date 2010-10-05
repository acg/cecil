ISSUES_DIR ?= $(CURDIR)/../issues

ISSUE_FILES = $(wildcard ${ISSUES_DIR}/i_*.cil )
COMMENT_FILES = $(wildcard ${ISSUES_DIR}/c_*.cil )
ISSUE_HTML_FILES = $(shell cd ${ISSUES_DIR}; ls i_*.cil | sed -e 's/.cil$$/.html/' )
TEMPLATE_FILES = $(shell find ${CURDIR}/../templates -name \*.tt.html )

TARGETS = summary.html $(ISSUE_HTML_FILES)


all : $(TARGETS)

summary.html : $(ISSUE_FILES) $(TEMPLATE_FILES) ../bin/cecil
	../bin/cecil $(ISSUES_DIR) /summary.html > $@

i_%.html : $(ISSUES_DIR)/i_%.cil $(TEMPLATE_FILES) ../bin/cecil
	../bin/cecil $(ISSUES_DIR) /$@ > $@

clean :
	rm -f $(TARGETS)

