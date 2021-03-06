#!/bin/sh
set -eu

# Copyright 2017 The Rust Project Developers. See the COPYRIGHT
# file at the top-level directory of this distribution and at
# http://rust-lang.org/COPYRIGHT.
#
# Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
# http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
# <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
# option. This file may not be copied, modified, or distributed
# except according to those terms.

# Performs `cat` and `grep` simultaneously for `run-make` tests in the Rust CI.
#
# This program will read lines from stdin and print them to stdout immediately.
# At the same time, it will check if the input line contains the substring or
# regex specified in the command line. If any match is found, the program will
# set the exit code to 0, otherwise 1.
#
# This is written to simplify debugging runmake tests. Since `grep` swallows all
# output, when a test involving `grep` failed, it is impossible to know the
# reason just by reading the failure log. While it is possible to `tee` the
# output into another stream, it becomes pretty annoying to do this for all test
# cases.

USAGE='
cat-and-grep.sh [-v] [-e] [-i] s1 s2 s3 ... < input.txt

Prints the stdin, and exits successfully only if all of `sN` can be found in
some lines of the input.

Options:
    -v      Invert match, exits successfully only if all of `sN` cannot be found
    -e      Regex search, search using extended Regex instead of fixed string
    -i      Case insensitive search.
'

GREPPER=fgrep
INVERT=0
GREPFLAGS='q'
while getopts ':vieh' OPTION; do
    case "$OPTION" in
        v)
            INVERT=1
            ERROR_MSG='should not be found'
            ;;
        i)
            GREPFLAGS="i$GREPFLAGS"
            ;;
        e)
            GREPPER=egrep
            ;;
        h)
            echo "$USAGE"
            exit 2
            ;;
        *)
            break
            ;;
    esac
done

shift $((OPTIND - 1))

LOG=$(mktemp -t cgrep.XXXXXX)
trap "rm -f $LOG" EXIT

printf "[[[ begin stdout ]]]\n\033[90m"
tee "$LOG"
echo >> "$LOG"   # ensure at least 1 line of output, otherwise `grep -v` may unconditionally fail.
printf "\033[0m\n[[[ end stdout ]]]\n"

HAS_ERROR=0
for MATCH in "$@"; do
    if "$GREPPER" "-$GREPFLAGS" -- "$MATCH" "$LOG"; then
        if [ "$INVERT" = 1 ]; then
            printf "\033[1;31mError: should not match: %s\033[0m\n" "$MATCH"
            HAS_ERROR=1
        fi
    else
        if [ "$INVERT" = 0 ]; then
            printf "\033[1;31mError: cannot match: %s\033[0m\n" "$MATCH"
            HAS_ERROR=1
        fi
    fi
done

exit "$HAS_ERROR"
