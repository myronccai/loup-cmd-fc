# Design: fc

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them
(`cli.args`, on top of the shared `win.switches`), handles `/?` and
`--version`, and calls `commands.fc.run_fc`. `run_fc` turns the two operands
into pairs of files (`plan_pairs`), and for each pair that can be opened
prints `Comparing files A and B` and the lines of a `Report` built by the text
or the binary comparison. Every comparison is a pure function from file
contents to a `Report` (lines plus a "different" flag), so the unit tests
check fc's exact output without capturing standard output.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, ERRORLEVELs (0, 1, 2, 255 for -1) |
| `source/cli/args.loup` | `Options`, `fc_switches()`, `/nnnn` pre-scan, `parse_args` |
| `source/cli/usage.loup` | `usage()` (the `/?` summary of syntax and switches), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 2 |
| `source/commands/fc.loup` | `plan_pairs`, `second_path`, `apply_template`, `binary_pair`, `compare_pair`, `run_fc` |
| `source/commands/textcompare.loup` | `prepare_text`, `find_resync`, `compare_text`: the resync algorithm and block output |
| `source/commands/bincompare.loup` | `compare_bytes`, hex formatting, `is_binary_name` |
| `source/commands/lines.loup` | `split_lines`, `expand_tabs`, `compress_white`, `line_key`, UTF-16LE decoding |
| `source/commands/report.loup` | `Report` and `make_report` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### Command line

The shared parser cannot declare `/nnnn` (a number as the switch name), so
`parse_args` first takes every `/digits` or `-digits` token before `--` out
of the argument list (the last one counts), then parses the rest with
`flag` switches `A B C L N T U W OFF OFFLINE` and `glued_value("LB",
"0123456789")` (`/LB5`, `/LB:5`, `/LB 5`). A `/B` or `/L` later on the line
overrides an earlier one.

### Text comparison (fc's algorithm)

`prepare_text` splits the file into lines (LF, CR dropped), expands tabs
unless `/T`, and computes each line's key (`/W` compresses blanks, `/C`
upper-cases). `compare_text` then:

1. advances through both files while the keys match;
2. at a mismatch at lines *i*, *j*, calls `find_resync`: for distances
   *s* = 1, 2, ... it tries every *(x, y)* with *(x − i) + (y − j) = s*,
   fewer lines skipped in file 1 first, with at most `/LBn` lines skipped on
   each side, and returns the first where `/nnnn` consecutive keys match;
3. prints the block: from the line before the mismatch (the last matching
   line; none at the start of the files) through the first resync line, in
   each file; with `/A` a run longer than two lines becomes first, `...`,
   last; with `/N` each line is `%5d:  text`;
4. continues from the resync point.

Without a resync point: if the rest of both files fits in the buffer, or
one file has ended, the block holds the rest of both files; otherwise fc
prints `Resync Failed.  Files are too different.` and the block of the
lines it looked at (`/LBn` past the mismatch) and stops.

Unlike diff's Myers algorithm, this is greedy and local: it never revisits
a resync point, a short common run (fewer than `/nnnn` lines) is reported
as a difference, and the output always repeats one line of context on each
side of a change.

### Binary comparison

`compare_bytes` walks the common length and prints `%08X: %02X %02X` for
each differing byte, then `FC: A longer than B` for a longer file, or
`FC: no differences encountered`; a blank line ends the result. Binary
mode applies with `/B` or, unless `/L`, when either name ends in `.EXE`,
`.COM`, `.SYS`, `.OBJ`, `.LIB` or `.BIN`.

### Sets of files

`plan_pairs` expands a wildcard first operand with `win.wildcard.expand`
(files only, name order). `second_path` maps each first file to its partner:
a directory operand (or one ending in a separator) gives the same name in
that directory; a wildcard name is a template applied part by part (base and
extension: `*` copies the rest of the source part, `?` one character, a
literal replaces one); anything else is used as is.

### Native-build notes

- A struct holding a list (`TextFile`, `Options`) passed to a function is
  deep-copied on every call in native builds, so the hot helpers
  (`run_matches`, `find_resync`, `dump`, `format_line`) take lists and
  scalars; `compare_text` unpacks the structs once.
- Structs are built only in their defining modules (`make_report`,
  `default_options`, `make_pair`).
- `readText` returns a file's bytes unchanged natively, so invalid UTF-8 and
  NUL bytes are compared and printed as they are.

## Differences from the original

- The second name is shown in upper case and the first as typed, as fc
  does; on Linux the names stay case-sensitive for opening files.
- The resync search order (nearest by total distance, fewer lines skipped in
  file 1 first) and the exact size of the look-ahead window are this
  implementation's reading of fc's documented behaviour; on files with
  several equally near resync points Windows may choose another.
- `Resync Failed` shows `/LBn` lines past the mismatch (plus the context
  line); Windows shows its buffer contents, which may differ slightly.
- Lines are not truncated at 127 characters; there is no Ctrl-Z end of file
  in text mode; `/U` decodes UTF-16LE and prints UTF-8 rather than using the
  console code page; `/OFF[LINE]` is accepted and has no effect.
- Name templates for the second operand use the simple part-by-part DOS
  rule, not every corner of cmd's ren algorithm.
- Messages go to standard error and end with LF; the comparison output goes
  to standard output.
- An unreadable file (permissions) ends the program with the toolchain's
  `IoError` message: Loup 1.26.0 has no `stat()` and a native `IoError`
  cannot be caught.
- `/?` prints a short summary written for this project, not Windows' text.
- ERRORLEVEL -1 is exit status 255 on Linux. `--help` and `--version` alone
  are series conventions.

## Error handling

Syntax errors stop before any comparison (status 255). A pair whose file
cannot be opened is reported and skipped; the status is then 2. Otherwise
the status is 1 if any pair differs. An unexpected exception is printed on
standard error and gives status 2.

## Testing

- `tests/args_test.loup`: switches in any case and prefix, `/LBn`, `/nnnn`,
  mode precedence, `--`, help and version.
- `tests/lines_test.loup`: line splitting, tab expansion, `/W`, `/C` keys,
  UTF-16LE.
- `tests/textcompare_test.loup`: the full output for changes, insertions,
  deletions, differences at either end, two blocks, `/nnnn`, `/LBn` and
  `Resync Failed`, `/A`, `/N`, `/C`, `/W`, `/T`, and the search order.
- `tests/bincompare_test.loup`: hex formatting, differing bytes, longer
  files, binary extensions.
- `tests/fc_test.loup`: name templates, directory and wildcard pairing.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: runs the native binary in a fixture tree under `$TMP` and
  compares standard output byte for byte, standard error and the status.
