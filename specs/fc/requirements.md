# Requirements: fc

## Introduction

`fc` is the Windows command that compares two files, or two sets of files,
and shows the differences. In text mode it does not compute a shortest edit
script the way `diff` does: it walks both files in step and, after a
mismatch, looks ahead for the nearest place where a few lines match again
(its *resynchronisation*), within a buffer of lines. In binary mode it lists
every differing byte. This repository recreates it in Loup for Linux, with
Windows' switches, output format, messages and ERRORLEVELs, as a deliberate
contrast with `loup-cmd-diff` (Myers' algorithm). It uses the shared Windows
code in `source/win/` (switch parser, wildcards, paths, messages).

## Requirements

### Requirement 1: Text comparison

**User Story:** As a cmd user, I want `fc a.txt b.txt` to show which lines
differ so that I can see what changed.

#### Acceptance Criteria

1. THE program SHALL print `Comparing files NAME1 and NAME2` before each
   comparison, with the first name as typed and the second in upper case,
   paths with `\`.
2. WHEN the files have the same lines, THE program SHALL print
   `FC: no differences encountered` and a blank line, and exit 0.
3. WHEN lines differ, THE program SHALL find the nearest resync point: the
   first place, by total distance from the mismatch, where the number of
   consecutive lines set by `/nnnn` (default 2) match in both files.
4. FOR each set of differences, THE program SHALL print `***** NAME1`, the
   last matching line before the difference (if any), the differing lines of
   file 1 and the first line of the resync point; the same for file 2 after
   `***** NAME2`; then `*****` and a blank line; and exit 1.
5. WHEN fewer lines than `/nnnn` match before the end, THE program SHALL show
   them as differences; WHEN the differences run to the end of both files, or
   one file has ended, the block SHALL hold the rest of both files.
6. WHEN more lines than `/LBn` (default 100) differ in a row and the files go
   on, THE program SHALL print `Resync Failed.  Files are too different.`, the
   block of lines it examined, and stop comparing that pair.
7. Lines end at LF; a CR before the LF SHALL be ignored, and a last line
   without a line end SHALL count as a line. File bytes SHALL be printed
   unchanged.

### Requirement 2: Text options

**User Story:** As a cmd user, I want fc's text switches so that I can
control what counts as a difference and how it is shown.

#### Acceptance Criteria

1. `/A` SHALL shorten each run of more than two lines in a block to its
   first line, `...` and its last line.
2. `/C` SHALL compare without regard to case.
3. `/N` SHALL prefix each shown line with its number, right-aligned in five
   columns, followed by `:` and two spaces.
4. `/W` SHALL compare with each run of spaces and tabs reduced to one space
   and none at the start or end of a line.
5. Tabs SHALL be expanded to spaces (stops every 8 columns) for comparison
   and display; `/T` SHALL keep them.
6. `/LBn` SHALL set the buffer (maximum consecutive differing lines) and
   `/nnnn` the number of lines needed to resynchronise; zero or a malformed
   value SHALL be a syntax error.
7. `/U` SHALL read both files as UTF-16LE (with or without a byte order
   mark) and show the text as UTF-8.
8. `/OFF` and `/OFFLINE` SHALL be accepted (there is no offline attribute).

### Requirement 3: Binary comparison

**User Story:** As a cmd user, I want `fc /B` to tell me which bytes differ.

#### Acceptance Criteria

1. WHEN `/B` is given, or either file name ends in `.EXE`, `.COM`, `.SYS`,
   `.OBJ`, `.LIB` or `.BIN` (any case) and `/L` is not given, THE program
   SHALL compare byte by byte; the later of `/B` and `/L` wins.
2. FOR each differing byte THE program SHALL print `OFFSET: AA BB`, the
   offset in eight upper-case hexadecimal digits and the two bytes in two.
3. WHEN one file is longer, THE program SHALL print `FC: LONGER longer than
   SHORTER` after the differences of the common part.
4. WHEN the files are identical, THE program SHALL print
   `FC: no differences encountered`. Every binary result SHALL end with a
   blank line.

### Requirement 4: Sets of files

**User Story:** As a cmd user, I want `fc *.txt backup` to compare several
files in one command.

#### Acceptance Criteria

1. WHEN the first operand has `*` or `?` in its last component, THE program
   SHALL compare every matching file, in name order (Windows wildcard rules).
2. WHEN the second operand is a directory (or ends with a separator), THE
   program SHALL compare with the file of the same name in it.
3. WHEN the second operand has wildcards in its last component, THE program
   SHALL build the second name from the first file's name, part by part
   (`*.bak` with `a.txt` gives `a.bak`).
4. Operands SHALL accept `\` and `/` as separators.

### Requirement 5: Errors and exit statuses

**User Story:** As a script author, I want fc's ERRORLEVELs so that batch
logic ported to this command behaves the same.

#### Acceptance Criteria

1. WHEN fewer than two file names are given, THE program SHALL print
   `FC: Insufficient number of file specifications` on standard error and
   exit with -1 (255); WHEN more than two, `FC: Too many file
   specifications`; WHEN a switch value is invalid, `FC: Invalid Switch`.
2. WHEN a file cannot be opened (missing, a directory, or no wildcard
   match), THE program SHALL print `FC: cannot open NAME - No such file or
   folder` on standard error, go on with the next pair, and exit 2.
3. OTHERWISE THE program SHALL exit 1 if any pair differs and 0 if none
   does.
4. WHEN `/?` or `-?` appears among the arguments, THE program SHALL print
   a short help text (syntax and switches) and exit 0. `--version` alone
   SHALL print `fc (loup-cmd-fc) 0.1.0`; `--help` alone SHALL print the
   help.
5. A `/X` that is not one of fc's switches SHALL be a file name, as SHALL
   every argument after `--`.
