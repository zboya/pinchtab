#!/usr/bin/env bash
set -euo pipefail

# doctor.sh — Verify and setup development environment for pinchtab
# Interactive: asks before installing anything
# Style: matches install.sh conventions

BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CRITICAL=0
WARNINGS=0

# ── Helpers ──────────────────────────────────────────────────────────

ok()   { echo -e "  ${GREEN}✅${NC} $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; [ -n "${2:-}" ] && echo -e "     ${DIM}$2${NC}"; CRITICAL=$((CRITICAL + 1)); }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $1"; [ -n "${2:-}" ] && echo -e "     ${DIM}$2${NC}"; WARNINGS=$((WARNINGS + 1)); }
info() { echo -e "     ${CYAN}→${NC} $1"; }

confirm() {
  local prompt="$1"
  echo -ne "     ${BOLD}$prompt [y/N]${NC} "
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

section() {
  echo ""
  echo -e "${BLUE}━━━ $1 ━━━${NC}"
  echo ""
}

# ── Detect OS & package manager ──────────────────────────────────────

OS="$(uname -s)"
HAS_BREW=false
HAS_APT=false
command -v brew &>/dev/null && HAS_BREW=true
command -v apt-get &>/dev/null && HAS_APT=true

# ── Start ────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}Verifying and setting up development environment...${NC}"

section "Go Backend Requirements"

# ── Go ───────────────────────────────────────────────────────────────

if command -v go &>/dev/null; then
  GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
  GO_MAJOR=$(echo "$GO_VERSION" | cut -d. -f1)
  GO_MINOR=$(echo "$GO_VERSION" | cut -d. -f2)

  if [ "$GO_MAJOR" -ge 1 ] && [ "$GO_MINOR" -ge 25 ]; then
    ok "Go $GO_VERSION"
  else
    fail "Go $GO_VERSION" "Go 1.25+ required."
    if $HAS_BREW && confirm "Install latest Go via brew?"; then
      brew install go
      ok "Go installed"
    else
      info "Install from https://go.dev/dl/"
    fi
  fi
else
  fail "Go not found"
  if $HAS_BREW && confirm "Install Go via brew?"; then
    brew install go
    ok "Go installed"
  else
    info "Install from https://go.dev/dl/"
  fi
fi

# ── golangci-lint ────────────────────────────────────────────────────

if command -v golangci-lint &>/dev/null; then
  LINT_VERSION=$(golangci-lint version --short 2>/dev/null || golangci-lint --version 2>/dev/null | head -1 | awk '{print $4}')
  ok "golangci-lint $LINT_VERSION"
else
  fail "golangci-lint" "Required for pre-commit hooks and CI."
  if $HAS_BREW && confirm "Install golangci-lint via brew?"; then
    brew install golangci-lint
    ok "golangci-lint installed"
  elif command -v go &>/dev/null && confirm "Install golangci-lint via go install?"; then
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    ok "golangci-lint installed"
  else
    info "Install: brew install golangci-lint"
    info "    or:  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
  fi
fi

# ── Git hooks ────────────────────────────────────────────────────────

if [ -f ".git/hooks/pre-commit" ]; then
  ok "Git hooks installed"
else
  warn "Git hooks not installed"
  if confirm "Install git hooks now?"; then
    ./scripts/install-hooks.sh 2>/dev/null || {
      cp scripts/pre-commit .git/hooks/pre-commit
      chmod +x .git/hooks/pre-commit
    }
    ok "Git hooks installed"
  fi
fi

# ── Go dependencies ─────────────────────────────────────────────────

if [ -f "go.mod" ]; then
  if go list -m all &>/dev/null 2>&1; then
    ok "Go dependencies"
  else
    warn "Go dependencies not downloaded"
    if confirm "Download Go dependencies now?"; then
      go mod download
      ok "Go dependencies downloaded"
    fi
  fi
fi

section "Dashboard Requirements (React/TypeScript)"

if [ -d "dashboard" ]; then

  # ── Node.js ──────────────────────────────────────────────────────

  if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)

    if [ "$NODE_MAJOR" -ge 18 ]; then
      ok "Node.js $NODE_VERSION"
    else
      warn "Node.js $NODE_VERSION" "Node 18+ recommended."
    fi
  else
    warn "Node.js not found" "Optional — needed for dashboard development."
    if $HAS_BREW && confirm "Install Node.js via brew?"; then
      brew install node
      ok "Node.js installed"
    else
      info "Install from https://nodejs.org"
    fi
  fi

  # ── Bun ────────────────────────────────────────────────────────

  if command -v bun &>/dev/null; then
    BUN_VERSION=$(bun -v)
    ok "Bun $BUN_VERSION"
  else
    warn "Bun not found" "Optional — used for fast dashboard builds."
    if confirm "Install Bun?"; then
      curl -fsSL https://bun.sh/install | bash
      ok "Bun installed (restart shell to use)"
    else
      info "Install: curl -fsSL https://bun.sh/install | bash"
    fi
  fi

  # ── Dashboard deps ─────────────────────────────────────────────

  if [ -d "dashboard/node_modules" ]; then
    ok "Dashboard dependencies"
  else
    warn "Dashboard dependencies not installed"
    if command -v bun &>/dev/null; then
      if confirm "Install dashboard dependencies via bun?"; then
        (cd dashboard && bun install)
        ok "Dashboard dependencies installed"
      fi
    elif command -v npm &>/dev/null; then
      if confirm "Install dashboard dependencies via npm?"; then
        (cd dashboard && npm install)
        ok "Dashboard dependencies installed"
      fi
    else
      info "Run: cd dashboard && bun install"
    fi
  fi

else
  echo -e "  ${DIM}Dashboard not found (optional)${NC}"
fi

section "Summary"

if [ $CRITICAL -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}All checks passed!${NC} You're ready to develop."
  echo ""
  echo -e "  ${DIM}Next steps:${NC}"
  echo -e "    go build ./cmd/pinchtab     ${DIM}# Build${NC}"
  echo -e "    go test ./...               ${DIM}# Test${NC}"
  exit 0
fi

[ $CRITICAL -gt 0 ] && echo -e "  ${RED}❌ $CRITICAL critical issue(s) remaining${NC}"
[ $WARNINGS -gt 0 ] && echo -e "  ${YELLOW}⚠️  $WARNINGS warning(s)${NC}"

if [ $CRITICAL -gt 0 ]; then
  echo ""
  echo -e "  ${DIM}After installing, run ./doctor.sh again.${NC}"
  exit 1
fi

exit 0
