# Developer notes

## Layout

- `plugin/quint_infoview.lua`: the `:QuintInfo` command.
- `lua/quint_infoview/init.lua`: setup, autocmds, running Quint, ghost text and diagnostics.
- `lua/quint_infoview/parse.lua`: Quint's text output to a summary (`check`) and test results (`tests`).
- `lua/quint_infoview/itf.lua`: ITF traces to steps, values rendered as Quint literals.
- `lua/quint_infoview/source.lua`: modules and declarations by line, main-module choice, block extent.
- `lua/quint_infoview/panel.lua`: the panel buffer, its content, jumps and step highlighting.
- `lua/quint_infoview/health.lua`: `:checkhealth quint_infoview`.

## What Quint gives us

| Fact | Source | Notes |
|---|---|---|
| ok / violation / warning / error | text: `[status] headline` | `warning` = no violation but an observation was never reached |
| violated invariants | text: `  ❌ name` | only the violated ones are listed on a violation |
| checked invariants | text: `Checked invariants: a, b` | printed on ok and warning only |
| observation counts | text: `name was observed in n trace(s) out of m explored (p%)` | |
| tests | text: `ok name passed`, `n) name failed`, then `Error [QNTxxx]: msg` and `at file:line:col` | |
| error location | text: first `at file:line:col` | type errors have no `[status]` line |
| counterexample | ITF from `--out-itf`, with `mbt::actionTaken` and `mbt::nondetPicks` from `--mbt` | `quint verify` traces have no `mbt::` variables |

`--out <file>` JSON has the status and the trace but not the violated invariant or the observation counts (0.34, 0.35), which is why the summary comes from the text. With `--out-itf`, `quint run` stops printing the `--seed` line, so the panel shows no seed.

On a violation, invariants of the main module that are not listed as violated are shown as "held until the run stopped": they held in every state explored before the stop, but the run did not finish.

## Tests

```sh
./scripts/test.sh              # all tests; integration tests need quint on PATH
./scripts/test.sh parse:       # filter by "file: name" prefix
QUINT=/path/to/quint ./scripts/test.sh integration
```

- `tests/*_spec.lua` return tables of named cases; `tests/run.lua` runs them in headless Neovim with no config.
- Unit tests read real Quint output from `tests/fixtures/quint-<version>/` for every version present.
- Integration tests copy `tests/fixtures/spec/` to a temporary directory, save buffers and wait for Quint, then check the panel, ghost text, diagnostics, step highlighting and `<CR>` jumps. The verify case needs `java`.

## Supporting a new Quint version

```sh
QUINT=/path/to/quint-x.y.z ./scripts/fixtures.sh
./scripts/test.sh
```

Then add the version to `M.tested` in `lua/quint_infoview/health.lua`.
