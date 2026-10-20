#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree.
W="$TMP/w"
mkdir -p "$W/sub" "$W/old" "$W/part"
printf 'alpha\nbravo\ncharlie\ndelta\necho\n' > "$W/a.txt"
cp "$W/a.txt" "$W/same.txt"
cp "$W/a.txt" "$W/old/a.txt"
printf 'alpha\nbravo\nX-ray\ndelta\necho\n' > "$W/part/a.txt"
printf 'alpha\nbravo\ncharlie\nDELTA\necho\n' > "$W/old/b.txt"
printf 'alpha\nBRAVO\ncharlie\ndelta\necho\n' > "$W/case.txt"
printf 'alpha\nbravo\nX-ray\ndelta\necho\n' > "$W/changed.txt"
printf 'alpha\nbravo\nnew 1\nnew 2\ncharlie\ndelta\necho\n' > "$W/inserted.txt"
printf 'alpha\ncharlie\ndelta\necho\n' > "$W/deleted.txt"
printf 'ALPHA\nbravo\ncharlie\ndelta\necho\n' > "$W/first.txt"
printf 'alpha\nbravo\ncharlie\ndelta\nend\n' > "$W/last.txt"
printf 'alpha\nbravo\n' > "$W/short.txt"
printf 'alpha\nB\ncharlie\ndelta\nE\n' > "$W/two.txt"
printf 'alpha\r\nbravo\r\ncharlie\r\ndelta\r\necho' > "$W/crlf.txt"
printf 'alpha\n  bravo \n charlie\t\n\tdelta\necho\n' > "$W/white.txt"
printf 'a\tb\n' > "$W/tab.txt"
printf 'a       b\n' > "$W/spaces.txt"
printf '1\n2\n3\n4\n5\n6\n7\n8\n9\n' > "$W/nine.txt"
printf '1\na\nb\nc\nd\n6\n7\n8\n9\n' > "$W/nine2.txt"
printf '1\n2\n3\n4\n' > "$W/four.txt"
printf '1\nX\n3\n4\n' > "$W/four2.txt"
: > "$W/empty.txt"
printf 'ab\x00c\xff' > "$W/x.bin"
printf 'aX\x00c\xfe!!' > "$W/y.bin"
cp "$W/x.bin" "$W/x2.bin"
printf 'ab\ncd\n' > "$W/sub/t.bin"
printf 'ab\nCD\n' > "$W/sub/u.bin"
printf '\xff\xfeH\x00i\x00\n\x00' > "$W/u1.txt"
printf '\xff\xfeH\x00o\x00\n\x00' > "$W/u2.txt"
printf 'x\xff\x00y\n' > "$W/raw1.txt"
printf 'x\xfe\x00y\n' > "$W/raw2.txt"
cd "$W"

ok=$'FC: no differences encountered\n\n'

# Help, version and syntax errors (ERRORLEVEL -1 is 255 on Linux).
help=$(printf '%s\n' \
'Compares two files or sets of files and shows the differences.' \
'' \
'FC [/A] [/C] [/L] [/LBn] [/N] [/OFF[LINE]] [/T] [/U] [/W] [/nnnn] file1 file2' \
'FC /B file1 file2' \
'' \
'  /A      Show only the first and last line of each run of differences.' \
'  /B      Compare byte by byte.' \
'  /C      Ignore case.' \
'  /L      Compare as text.' \
'  /LBn    Give up after n consecutive differing lines (default 100).' \
'  /N      Show line numbers.' \
'  /OFF    Accepted; there is no offline attribute.' \
'  /T      Do not expand tabs.' \
'  /U      Read the files as UTF-16LE text.' \
'  /W      Compress runs of spaces and tabs.' \
'  /nnnn   Lines that must match to resynchronise (default 2).')$'\n'
check_both "/? help"                 0 "$help" ''                 '/?'
check      "-? among files"          0 "$help"                    a.txt '-?' same.txt
check      "--help"                  0 "$help"                    --help
check      "--version"               0 $'fc (loup-cmd-fc) 0.1.0\n' --version
insufficient=$'FC: Insufficient number of file specifications\n'
check_both "no operand"              255 '' "$insufficient"
check_both "one operand"             255 '' "$insufficient"       a.txt
check_both "three operands"          255 '' $'FC: Too many file specifications\n' a.txt same.txt case.txt
check_both "bad /LB"                 255 '' $'FC: Invalid Switch\n' /LB0 a.txt same.txt
check_both "/0"                      255 '' $'FC: Invalid Switch\n' /0 a.txt same.txt

