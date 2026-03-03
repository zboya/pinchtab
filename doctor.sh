#!/usr/bin/env bash
set -euo pipefail

# doctor.sh - Verify and setup development environment for pinchtab
# Checks requirements and auto-installs what it can (hooks, dependencies)
# Tells you what you need to install manually (Go, golangci-lint)

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CRITICAL_FAIL=0
WARNINGS=0
INSTALLED_SOMETHING=false

echo -e "${BLUE}🩺 Pinchtab Doctor${NC}"
echo -e "${BLUE}Verifying and setting up development environment...${NC}"
echo ""

# Critical check
check_critical() {
  local name="$1"
  local result="$2"
  
  if [ "$result" = "ok" ]; then
    echo -e "${GREEN}✅${NC} $name"
  else
    echo -e "${RED}❌${NC} $name"
    echo -e "   ${RED}$3${NC}"
    CRITICAL_FAIL=$((CRITICAL_FAIL + 1))
  fi
}

# Warning check
check_warning() {
  local name="$1"
  local result="$2"
  
  if [ "$result" = "ok" ]; then
    echo -e "${GREEN}✅${NC} $name"
  else
    echo -e "${YELLOW}⚠️${NC}  $name"
    echo -e "   ${YELLOW}$3${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
}

echo -e "${BLUE}━━━ Go Backend Requirements ━━━${NC}"
echo ""

# Go version (critical)
if command -v go &>/dev/null; then
  GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
  GO_MAJOR=$(echo "$GO_VERSION" | cut -d. -f1)
  GO_MINOR=$(echo "$GO_VERSION" | cut -d. -f2)
  
  if [ "$GO_MAJOR" -ge 1 ] && [ "$GO_MINOR" -ge 25 ]; then
    check_critical "Go $GO_VERSION" "ok"
  else
    check_critical "Go $GO_VERSION" "fail" "Go 1.25+ required. Install from https://go.dev/dl/"
  fi
else
  check_critical "Go" "fail" "Go not found. Install from https://go.dev/dl/"
fi

# golangci-lint (critical)
if command -v golangci-lint &>/dev/null; then
  LINT_VERSION=$(golangci-lint --version 2>/dev/null | head -1 | awk '{print $4}')
  check_critical "golangci-lint $LINT_VERSION" "ok"
else
  check_critical "golangci-lint" "fail" "Required for pre-commit checks. Install: brew install golangci-lint or go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
fi

# Git hooks (auto-install if missing)
if [ -f ".git/hooks/pre-commit" ]; then
  check_warning "Git hooks installed" "ok"
else
  echo -e "${YELLOW}⚠️${NC}  Git hooks not installed"
  echo -e "   ${BLUE}Installing git hooks...${NC}"
  ./scripts/install-hooks.sh
  echo -e "${GREEN}   ✅ Git hooks installed${NC}"
  INSTALLED_SOMETHING=true
fi

# Go modules (auto-download if needed)
if [ -f "go.mod" ]; then
  # Check if dependencies are downloaded
  if go list -m all &>/dev/null; then
    check_warning "Go dependencies" "ok"
  else
    echo -e "${YELLOW}⚠️${NC}  Go dependencies not downloaded"
    echo -e "   ${BLUE}Downloading dependencies...${NC}"
    go mod download
    echo -e "${GREEN}   ✅ Dependencies downloaded${NC}"
    INSTALLED_SOMETHING=true
  fi
else
  check_warning "go.mod" "fail" "go.mod not found"
fi

echo ""
echo -e "${BLUE}━━━ Dashboard Requirements (React/TypeScript) ━━━${NC}"
echo ""

# Check if dashboard directory exists
if [ -d "dashboard" ]; then
  # Node.js (critical for dashboard)
  if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    
    if [ "$NODE_MAJOR" -ge 18 ]; then
      check_warning "Node.js $NODE_VERSION" "ok"
    else
      check_warning "Node.js $NODE_VERSION" "fail" "Node 18+ recommended. Current: $NODE_VERSION"
    fi
  else
    check_warning "Node.js" "fail" "Optional for dashboard. Install from https://nodejs.org"
  fi

  # Bun (warning)
  if command -v bun &>/dev/null; then
    BUN_VERSION=$(bun -v)
    check_warning "Bun $BUN_VERSION" "ok"
  else
    check_warning "Bun" "fail" "Optional for dashboard. Install: curl -fsSL https://bun.sh/install | bash"
  fi

  # Dashboard deps installed
  if [ -d "dashboard/node_modules" ]; then
    check_warning "Dashboard dependencies" "ok"
  else
    check_warning "Dashboard dependencies" "fail" "Run: cd dashboard && bun install (or npm install)"
  fi
else
  echo -e "${YELLOW}⚠️${NC}  Dashboard not found (optional)"
fi

echo ""
echo -e "${BLUE}━━━ Summary ━━━${NC}"
echo ""

if [ $CRITICAL_FAIL -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  if [ "$INSTALLED_SOMETHING" = true ]; then
    echo -e "${GREEN}✅ Setup complete! Auto-installed missing components.${NC}"
  else
    echo -e "${GREEN}✅ All checks passed! You're ready to develop.${NC}"
  fi
  echo ""
  echo "Next steps:"
  echo "  go build ./cmd/pinchtab     # Build pinchtab"
  echo "  go test ./...               # Run tests"
  exit 0
elif [ $CRITICAL_FAIL -eq 0 ]; then
  if [ "$INSTALLED_SOMETHING" = true ]; then
    echo -e "${GREEN}✅ Auto-installed what I could.${NC}"
  fi
  echo -e "${YELLOW}⚠️  $WARNINGS warning(s). Development is possible but some tools are missing.${NC}"
  exit 0
else
  echo -e "${RED}❌ $CRITICAL_FAIL critical issue(s). Install these manually:${NC}"
  [ $WARNINGS -gt 0 ] && echo -e "${YELLOW}⚠️  $WARNINGS warning(s).${NC}"
  echo ""
  echo "After installing, run ./doctor.sh again."
  exit 1
fi
