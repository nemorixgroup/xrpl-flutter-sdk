#!/usr/bin/env bash
# pre_commit.sh
# Run this before every commit. Must exit 0 before pushing.

set -e

echo -e "\033[0;36m==> Getting dependencies...\033[0m"
flutter pub get
if [ $? -ne 0 ]; then echo -e "\033[0;31mpub get failed\033[0m"; exit 1; fi

echo -e "\033[0;36m==> Checking formatting...\033[0m"
dart format --output=none --set-exit-if-changed .
if [ $? -ne 0 ]; then
    echo -e "\033[0;31mFormatting issues found. Run 'dart format .' to fix.\033[0m"
    exit 1
fi

echo -e "\033[0;36m==> Running static analysis...\033[0m"
flutter analyze --fatal-infos
if [ $? -ne 0 ]; then echo -e "\033[0;31mAnalysis failed\033[0m"; exit 1; fi

echo -e "\033[0;36m==> Running tests with coverage...\033[0m"
flutter test --coverage --concurrency=1
if [ $? -ne 0 ]; then echo -e "\033[0;31mTests failed\033[0m"; exit 1; fi

echo ""
echo -e "\033[0;32mAll checks passed. Safe to commit.\033[0m"
