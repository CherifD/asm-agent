#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."
mkdir -p bin build

clang -arch arm64 asm/main.s -o bin/asm-agent
chmod +x bin/asm-agent
