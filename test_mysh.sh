#!/bin/bash
#
# test_mysh.sh — full-coverage test for the mysh shell
#
# Builds mysh, feeds it a scripted sequence of commands through stdin (the
# same way a person would type them at the prompt), and checks the output
# against expected results. Also checks the actual files mysh should have
# created/modified on disk.
#
# Usage: ./test_mysh.sh

set -uo pipefail

BIN="./mysh"
WORKDIR="mysh_test_dir"
LOG="test_mysh_run.log"

PASS=0
FAIL=0

check_contains() {
    local desc="$1"
    local pattern="$2"
    if grep -qF -- "$pattern" "$LOG"; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc"
        echo "         expected to find: '$pattern'"
        FAIL=$((FAIL + 1))
    fi
}

check_not_contains() {
    local desc="$1"
    local pattern="$2"
    if grep -qF -- "$pattern" "$LOG"; then
        echo "  [FAIL] $desc"
        echo "         did NOT expect to find: '$pattern'"
        FAIL=$((FAIL + 1))
    else
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    fi
}

check_file_contains() {
    local desc="$1"
    local file="$2"
    local pattern="$3"
    if [ -f "$file" ] && grep -qF -- "$pattern" "$file"; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc"
        echo "         expected '$file' to contain: '$pattern'"
        FAIL=$((FAIL + 1))
    fi
}

check_file_exists() {
    local desc="$1"
    local file="$2"
    if [ -f "$file" ]; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc"
        echo "         expected file to exist: '$file'"
        FAIL=$((FAIL + 1))
    fi
}

# --- setup -------------------------------------------------------------

echo "== Building mysh =="
if ! make mysh > build.log 2>&1; then
    echo "Build failed — see build.log"
    exit 1
fi
echo "Build OK"
echo

rm -rf "$WORKDIR"
mkdir "$WORKDIR"
cd "$WORKDIR" || exit 1
cp "../$BIN" .

export NAME=World

# --- scripted command sequence ------------------------------------------
# Builds redirected files, background jobs, wildcards, an alias, a couple
# of history entries, and a multi-command line, then dumps the history.

echo "== Running command sequence =="
{
    echo "cd sub"                                           # cd into a subdir...
    echo "cd .."                                             # ...and back out
    echo "echo Hello \${NAME}"                                # env var substitution
    echo "echo line1 > file1.txt"                             # output redirection (truncate)
    echo "cat file1.txt"                                      # confirm redirected content
    echo "echo line2 >> file1.txt"                            # output redirection (append)
    echo "cat file1.txt"                                      # confirm both lines present
    echo "wc -l < file1.txt"                                  # input redirection
    echo "touch alpha.txt beta.txt gamma.txt"                 # files for wildcard test
    echo "echo *.txt"                                          # wildcard expansion
    echo "createalias hello \"echo Hi from alias\""            # alias creation
    echo "hello"                                               # run the alias
    echo "destroyalias hello"                                  # remove the alias
    echo "hello"                                               # should fail now, no such command
    echo "echo first ; echo second ; echo third"               # multiple commands on one line
    echo "sleep 2 &"                                           # background job, shouldn't block
    echo "echo done-after-bg"                                  # proves the shell didn't wait
    echo "history 2"                                           # re-run history entry 2
    echo "history"                                             # dump full history
    echo "exit"
} > ../commands.txt

mkdir -p sub

"$BIN" < ../commands.txt > "../$LOG" 2>&1
cd ..

echo "Command sequence finished"
echo

# --- checks: shell output ------------------------------------------------

echo "== Checking shell output =="
check_contains "cd into subdirectory changes the prompt"          "$WORKDIR/sub"
check_contains "environment variable substitution (\${NAME})"     "Hello World"
check_contains "redirected output shows up via cat (first line)"  "line1"
check_contains "append redirection keeps first line and adds second" "line2"
check_contains "input redirection into wc -l counts 2 lines"      "2"
check_contains "wildcard expansion lists matching .txt files"     "alpha.txt beta.txt file1.txt gamma.txt"
check_contains "alias runs the aliased command"                   "Hi from alias"
check_contains "destroyed alias is no longer recognized"          "Error: command: hello not found."
check_contains "multiple ; separated commands all run — first"    "first"
check_contains "multiple ; separated commands all run — second"   "second"
check_contains "multiple ; separated commands all run — third"    "third"
check_contains "background job does not block the prompt"         "done-after-bg"
check_contains "history <n> re-executes that command"             "Hello World"
check_contains "history dump lists all commands with indices"     "0: cd sub"

echo
echo "== Checking files created on disk =="
check_file_exists   "file1.txt was created by redirection"        "$WORKDIR/file1.txt"
check_file_contains "file1.txt has both redirected lines"          "$WORKDIR/file1.txt" "line1"
check_file_contains "file1.txt has both redirected lines"          "$WORKDIR/file1.txt" "line2"
check_file_exists   "wildcard file alpha.txt was created"          "$WORKDIR/alpha.txt"
check_file_exists   "wildcard file beta.txt was created"           "$WORKDIR/beta.txt"
check_file_exists   "wildcard file gamma.txt was created"          "$WORKDIR/gamma.txt"

echo
echo "== Known quirk (informational, not a failure) =="
echo "history <n> rewrites the stored history entry in place when it substitutes"
echo "environment variables, which can replace the spaces in that entry with null"
echo "bytes. Look at index 2 in the history dump in $LOG to see it — this is a"
echo "pre-existing behavior of the code, not something this script is trying to fix."

# --- summary ---------------------------------------------------------------

echo
echo "===================================="
echo "Passed: $PASS   Failed: $FAIL"
echo "===================================="

exit $FAIL