# Identical files.
check_both "identical"               0 $'Comparing files a.txt and SAME.TXT\n'"$ok" '' a.txt same.txt
check      "both empty"              0 $'Comparing files empty.txt and EMPTY.TXT\n'"$ok" empty.txt empty.txt
check      "CRLF and LF"             0 $'Comparing files a.txt and CRLF.TXT\n'"$ok" a.txt crlf.txt
check      "backslash path"          0 $'Comparing files old\\a.txt and A.TXT\n'"$ok" 'old\a.txt' a.txt

# Text differences: the last matching line, the differing lines and the
# first line of the resync point, for each file.
check_both "changed line"            1 'Comparing files a.txt and CHANGED.TXT
***** a.txt
bravo
charlie
delta
***** CHANGED.TXT
bravo
X-ray
delta
*****

' '' a.txt changed.txt
check      "inserted lines"          1 'Comparing files a.txt and INSERTED.TXT
***** a.txt
bravo
charlie
***** INSERTED.TXT
bravo
new 1
new 2
charlie
*****

' a.txt inserted.txt
check      "deleted line"            1 'Comparing files a.txt and DELETED.TXT
***** a.txt
alpha
bravo
charlie
***** DELETED.TXT
alpha
charlie
*****

' a.txt deleted.txt
check      "first line differs"      1 'Comparing files a.txt and FIRST.TXT
***** a.txt
alpha
bravo
***** FIRST.TXT
ALPHA
bravo
*****

' a.txt first.txt
check      "last line differs"       1 'Comparing files a.txt and LAST.TXT
***** a.txt
delta
echo
***** LAST.TXT
delta
end
*****

' a.txt last.txt
check      "second file shorter"     1 'Comparing files a.txt and SHORT.TXT
***** a.txt
bravo
charlie
delta
echo
***** SHORT.TXT
bravo
*****

' a.txt short.txt
check      "empty first file"        1 'Comparing files empty.txt and SHORT.TXT
***** empty.txt
***** SHORT.TXT
alpha
bravo
*****

' empty.txt short.txt
check      "two blocks"              1 'Comparing files a.txt and TWO.TXT
***** a.txt
alpha
bravo
charlie
***** TWO.TXT
alpha
B
charlie
*****

***** a.txt
delta
echo
***** TWO.TXT
delta
E
*****

' a.txt two.txt

# Switches.
check      "/N line numbers"         1 'Comparing files a.txt and INSERTED.TXT
***** a.txt
    2:  bravo
    3:  charlie
***** INSERTED.TXT
    2:  bravo
    3:  new 1
    4:  new 2
    5:  charlie
*****

' /N a.txt inserted.txt
check      "/A abbreviated"          1 'Comparing files a.txt and INSERTED.TXT
***** a.txt
bravo
charlie
***** INSERTED.TXT
bravo
...
charlie
*****

' /a a.txt inserted.txt
check      "/C ignores case"         0 $'Comparing files a.txt and CASE.TXT\n'"$ok" /C a.txt case.txt
check      "case differs without /C" 1 'Comparing files a.txt and CASE.TXT
***** a.txt
alpha
bravo
charlie
***** CASE.TXT
alpha
BRAVO
charlie
*****

' a.txt case.txt
check      "/W compresses blanks"    0 $'Comparing files a.txt and WHITE.TXT\n'"$ok" -w a.txt white.txt
check      "tabs are expanded"       0 $'Comparing files tab.txt and SPACES.TXT\n'"$ok" tab.txt spaces.txt
check      "/T keeps tabs"           1 $'Comparing files tab.txt and SPACES.TXT\n***** tab.txt\na\tb\n***** SPACES.TXT\na       b\n*****\n\n' /T tab.txt spaces.txt
check      "/LB3: resync failed"     1 'Comparing files nine.txt and NINE2.TXT
Resync Failed.  Files are too different.
***** nine.txt
1
2
3
4
***** NINE2.TXT
1
a
b
c
*****

