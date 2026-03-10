#!/bin/bash
set -o nounset
set -o errexit

# Clean and create dist directory
rm -rf dist
mkdir -p dist

# Copy all files to dist, excluding .git
rsync -a --exclude='.git' ./ dist/

# Detect OS to handle sed -i compatibility (macOS requires '' as backup suffix, Linux does not)
if [[ "$(uname)" == "Darwin" ]]; then
    SED_INPLACE=(-i '')
else
    SED_INPLACE=(-i)
fi

# Replace all occurrences of the old import path with the new one in files under dist
find dist -type f -name "*.go" -exec sed "${SED_INPLACE[@]}" 's|github\.com/pinchtab/pinchtab/internal|github.com/pinchtab/pinchtab/pkg|g' {} +

# Replace all occurrences of "github.com/pinchtab/pinchtab" with "github.com/zboya/pinchtab"
find dist -type f -name "*.go" -exec sed "${SED_INPLACE[@]}" 's|github\.com/pinchtab/pinchtab|github.com/zboya/pinchtab|g' {} +

# Also update go.mod module path
if [ -f dist/go.mod ]; then
    sed "${SED_INPLACE[@]}" 's|github\.com/pinchtab/pinchtab|github.com/zboya/pinchtab|g' dist/go.mod
fi

# Rename the internal directory to pkg
if [ -d dist/internal ]; then
    mv dist/internal dist/pkg
fi
