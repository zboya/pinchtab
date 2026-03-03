# Contributing

Guide to build PinchTab from source and contribute to the project.

## System Requirements

### Minimum Requirements

| Requirement | Version | Purpose |
|------------|---------|---------|
| Go | 1.25+ | Build language |
| golangci-lint | Latest | Linting (required for pre-commit hooks) |
| Chrome/Chromium | Latest | Browser automation |
| macOS, Linux, or WSL2 | Current | OS support |

### Recommended Setup

- **macOS**: Homebrew for package management
- **Linux**: apt (Debian/Ubuntu) or yum (RHEL/CentOS)
- **WSL2**: Full Linux environment (not WSL1)

---

## Quick Start

**Fastest way to get started:**

```bash
# 1. Clone
git clone https://github.com/pinchtab/pinchtab.git
cd pinchtab

# 2. Run doctor (verifies environment + auto-installs hooks/deps)
./doctor.sh

# 3. Build and run
go build ./cmd/pinchtab
./pinchtab
```

**Example output:**
```
🩺 Pinchtab Doctor
Verifying and setting up development environment...

━━━ Go Backend Requirements ━━━

✅ Go 1.26.0
✅ golangci-lint 2.9.0
⚠️  Git hooks not installed
   Installing git hooks...
   ✅ Git hooks installed
✅ Go dependencies

━━━ Dashboard Requirements (React/TypeScript) ━━━

✅ Node.js 22.22.0
⚠️  Bun
   Optional for dashboard. Install: curl -fsSL https://bun.sh/install | bash

━━━ Summary ━━━

✅ Setup complete! Auto-installed missing components.

Next steps:
  go build ./cmd/pinchtab     # Build pinchtab
  go test ./...               # Run tests
```

The `doctor.sh` script will:
- ✅ Check Go 1.25+ (tells you to install if missing)
- ✅ Check golangci-lint (tells you to install if missing)
- 🔧 Auto-install git hooks
- 🔧 Auto-download Go dependencies

---

## Part 1: Prerequisites

### Install Go

**macOS (Homebrew):**
```bash
brew install go
go version  # Verify: go version go1.25.0
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install -y golang-go git build-essential
go version
```

**Linux (RHEL/CentOS):**
```bash
sudo yum install -y golang git
go version
```

**Or download from:** https://go.dev/dl/

### Install golangci-lint (Required)

Required for pre-commit hooks:

**macOS/Linux:**
```bash
brew install golangci-lint
```

**Or via Go:**
```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

Verify:
```bash
golangci-lint --version
```

### Install Chrome/Chromium

**macOS (Homebrew):**
```bash
brew install chromium
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt install -y chromium-browser
```

**Linux (RHEL/CentOS):**
```bash
sudo yum install -y chromium
```

### Automated Setup

After installing Go and golangci-lint, run:

```bash
git clone https://github.com/pinchtab/pinchtab.git
cd pinchtab
./doctor.sh
```

This verifies your environment and automatically:
- Installs git hooks (gofmt + golangci-lint on commit)
- Downloads Go modules
- Checks for optional tools (Node/Bun for dashboard)

You can run `./doctor.sh` anytime to verify or fix your environment.

---

## Part 2: Build the Project

### Simple Build

```bash
go build -o pinchtab ./cmd/pinchtab
```

**What it does:**
- Compiles Go source code
- Produces binary: `./pinchtab`
- Takes ~30-60 seconds

**Verify:**
```bash
ls -la pinchtab
./pinchtab --version
```

---

## Part 3: Run the Server

### Start (Headless)

```bash
./pinchtab
```

**Expected output:**
```
🦀 PINCH! PINCH! port=9867
auth disabled (set BRIDGE_TOKEN to enable)
```

### Start (Headed Mode)

```bash
BRIDGE_HEADLESS=false ./pinchtab
```

Opens Chrome in the foreground.

### Background

```bash
nohup ./pinchtab > pinchtab.log 2>&1 &
tail -f pinchtab.log  # Watch logs
```

---

## Part 4: Quick Test

### Health Check

```bash
curl http://localhost:9867/health
```

### Try CLI

```bash
./pinchtab quick https://example.com
./pinchtab nav https://github.com
./pinchtab snap
```

---

## Development

### Run Tests

```bash
go test ./...                              # All tests
go test ./... -v                           # Verbose
go test ./... -v -coverprofile=coverage.out
go tool cover -html=coverage.out           # View coverage
```

### Code Quality

```bash
gofmt -w .                # Format code
golangci-lint run         # Lint
./doctor.sh               # Verify environment
```

### Git Hooks

Git hooks are auto-installed by `./doctor.sh`. They run on every commit:
- `gofmt` — Format check
- `golangci-lint` — Linting

To manually reinstall hooks:
```bash
./scripts/install-hooks.sh
```

### Development Workflow

```bash
# 1. Create feature branch
git checkout -b feat/my-feature

# 2. Make changes
# ... edit files ...

# 3. Test
go test ./...

# 4. Commit (hooks run automatically)
git commit -m "feat: description"

# 5. Push
git push origin feat/my-feature

# 6. Create PR on GitHub
```

**Note:** Git hooks will automatically format and lint your code on commit. If checks fail, the commit is blocked.

---

## Continuous Integration

GitHub Actions automatically runs on push:
- Format checks (gofmt)
- Vet checks (go vet)
- Build verification
- Full test suite with coverage
- Linting (golangci-lint)

See `.github/workflows/` for details.

---

## Installation as CLI

### From Source

```bash
go build -o ~/go/bin/pinchtab ./cmd/pinchtab
```

Then use anywhere:
```bash
pinchtab help
pinchtab --version
```

### Via npm (released builds)

```bash
npm install -g pinchtab
pinchtab --version
```

---

## Resources

- **GitHub Repository:** https://github.com/pinchtab/pinchtab
- **Go Documentation:** https://golang.org/doc/
- **Chrome DevTools Protocol:** https://chromedevtools.github.io/devtools-protocol/
- **Chromedp Library:** https://github.com/chromedp/chromedp

---

## Troubleshooting

### Environment Issues

**First step:** Run doctor to verify your setup:
```bash
./doctor.sh
```

This will tell you exactly what's missing or misconfigured.

### Common Issues

**"Go version too old"**
- Install Go 1.25+ from https://go.dev/dl/
- Verify: `go version`

**"golangci-lint: command not found"**
- Install: `brew install golangci-lint`
- Or: `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`

**"Git hooks not running on commit"**
- Run: `./scripts/install-hooks.sh`
- Or: `./doctor.sh` (auto-installs)

**"Chrome not found"**
- Install Chromium: `brew install chromium` (macOS)
- Or: `sudo apt install chromium-browser` (Linux)

**"Port 9867 already in use"**
- Check: `lsof -i :9867`
- Stop other instance or use different port: `BRIDGE_PORT=9868 ./pinchtab`

**Build fails**
1. Verify dependencies: `go mod download`
2. Clean cache: `go clean -cache`
3. Rebuild: `go build ./cmd/pinchtab`

---

## Support

Issues? Check:
1. Run `./doctor.sh` first
2. All dependencies installed and correct versions?
3. Port 9867 available?
4. Check logs: `tail -f pinchtab.log`

See `docs/` for guides and examples.
