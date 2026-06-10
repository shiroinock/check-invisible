# check-invisible

Zero-dependency shell scanner for suspicious invisible Unicode characters in source repositories.

It is designed for quick supply-chain hygiene checks, including GlassWorm-style hiding with Unicode variation selectors, without requiring npm, Python, Ruby, Go, Rust, or any package install.

## Usage

```sh
./check-invisible.sh
./check-invisible.sh --glassworm
./check-invisible.sh --all path/to/file-or-directory
```

When run inside a Git repository with no path arguments, it scans `git ls-files`.
Outside Git, it scans the current directory recursively while skipping common generated directories such as `.git`, `node_modules`, `vendor`, `dist`, `build`, and `target`.

## Modes

`--glassworm` detects only Unicode variation selectors:

- `U+FE00..U+FE0F`
- `U+E0100..U+E01EF`

`--all` is the default and detects broader invisible/control characters:

- ASCII and C1 control characters, excluding common line structure handled by the shell reader
- non-breaking spaces and unusual Unicode spaces
- zero-width characters
- bidi controls
- Unicode tag/control characters
- BOM / zero-width no-break space
- GlassWorm-style variation selectors

## Output

Findings are printed as:

```text
path:line:column: U+CODEPOINT [reason]
```

Example:

```text
src/example.js:12:18: U+FE00 [glassworm variation selector]
```

The command exits with:

- `0` when no suspicious characters are found
- `1` when findings are found
- `2` for usage or scanner errors

## CI

Add this to a repository and run it from CI:

```sh
./check-invisible.sh --all
```

For a lower-noise GlassWorm-focused check:

```sh
./check-invisible.sh --glassworm
```

## Notes

Some repositories may legitimately contain certain invisible characters in localization files, typography fixtures, or Unicode tests. In that case, run the script on stricter paths such as `src/`, or keep explicit fixture files outside the scanned set.

## License

MIT
