#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(mktemp -d)/unlock-tests"
swiftc -swift-version 5 Sources/Core/*.swift Tests/main.swift -o "$OUT"
"$OUT"
