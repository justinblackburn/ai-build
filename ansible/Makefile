# Repo tooling. Molecule and lint tools live in a venv (see README, "Testing with Molecule").
VENV ?= $(HOME)/.venvs/molecule-venv
export PATH := $(VENV)/bin:$(PATH)
# Scenarios apply roles by name, so the roles directory must be on the path.
export ANSIBLE_ROLES_PATH := $(CURDIR)/playbooks/roles

ROLE ?= base
SCENARIO ?= default

# Unique per worktree, so two agents can test different roles (or the same role in
# two worktrees) at the same time without container name clashes.
export MOLECULE_RUN_ID ?= $(shell pwd | sha1sum | cut -c1-8)
# Molecule's ephemeral state is otherwise shared by every checkout testing the same role.
export MOLECULE_EPHEMERAL_DIRECTORY ?= $(CURDIR)/.molecule/$(MOLECULE_RUN_ID)

.PHONY: test lint

test:
	@test -d playbooks/roles/$(ROLE)/molecule/$(SCENARIO) || { echo "no scenario $(SCENARIO) for role $(ROLE)"; exit 1; }
	cd playbooks/roles/$(ROLE) && molecule test -s $(SCENARIO)

lint:
	ansible-lint -c .ansible-lint playbooks/roles
	yamllint -c .yamllint .
