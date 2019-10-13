#!/bin/bash
set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
readonly REPO_DIR="$(dirname "$SCRIPT_DIR")"

wget https://github.com/google/google-java-format/releases/download/google-java-format-1.3/google-java-format-1.3-all-deps.jar
java -jar google-java-format-1.3-all-deps.jar --replace `find ${REPO_DIR} -name "*.java"`
[[ -z "`git ls-files --modified`" ]] || (
    echo "Formatting failed."
    echo "Please follow the instructions on https://github.com/google/google-java-format"
    echo "The expected file formatting is:";
    git diff

    exit 1
)
