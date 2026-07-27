# Repository Guidelines

## Project Structure & Module Organization

Rabbit is a Windows Rime frontend written for AutoHotkey v2. `Rabbit.ahk` is the main entry point; `RabbitDeployer.ahk` handles installation and maintenance workflows. First-party modules live in `Lib/` and use the `Rabbit*.ahk` naming pattern. `schemas/rabbit.yaml` defines the bundled Rime schema, while `assets/` contains source SVG icons. `Data/` and `Rime/` are generated or runtime data and are intentionally ignored.

Three directories are Git submodules: `Lib/librime-ahk`, `Lib/Direct2D`, and `plum`. Avoid mixing upstream submodule changes with application changes.

Keep entry scripts readable as startup outlines: directives, direct includes, top-level state, the main workflow, and shutdown handling belong there. Move input processing, runtime state, dialogs, settings models, and other implementation details into cohesive `Lib/Rabbit*.ahk` modules. Give each substantial independent class its own file; keep small helpers with the feature they exclusively support. Every module must declare its direct `#Include` dependencies rather than relying on an entry script's include order.

## Build, Test, and Development Commands

Run commands from PowerShell on Windows:

```powershell
git submodule update --init --recursive
AutoHotkey.exe Rabbit.ahk
AutoHotkey.exe RabbitDeployer.ahk
```

The first command obtains required dependencies. The latter commands launch the frontend and deployer directly from source with AutoHotkey v2.0.19, the version pinned by CI.

For a distributable executable, use Ahk2Exe as described in `README.md`; GitHub Actions generates icons with ImageMagick, prepares x86/x64 Rime DLLs, and packages releases. Treat `.github/workflows/ci.yaml` as the authoritative release recipe.

## Coding Style & Naming Conventions

Use four-space indentation without tabs and a soft 120-character line limit. Indent continuation lines by one additional level; retain deliberate alignment in large mapping tables when it improves scanning. Place opening braces on the declaration or control-flow line, and use braces for every control-flow body, including single statements. Do not wrap an entire `if` or `while` condition in redundant parentheses.

Use `PascalCase` for classes, functions, and methods; `snake_case` for parameters, locals, mutable globals, instance properties, and class properties; and `UPPER_SNAKE_CASE` for constants. Preserve the spelling of AutoHotkey built-ins, Windows APIs, third-party interfaces, and existing dynamically accessed methods or properties. Declare function-local variables explicitly with `local`, except when a nested function intentionally captures an enclosing local; make global access similarly evident where it is not already super-global. Prefix repository modules and shared types with `Rabbit`.

Use `!`, `&&`, and `||` for logical operations. Parenthesize assignments used as conditions, for example `if (status := GetStatus())` and `if !(config := OpenConfig())`. Do not normalize `=` with `==`, or `!=` with `!==`; these operators have different case-sensitivity semantics in AutoHotkey. Likewise, do not mechanically replace `0`, `1`, or `!!value` with booleans when the existing form conveys API or coercion semantics.

Use double-quoted strings by default, allowing single quotes when they avoid substantial escaping. Use the explicit `.` operator for string concatenation, with spaces on both sides. Do not invert branches, introduce guard clauses, merge conditions, or otherwise reshape control flow as part of a style-only change.

Write first-party source comments in English and focus on rationale, platform constraints, and non-obvious behavior. Preserve TODOs, warnings, and source links unless they can be conclusively updated. Keep Chinese user-facing text unchanged. Preserve GPL headers and use `2023 - <current year>` for Xuesong Peng's copyright range in files modified during that year.

Match surrounding YAML indentation and comments. No formatter or linter is currently configured; do not introduce one without a separate project decision.

## Testing Guidelines

There is no top-level automated test suite or coverage threshold. Before submitting, launch both scripts and manually exercise affected input, tray, candidate-window, configuration, and deployment paths on Windows. For binding-level changes, run:

```powershell
AutoHotkey.exe Lib/librime-ahk/tests/rime_test_main.ahk
```

Ensure the matching `rime.dll` and test data are available. Add focused regression tests to the closest test directory when practical.

Testing must not leave temporary safety overrides in the diff. In particular, if caret-hook use is forced off for local antivirus compatibility, restore `RabbitConfig.use_caret_hook` before staging or committing.

## Commit & Pull Request Guidelines

Recent history follows Conventional Commits, usually `fix(scope): summary`, `feat: summary`, or `chore(dep): summary`. Keep subjects imperative and concise; reference issues in the body (for example, `Fixes #37`). Pull requests should explain behavior changes, testing performed, and Windows versions affected. Link relevant issues and include screenshots for candidate box, theme, tray, or other visual changes. Do not commit generated binaries, DLLs, icons, runtime data, or unrelated submodule pointer updates.
