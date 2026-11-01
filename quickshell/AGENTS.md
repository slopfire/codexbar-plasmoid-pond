# Quickshell integration

This directory contains the CodexBar module for Pond. It is not a Plasma applet.
Use Pond's Theme, Card, CardStack and controls. Do not apply Kirigami-only rules.

- `pond-shell/codexbar/` is the source module. Keep captured account data and credentials out of this tree.
- `pond-shell/codexbar-preview.qml` uses synthetic data. Pond supplies its host components.
- `manage.py` installs the module and `integrate.py` adds validated Pond hooks. Preserve other Pond code and the user's settings.
- The helper retains Pond-specific stdin and sign-in behavior. The updater and resilience module link to the Plasma sources. Installers dereference those links.
- Use `/usr/lib64/qt6/bin/qmllint` on this host. The `qmllint` on PATH is the old Qt 5 tool.

Check with `./scripts/quickshell.sh check --ui`. This runs pointer and layout
checks in isolated KWin. Do not start or capture the host shell for tests.
Run `python3 -m unittest discover -s quickshell/tests` after installer changes.
