# iac-security-gate: scan Terraform before it deploys.
#
# The gate (checkov + trivy) runs the same here as in CI and in pre-commit.
# `make scan` passes on the hardened infra/; `make scan-insecure` fails on the
# deliberately broken examples/insecure/, which proves the scanners can go red.
#
# deploy/destroy need real AWS credentials; scan/validate/fmt do not.

TF        := terraform
INFRA_DIR := infra
SCAN_DIR  ?= infra

.PHONY: help scan scan-insecure checkov trivy check-skips fmt fmt-check validate \
        deploy destroy baseline teardown-check precommit-install

help:
	@echo "scan             - checkov + trivy on $(SCAN_DIR) (override SCAN_DIR=...)"
	@echo "scan-insecure    - checkov + trivy on examples/insecure (must FAIL)"
	@echo "check-skips      - fail if any suppression in infra/ has no reason"
	@echo "fmt / fmt-check  - format Terraform / check formatting"
	@echo "validate         - terraform init -backend=false + validate (infra/)"
	@echo "deploy           - terraform apply the hardened infra/ (needs AWS creds)"
	@echo "destroy          - terraform destroy (needs AWS creds)"
	@echo "baseline         - snapshot the account to evidence/baseline.txt"
	@echo "teardown-check   - snapshot the account to evidence/teardown.txt"
	@echo "precommit-install- install the git pre-commit hook"

# --- the gate (no credentials needed) ------------------------------------

scan: check-skips checkov trivy
	@echo "scan: $(SCAN_DIR) passed checkov and trivy"

checkov:
	checkov -d $(SCAN_DIR) --compact --quiet

trivy:
	trivy config $(SCAN_DIR) --quiet --exit-code 1

# The vulnerable twin. This target is expected to FAIL; that is the point.
scan-insecure:
	@echo "Scanning examples/insecure — this MUST report findings and fail."
	checkov -d examples/insecure --compact --quiet; \
	trivy config examples/insecure --quiet --exit-code 1

check-skips:
	python3 scripts/check-skips.py $(INFRA_DIR)

fmt:
	$(TF) fmt -recursive

fmt-check:
	$(TF) fmt -check -recursive

validate:
	$(TF) -chdir=$(INFRA_DIR) init -backend=false -input=false
	$(TF) -chdir=$(INFRA_DIR) validate

# --- apply / destroy (need AWS credentials) ------------------------------

deploy:
	$(TF) -chdir=$(INFRA_DIR) init -input=false
	$(TF) -chdir=$(INFRA_DIR) apply -auto-approve

destroy:
	$(TF) -chdir=$(INFRA_DIR) destroy -auto-approve

baseline:
	./scripts/aws-inventory.sh evidence/baseline.txt

teardown-check:
	./scripts/aws-inventory.sh evidence/teardown.txt

# --- developer setup -----------------------------------------------------

precommit-install:
	pre-commit install
