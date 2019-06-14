# ----------------------------------------------------------------------------------------
# Currently this Makefile is only viable on MacOS
# ----------------------------------------------------------------------------------------

ensure-mac-os:
	@if [[ `uname -s` != "Darwin" ]]; then \
		echo This Makefile can only be used on MacOS; \
	fi;

BREW := /usr/local/bin/brew
$(BREW): | $(RUBY) ensure-mac-os
	@echo "\n--- Installing Homebrew\n"
	ruby -e "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	$(BREW) update
	$(BREW) doctor


# ----------------------------------------------------------------------------------------
# Make sure Elixir and Erlang are installed
# ----------------------------------------------------------------------------------------

WHOAMI := $(shell whoami)
ASDF_ROOT := /Users/$(WHOAMI)/.asdf
ASDF := $(ASDF_ROOT)/bin/asdf
ASDF_ERLANG := $(ASDF_ROOT)/plugins/erlang/
ERLANG_VERSION := 20.0
ERLANG_INSTALLED := /Users/$(WHOAMI)/.asdf/installs/erlang/$(ERLANG_VERSION)
ASDF_ELIXIR := $(ASDF_ROOT)/plugins/elixir/
ELIXIR_VERSION := 1.8.1-otp-20
ELIXIR_INSTALLED := $(ASDF_ROOT)/installs/elixir/$(ELIXIR_VERSION)
MIX := $(ASDF_ROOT)/installs/elixir/$(ELIXIR_VERSION)/bin/mix
IEX := $(ASDF_ROOT)/installs/elixir/$(ELIXIR_VERSION)/bin/iex

$(ASDF):
	@echo "\n--- Installing asdf: https://github.com/asdf-vm/asdf for post-install setup\n"
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.4.0

$(KERL): $(ASDF)
	@echo "\n--- Installing kerl for erlang\n"
	curl https://raw.githubusercontent.com/kerl/kerl/master/kerl > $(KERL)
	chmod +x $(KERL)

$(ASDF_ERLANG): $(KERL)
	@echo "\n--- Installing asdf-kerl for erlang\n"
	$(ASDF) plugin-add erlang https://github.com/eproxus/asdf-kerl

$(ASDF_ELIXIR): $(ASDF)
	@echo "\n--- Installing asdf-elixir\n"
	$(ASDF) plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git

$(ERLANG_INSTALLED): | $(ASDF_ERLANG)
	@echo "\n--- Checking installed Erlang\n"
	$(BREW) install wxmac # for wx and observer
	$(ASDF) install erlang $(ERLANG_VERSION)
	$(ASDF) global erlang $(ERLANG_VERSION)

$(ELIXIR_INSTALLED): | $(ASDF_ERLANG) $(ERLANG_INSTALLED) $(ASDF_ELIXIR)
	@echo "\n--- Checking installed Elixir\n"
	$(ASDF) install elixir $(ELIXIR_VERSION)
	$(ASDF) global elixir $(ELIXIR_VERSION)

# We want to check that the user has run the asdf setup that makes shim commands
# available. We test this by running an asdf command and an elixir command
# that should both exit 0 if the shell can resolve `asdf`/`elixir`.

.PHONY: check-asdf-shims
check-asdf-shims: $(ELIXIR_INSTALLED)
	@echo "\n--- Checking asdf shims\n"
	@( asdf current elixir && elixir -v ) || (echo "\nError: asdf shims aren't working. You probably need to run the setup appropriate for your shell: https://github.com/asdf-vm/asdf"; exit 1)

.PHONY: hex-and-rebar
hex-and-rebar: check-asdf-shims
	@echo "\n--- Install local copy of rebar and hex\n"
	echo "N" | $(MIX) local.rebar
	@echo "\n"
	echo "Y" | $(MIX) local.hex
	@echo "\n"


# ----------------------------------------------------------------------------------------
# Elixir dependencies
# ----------------------------------------------------------------------------------------

MIX_ENV := test

.PHONY: get-deps
get-deps: hex-and-rebar
	@echo "\n--- Install Elixir dependencies\n"
	MIX_ENV=test $(MIX) deps.get
	MIX_ENV=test $(MIX) deps.compile --all

.PHONY: compile
compile: get-deps
	@echo "\n--- Compiling Elixir code\n"
	MIX_ENV=test $(MIX) compile --warnings-as-errors --force

.PHONY: enforce-format
enforce-format: compile
	@echo "\n--- Enforce code format\n"
	MIX_ENV=test $(MIX) format --check-formatted

.PHONY: credo
credo: get-deps
	@echo "\n--- Enforcing code quality\n"
	MIX_ENV=test $(MIX) credo

.PHONY: code-ready
code-ready: get-deps compile enforce-format credo


# ----------------------------------------------------------------------------------------
# Unit tests
# ----------------------------------------------------------------------------------------

.PHONY: test
test: code-ready
	@echo "\n--- Running unit tests and verifying code coverages\n"
	MIX_ENV=test $(MIX) coveralls.html --raise --exclude needs_token --exclude flaky
