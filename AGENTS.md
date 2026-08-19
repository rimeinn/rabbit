# Repository Guidelines

## Agent Operating Rules (Read First)

The rules in this section bind every agent run of this repository's scripts and take precedence over convenience. Read them before running anything.

### Catch every AutoHotkey exception at the top level

An uncaught AutoHotkey exception pops up a native error dialog on the machine running the script. No agent tool can see that dialog; it can leave the process hanging, exiting with a misleading status, or failing silently while the GUI waits for a click. Therefore:

- When running or testing any AutoHotkey script, MUST wrap its top-level startup or test entry point in `try/catch` and print the exception details (message, location, stack) to standard output.
- MUST NOT rely on the default error dialog as the record of a failure — the dialog is invisible to the agent, so the failure must be observable on stdout and in the exit status.
- MUST NOT treat `/ErrorStdOut` as the exception boundary; it only covers startup and load diagnostics, and destructor or callback-thread errors can still surface as dialogs.
- If a run hangs or ends with an unclear status, suspect an invisible dialog first and re-run through the wrapper below.

Copy this wrapper around any top-level entry point — a `main()` call or the script's inline startup statements:

```ahk
try {
    main() ; or the script's actual top-level statements
} catch as err {
    FileAppend "Uncaught exception: " err.Message "`n  at " err.What "`n  " err.Line "`nStack:`n" err.Stack "`n", "*"
    ExitApp 1
}
```

`FileAppend ..., "*"` writes the details to stdout, and `ExitApp 1` yields a non-zero exit status, so the failure is visible to the agent. When a runner already provides this boundary (for example `RunTest` in the unit tests), prefer it over hand-rolling the wrapper.

## Project Structure & Module Organization

Rabbit is a Windows Rime frontend written for AutoHotkey v2. `Rabbit.ahk` is the main entry point; `RabbitDeployer.ahk` handles installation and maintenance workflows. First-party modules live in `Lib/` and use the `Rabbit*.ahk` naming pattern. `schemas/rabbit.yaml` defines the bundled Rime schema, while `assets/` contains source SVG icons. `Data/` and `Rime/` are generated or runtime data and are intentionally ignored.

Two directories are Git submodules: `Lib/librime-ahk` and `plum`. Avoid mixing upstream submodule changes with
application changes. `Lib/Direct2D` and `Lib/GetCaretPosEx` are Rabbit-maintained copies of third-party modules; their
README files record the upstream baseline and license.

Implement new candidate-window features only for the modern candidate box. The legacy candidate box needs regression protection, but does not need to support new functionality unless explicitly requested.

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

There is no CI-enforced coverage threshold. Run focused tests directly or use the unit test runner. Always use `/ErrorStdOut` for startup and load diagnostics, but do not treat it as an exception boundary: each test body must run through `RunTest`, which catches callback exceptions and prints the test name, error, location, and stack to standard output. Test scripts use explicit relative includes and must remain runnable without a root-level test launcher.

AutoHotkey exceptions are not guaranteed to appear on stdout or stderr; runtime failures, including destructor errors, may be shown directly in a dialog. Always run through the top-level `try/catch` boundary required by Agent Operating Rules above; `/ErrorStdOut` only covers startup and load diagnostics and is not a substitute for that boundary.

```powershell
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitTests.ahk
```

`tests\integration\RabbitDeployerDialogTests.ahk` and `tests\integration\RabbitUIStylePreviewTests.ahk` are separate integration smoke tests. They initialize the real Rime deployer, require a matching `rime.dll` and local Rime data, and create native/Direct2D dialog resources; do not include them in `tests\unit\RabbitTests.ahk`. Run either one explicitly with `/ErrorStdOut` when changing its dialog or preview path.

Before submitting, launch both scripts and manually exercise affected input, tray, candidate-window, configuration, and deployment paths on Windows. For binding-level changes, run:

```powershell
AutoHotkey.exe Lib/librime-ahk/tests/rime_test_main.ahk
```

Ensure the matching `rime.dll` and test data are available. Add focused regression tests to the closest test directory when practical.

Testing must not leave temporary safety overrides in the diff. In particular, if caret-hook use is forced off for local antivirus compatibility, restore `RabbitConfig.use_caret_hook` before staging or committing.

## Commit & Pull Request Guidelines

Recent history follows Conventional Commits, usually `fix(scope): summary`, `feat: summary`, or `chore(dep): summary`. Keep subjects imperative and concise; reference issues in the body (for example, `Fixes #37`). Pull requests should explain behavior changes, testing performed, and Windows versions affected. Link relevant issues and include screenshots for candidate box, theme, tray, or other visual changes. Do not commit generated binaries, DLLs, icons, runtime data, or unrelated submodule pointer updates.
