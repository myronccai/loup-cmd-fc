# loup-cmd-fc

The Windows `fc` command recreated in [Loup](https://code-craft.ai/references/loup):
compare two files, or two sets of files, in text mode with fc's own
resynchronisation algorithm or byte by byte in binary mode, with cmd's
switches, output format, messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type), and is meant to
be read next to [loup-cmd-diff](https://github.com/myronccai/loup-cmd-diff):
fc's greedy look-ahead resync is a different algorithm from diff's Myers
shortest edit script.

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                       # native binary: build/fc
make ci                          # check, unit tests, build, end-to-end tests
make run ARGS="a.txt b.txt"      # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ build/fc 'demo\old.txt' 'demo\new.txt'; echo "ERRORLEVEL $?"
Comparing files demo\old.txt and DEMO\NEW.TXT
***** demo\old.txt
bananas
cherries
***** DEMO\NEW.TXT
bananas
blueberries
cherries
*****

***** demo\old.txt
dates
elderberries
figs
grapes
***** DEMO\NEW.TXT
dates
FIGS
grapes
*****

ERRORLEVEL 1
```

Each block shows, for each file, the last line that still matched, the
lines that differ, and the first line where the files agree again. fc needs
two consecutive matching lines (`/nnnn`) to resynchronise, so the single
matching `grapes` at the end of the second block counts as a difference.

```text
$ build/fc /N 'demo\old.txt' 'demo\new.txt'
Comparing files demo\old.txt and DEMO\NEW.TXT
***** demo\old.txt
    2:  bananas
    3:  cherries
***** DEMO\NEW.TXT
    2:  bananas
    3:  blueberries
    4:  cherries
*****

***** demo\old.txt
    4:  dates
    5:  elderberries
    6:  figs
    7:  grapes
***** DEMO\NEW.TXT
    5:  dates
    6:  FIGS
    7:  grapes
*****

$ build/fc /C /A 'demo\old.txt' 'demo\new.txt'
Comparing files demo\old.txt and DEMO\NEW.TXT
***** demo\old.txt
bananas
cherries
***** DEMO\NEW.TXT
bananas
...
cherries
*****

***** demo\old.txt
dates
...
figs
***** DEMO\NEW.TXT
dates
FIGS
*****

$ build/fc 'demo\*.txt' 'demo\backup'; echo "ERRORLEVEL $?"
FC: cannot open DEMO\BACKUP\NEW.TXT - No such file or folder
Comparing files demo\old.txt and DEMO\BACKUP\OLD.TXT
FC: no differences encountered

ERRORLEVEL 2
$ build/fc demo/app.bin demo/app2.bin
Comparing files demo\app.bin and DEMO\APP2.BIN
00000004: 03 04
FC: DEMO\APP2.BIN longer than demo\app.bin

$ build/fc 'demo\old.txt'; echo "ERRORLEVEL $?"
FC: Insufficient number of file specifications
ERRORLEVEL 255
$ build/fc --version
fc (loup-cmd-fc) 0.1.0
```

## Switches

| Switch | Meaning |
|---|---|
| `/A` | Abbreviated: each run of more than two lines in a block shows only its first line, `...` and its last line |
| `/B` | Binary comparison: `OFFSET: AA BB` for every differing byte, then `FC: A longer than B` if the sizes differ |
| `/C` | Ignore case |
| `/L` | Text comparison, also for `.EXE`, `.COM`, `.SYS`, `.OBJ`, `.LIB` and `.BIN` files (compared in binary by default) |
| `/LBn` | At most *n* consecutive differing lines (default 100); beyond that, `Resync Failed.  Files are too different.` |
| `/N` | Line numbers (`    7:  text`) |
| `/OFF[LINE]` | Accepted; Linux has no offline attribute |
| `/T` | Do not expand tabs (by default they become spaces to the next multiple of 8, for comparison and display) |
| `/U` | Read both files as UTF-16LE |
| `/W` | Compare with runs of spaces and tabs reduced to one, and none at either end of a line |
| `/nnnn` | Lines that must match to resynchronise (default 2) |
| `/?` | Help |

Switches start with `/` or `-` and may be in any case (`/n`, `-N`); the later
of `/B` and `/L` wins. A `/X` that is not one of these is a file name, and
`--` ends switch parsing. The first operand may use `*` and `?` (Windows
rules, name order); the second may be a directory (compare with the file of
the same name in it) or a wildcard template (`fc *.txt *.bak` compares
`a.txt` with `a.bak`). The first name is shown as typed and the second in
upper case, as fc does.

Exit status (ERRORLEVEL): `0` the files are the same, `1` they differ, `2` a
file could not be opened, `255` (Windows' -1) a syntax error.

## Differences from the original

- Names: the second name is printed in upper case like Windows, but files
  are opened with their real, case-sensitive Linux names; paths are printed
  with `\`.
- The resync search tries candidates by total distance from the mismatch
  (fewer lines skipped in the first file first) within `/LBn` lines on each
  side. When several resync points are equally near, Windows may pick a
  different one, and its `Resync Failed` block shows its internal buffer,
  which can differ slightly from the `/LBn` lines shown here.
- Long lines are not split at 127 characters, and Ctrl-Z does not end a
  text file.
- `/U` converts UTF-16LE to UTF-8 rather than to the console code page;
  other files are compared and printed byte for byte (invalid UTF-8 and NUL
  bytes included).
- `/OFF[LINE]` has no effect.
- A wildcard template for the second name uses the simple DOS rule (base
  and extension separately: `*` copies the rest, `?` one character, a
  literal replaces one), not every corner of cmd's `ren` algorithm.
- `Too many file specifications` (three or more names) and `Invalid Switch`
  (`/LB0`, `/0`, `/LB` without a number) are this implementation's wording.
- Messages go to standard error and end with LF; comparison output goes to
  standard output.
- An unreadable file (permissions) stops the program with the toolchain's
  `IoError` message: Loup 1.26.0 has no `stat()`, and a native `IoError`
  cannot be caught.
- `/?` prints a short summary of the syntax and switches written for this
  project, not Windows' own help text.
- ERRORLEVEL -1 is exit status 255 on Linux. `--help` and `--version` as
  the only argument are series conventions.

## Layout

```text
source/main.loup                  # entry point
source/appinfo.loup               # name, version, ERRORLEVELs
source/cli/args.loup              # fc's switches via win.switches, plus /nnnn
source/cli/usage.loup             # /? and --version text
source/cli/app.loup               # run(): parse, dispatch, exit status
source/commands/fc.loup           # pairs of files (wildcards, directories, templates), run_fc
source/commands/textcompare.loup  # the resync algorithm and the ***** blocks
source/commands/bincompare.loup   # /B: OFFSET: AA BB
source/commands/lines.loup        # line splitting, tabs, /W and /C keys, UTF-16LE
source/commands/report.loup       # the result of one comparison
source/win/                       # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup                 # unit tests (make test)
tests/e2e.sh                      # end-to-end tests of build/fc (make e2e)
specs/fc/                         # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
