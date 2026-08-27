QMLLINT := /usr/lib/qt6/bin/qmllint
QML_FILES := Panel.qml Service.qml

.PHONY: qml-check shellcheck install reinstall doctor validate help

# qs.Commons and qs.Ui cannot resolve without a full Omarchy install, so
# most output is import noise -- filtered the same way tormarchy's own
# Makefile does. A file named Panel.qml whose root element is also `Panel`
# (inheriting the real qs.Ui base type) additionally trips a same-directory
# self-name "inheritance cycle" warning in a standalone lint -- confirmed
# harmless by testing under a renamed copy, where it disappears; the real
# Quickshell plugin loader resolves the base type from its own module path,
# not this linter's local-directory scan.
qml-check:
	$(QMLLINT) -I /usr/share/omarchy/shell $(QML_FILES) 2>&1 \
	  | grep -vE 'qs\.(Commons|Ui)|Failed to import|Unqualified access|unresolved-type|was not found|ComponentBehavior|Did you mean|inheritance-cycle|unknown grouped property scope anchors|^\s*\^|^---$$|^import |^$$' \
	  || true

shellcheck:
	shellcheck macarchy

install:
	sudo ./macarchy setup

reinstall:
	sudo ./macarchy uninstall
	sudo ./macarchy setup
	omarchy-restart-shell

doctor:
	./macarchy status

validate: qml-check shellcheck
	omarchy plugin validate .

help:
	@echo "qml-check    qmllint, import noise filtered out"
	@echo "shellcheck   shellcheck against the macarchy CLI script"
	@echo "install      sudo ./macarchy setup"
	@echo "reinstall    uninstall, setup, restart the shell"
	@echo "doctor       ./macarchy status"
	@echo "validate     qml-check + shellcheck + omarchy plugin validate"
