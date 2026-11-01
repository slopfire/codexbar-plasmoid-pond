# CodexBar for Quickshell and Pond

CodexBar adds a usage card, provider dashboard and settings pages to the
Pond Quickshell sidebar. Pond supplies the
cards, fonts, colors, controls and page transitions. This directory contains
the CodexBar integration, not a second copy of the Pond desktop.

## Install

Install Pond, Quickshell, Node.js, Python 3 and Cargo first. Then run from the
repository root:

```sh
./scripts/install-quickshell.sh
```

The installer builds the Linux helper, copies the module into
`~/.config/quickshell/pond-shell/codexbar`, adds its hooks to Pond's
`Sidebar.qml` and `shell.qml`, and installs `~/.local/bin/codexbar-pond`.
Make sure `~/.local/bin` is on PATH. A running Pond shell reloads the files.
The installer does not restart the desktop or change settings or credentials.

For another Pond location, or to inspect planned actions:

```sh
./scripts/install-quickshell.sh --pond-dir /path/to/pond-shell --dry-run
./scripts/install-quickshell.sh --pond-dir /path/to/pond-shell
```

`XDG_CONFIG_HOME` selects the default Pond location. `--bin-dir PATH` changes
the command directory. `--skip-build` reuses a built or installed Linux
helper. `--native-binary PATH` supplies one explicitly.

The installer supports the current Pond layout and the existing CodexBar
integration from this project. It validates the hooks before writing files.
If a different Pond version has changed those hooks, it stops with an error.
Other Pond components and local files stay in place.

## Use

```sh
codexbar-pond start       # start Pond if it is not already running
codexbar-pond toggle      # open or close CodexBar on the focused output
codexbar-pond settings    # open CodexBar settings
codexbar-pond refresh     # refresh usage now
codexbar-pond doctor      # check programs, host files and installation
```

With no arguments, `codexbar-pond` runs `toggle`. `start` stays in the
foreground, so it can be used by Niri's startup configuration. If Pond already
starts with your session, keep that startup command. Bind `codexbar-pond
toggle` or `codexbar-pond settings` to a Niri shortcut if needed.

Install the upstream [CodexBar CLI](https://github.com/steipete/CodexBar), set
its path in General settings, or enable **Update managed CLI** there. Managed
updates are opt-in. The bundled Linux helper handles native provider access
and local cost scans; it does not replace the upstream CLI.

The sidebar shows provider logos, remaining usage rings and window labels.
Each usage ring has a tick for the time remaining in that window. Both use
the same clockwise scale. An arc that extends past the tick has reserve.
Hover or focus a provider to read the percentages, reset time and pace report.
Credits and reset counts have no time tick.
The drawer has provider tabs, full usage bars, spend and history. Its settings
button opens these pages:

- General has the CLI path, refresh interval, timeout, spend, credits and email masking. It also controls provider status requests, shared usage fetches, the cost refresh interval, retry attempts, failure cooldown and cost scan timeout.
- Providers has add, enable, disable, remove and reorder controls. Select a row to set the source and account, detect accounts or enter a masked API key. Antigravity has browser sign-in controls. Devin has an organization field. Bedrock uses existing AWS credentials.
- Appearance sets sidebar rows, rings per provider, the initial layout and the history chart. Choose separate or nested rings. Nested rings put the shortest window on the outside and work in provider rows, compact tiles and the collapsed rail. Inner rings can keep the same width or become thinner. Ring size, width and gap have controls. Widths and gaps scale down when needed to fit all rings. Icons, provider names, values, window labels and ring tracks have separate visibility controls. Hover and keyboard focus retain the usage details when text is hidden. Circular pace markers can use time, usage, provider or theme colors. They can also show a gap alone or be hidden.

Provider details show status descriptions and links, reset-credit expiry,
partial refresh errors and incomplete-history notes. The daily chart uses
spend when available, or tokens for a token-only series. Hover, click or focus
a day to read its models and unused limit resets. Arrow keys move between
days. Home and End select the first and last day.

Cross-device sync setup, multi-provider selection in the drawer and KDE tray
layout controls are not yet ported. Pond keeps its sidebar and page controls.

Apply saves and refreshes. Cancel keeps the current values. Settings live in
`$XDG_CONFIG_HOME/codexbar-plasmoid/config.json`, or
`~/.config/codexbar-plasmoid/config.json`. The file has owner-only read and
write permissions. Provider settings reach the helper through standard input,
so keys do not appear in process arguments. The installer never reads this
file. Existing CLI accounts and credentials stay where their providers store
them.

## Update and restore

After pulling changes, rerun `./scripts/install-quickshell.sh`. Installs are
idempotent. Each changed file is backed up before replacement under
`$XDG_STATE_HOME/codexbar-plasmoid/quickshell/backups`, or
`~/.local/state/codexbar-plasmoid/quickshell/backups`. The installer prints the
exact backup path.

To undo one install:

```sh
codexbar-pond restore /path/to/printed/backup
```

Restore checks that the installed files still match that install. It stops if
you edited them later. This protects newer Pond changes. It restores previous
files and removes only files created by that install. Settings stay unchanged.
Restore backups in reverse installation order.

## Preview and checks

These commands run from the checkout. They use Pond's components from the
installed directory but render the module in this repository.

```sh
./scripts/quickshell.sh preview
./scripts/quickshell.sh preview --virtual --output /tmp/codexbar-pond.png
./scripts/quickshell.sh check
./scripts/quickshell.sh check --ui
python3 -m unittest discover -s quickshell/tests
```

The first preview opens a window. `--virtual` captures the preview in isolated
KWin and closes that session. The output contains synthetic values, not live
accounts. `check` runs model, settings and process tests with disposable
profiles and fake CLIs. `--ui` adds pointer and layout tests in isolated KWin.
It requires `virt-shot`, KWin, and QtTest. No host window opens for checks.
Use `--pond-dir PATH` on preview, check or doctor for another host directory.

Tested with Quickshell 0.3.2 and Qt 6.11.2. Qt 6 lint reports the existing
Pond `state` overrides and Quickshell type metadata warnings. The runtime
checks validate the properties on the real engine.

## Source layout

| Path | Role |
|------|------|
| `pond-shell/codexbar/` | QML, presentation rules, settings, synthetic fixtures and tests. |
| `pond-shell/codexbar-preview.qml` | Synthetic preview and UI test entry point. |
| `manage.py` | Install, backup, restore, run and check commands. |
| `integrate.py` | Validated, idempotent Pond hooks. |
| `tests/` | Installer and integration regressions. |

Pond's helper retains its stdin transport, native lookup and sign-in modes.
It currently differs from KDE's helper in provider defaults and API-key
handling. Keep those differences covered by its settings tests when updating
it. The identical updater and retry modules are repository-relative symlinks
to `plasmoid/contents/code/`; the installer copies their resolved contents.
The Linux helper is built from `native-cli/` and installed beside the module.
No generated binary is committed.

## Provider refresh and retries

In Settings, open Providers and select a provider. Each provider can override
its refresh interval, retry attempts and maximum failure cooldown. Turn an
override off to use the General setting. Attempts include the first try.
Only temporary failures cause retries. Manual refresh updates all providers.

Pond polls at the shortest enabled provider interval. It keeps each provider's
reading until that provider's interval expires, then fetches it on the next
poll. Separate intervals still apply when shared fetches are off. Cooldowns
start at 30 seconds and increase up to the selected maximum.

OpenCode shows rolling, weekly and monthly subscription limits. If the sidebar
cannot fit every window, an exhausted window replaces a window with usage left.
The provider page shows all windows and their reset times.