' /LB3 nine.txt nine2.txt
check      "/LB4: resyncs"           1 'Comparing files nine.txt and NINE2.TXT
***** nine.txt
1
2
3
4
5
6
***** NINE2.TXT
1
a
b
c
d
6
*****

' /lb4 nine.txt nine2.txt
check      "/1 resyncs on one line"  1 'Comparing files four.txt and FOUR2.TXT
***** four.txt
1
2
3
***** FOUR2.TXT
1
X
3
*****

' /1 four.txt four2.txt
check      "/3: too few lines match" 1 'Comparing files four.txt and FOUR2.TXT
***** four.txt
1
2
3
4
***** FOUR2.TXT
1
X
3
4
*****

' /3 four.txt four2.txt
check      "/U UTF-16LE"             1 $'Comparing files u1.txt and U2.TXT\n***** u1.txt\nHi\n***** U2.TXT\nHo\n*****\n\n' /U u1.txt u2.txt
printf 'Comparing files raw1.txt and RAW2.TXT\n***** raw1.txt\nx\xff\x00y\n***** RAW2.TXT\nx\xfe\x00y\n*****\n\n' > "$TMP/raw"
check_file "bytes pass through"      1 "$TMP/raw"                 raw1.txt raw2.txt

# Binary mode: /B, or .EXE .COM .SYS .OBJ .LIB .BIN files.
check_both "/B differences"          1 $'Comparing files x.bin and Y.BIN\n00000001: 62 58\n00000004: FF FE\nFC: Y.BIN longer than x.bin\n\n' '' /B x.bin y.bin
check      ".bin is binary"          1 $'Comparing files y.bin and X.BIN\n00000001: 58 62\n00000004: FE FF\nFC: y.bin longer than X.BIN\n\n' y.bin x.bin
check      "binary identical"        0 $'Comparing files x.bin and X2.BIN\n'"$ok" x.bin x2.bin
check      "/B on text files"        1 $'Comparing files a.txt and CASE.TXT\n00000006: 62 42\n00000007: 72 52\n00000008: 61 41\n00000009: 76 56\n0000000A: 6F 4F\n\n' /b a.txt case.txt
check      "/L on .bin files"        1 $'Comparing files sub\\t.bin and SUB\\U.BIN\n***** sub\\t.bin\nab\ncd\n***** SUB\\U.BIN\nab\nCD\n*****\n\n' /L sub/t.bin 'sub\u.bin'

# Sets of files.
check      "directory as second"     0 $'Comparing files a.txt and OLD\\A.TXT\n'"$ok" a.txt old
cp a.txt b.txt
check      "wildcard and directory"  1 'Comparing files a.txt and OLD\A.TXT
FC: no differences encountered

Comparing files b.txt and OLD\B.TXT
***** b.txt
charlie
delta
echo
***** OLD\B.TXT
charlie
DELTA
echo
*****

' '?.txt' old
check      "wildcard template"       0 $'Comparing files old\\a.txt and A.TXT\n'"$ok" 'old\a.*' '*.txt'
check_both "no match"                2 '' $'FC: cannot open *.none - No such file or folder\n' '*.none' a.txt

# Files that cannot be opened (ERRORLEVEL 2).
check_both "first missing"           2 '' $'FC: cannot open nope.txt - No such file or folder\n' nope.txt a.txt
check_both "second missing"          2 '' $'FC: cannot open NOPE.TXT - No such file or folder\n' a.txt nope.txt
check_both "a directory"             2 '' $'FC: cannot open sub - No such file or folder\n' sub a.txt
check_both "unknown switch is a file" 2 '' $'FC: cannot open \\X - No such file or folder\n' /X a.txt
check_both "-- ends switches"        2 '' $'FC: cannot open \\5 - No such file or folder\n' -- /5 a.txt
check_both "one pair missing"        2 'Comparing files old\a.txt and PART\A.TXT
***** old\a.txt
bravo
charlie
delta
***** PART\A.TXT
bravo
X-ray
delta
*****

' $'FC: cannot open PART\\B.TXT - No such file or folder\n' 'old\*.txt' part

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
