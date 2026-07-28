# Rabbit Runtime Architecture Refactoring

Status: Phase 2 candidate presentation model implemented and validated
Last updated: 2026-07-28

## 1. Purpose

This document records the current runtime ownership, UI lifecycles, mutable state, dependency direction, and staged
refactoring plan for Rabbit. It covers both `Rabbit.ahk` and `RabbitDeployer.ahk`.

The refactoring preserves current control flow and user-visible behavior by default. Existing defects discovered during
the work are recorded and reproduced separately. A defect is fixed only after approval, in an independent `fix(...)`
commit.

## 2. Confirmed constraints

- Rabbit continues to target AutoHotkey v2.0.19.
- The legacy candidate box remains a first-class backend for old Windows versions, including Windows 7.
- Users on supported Windows versions may select the legacy candidate box with `use_legacy_candidate_box: true`.
- Selecting the legacy candidate box in the main application must not initialize Direct2D resources.
- Non-preview deployer paths must not initialize Direct2D resources.
- The deployer may initialize Direct2D lazily when it actually displays a supported style preview.
- `use_legacy_candidate_box` controls the main candidate backend; it does not disable the deployer style preview.
- The modern and legacy candidate boxes share a backend-neutral contract without requiring an inheritance hierarchy.
- Runtime resources use explicit, idempotent disposal. `__Delete()` may remain a fallback but is not the normal owner.
- Full application contexts stay at the entry or top-level coordination layer. Other components receive narrow
  dependencies.
- Configuration and resolved UI styles become read-only snapshots.
- Business modules ultimately stop depending on the super-global `rime`; librime itself is not mechanically wrapped.
- Focused first-party AutoHotkey regression tests and lightweight construction substitutes are allowed.
- The upstream `Lib/librime-ahk`, `Lib/Direct2D`, and `plum` submodules are not modified.
- Each implementation phase has its own commit and validation. Work pauses for approval after each phase.

## 3. Current process lifecycles

### 3.1 Main application

```text
Rabbit.ahk
  -> choose and load the keyboard layout
  -> acquire the process-wide Rime mutex
  -> create traits and initialize the global Rime API
  -> run first-start deployment or Rime maintenance
  -> create the Rime session
  -> load RabbitConfig and mutate UIStyle
  -> choose and construct one candidate-box backend
  -> register hotkeys
  -> read state labels and initial Rime status
  -> construct the tray menu and refresh the candidate style
  -> register tray and Windows color-change messages
  -> optionally start the per-window ASCII timer
  -> register the exit callback
  -> process input and UI events
  -> on exit, restore the keyboard layout and finalize Rime
```

Current ownership is implicit after startup. `RabbitMain()` constructs the mutex, Rime session, and candidate box, but
callbacks in several modules access them as globals. The exit callback directly accesses the same globals.

### 3.2 Deployer

```text
RabbitDeployer.ahk
  -> register the exit callback
  -> set maintenance tray state
  -> construct Configurator
  -> create traits and initialize the global Rime API for deployment
  -> dispatch one workflow
       -> deploy
       -> dictionary management
       -> synchronization
       -> switcher and style configuration
  -> optionally launch the main application with the result
  -> exit
```

The deployer uses synchronous `WinWaitClose()` calls as the practical owner of configuration and dictionary dialogs.
The ownership is not represented by a deployer object, and the global Rime API and `rabbit_traits` supply their implicit
runtime dependencies.

## 4. Mutable state inventory

The inventory covers all first-party module globals, class-static fields, function-static fields, state shared across
callbacks, and instance state grouped by its owning UI or resource. Ordinary function locals are intentionally excluded.
Instance fields are grouped by owner rather than listing every GUI control property.

AutoHotkey does not make a `Map` or `Array` immutable merely because Rabbit never intends to change it. The tables
therefore distinguish actively mutated state, lazy caches, and mutable containers used by convention as immutable
lookup data. “Target owner” describes the planned boundary, not an implemented type.

### 4.1 Main-process and shared globals

| State | Current writers | Current readers | Lifetime | Target owner |
|---|---|---|---|---|
| `rime` | constructed by `RabbitCommon` | main, input, state, tray, config, style, deployer UI | process | app or deployer context |
| `rabbit_traits` | main and `Configurator.Initialize()` | Rime setup lifetime | initialization/process | app or deployer context |
| `session_id` | `RabbitMain()` | input, runtime state, tray, exit | Rime session | app context |
| `mutex` | top-level `Rabbit.ahk` | startup and exit | main process | app context |
| `box` | `RabbitMain()` | input, tray, color-change handler | main process UI | candidate UI coordinator |
| `IN_MAINTENANCE` | common default and both entries | tray menu and icon | process/workflow | app/deployer runtime state |
| `IS_DARK_MODE` | config load and color-change handler | config/style dark-mode logic | main process | resolved appearance state |
| `last_is_hide` | top-level default, `ProcessKey()` | input processing | input interaction | input state |
| `suspend_hotkey_mask` | `RegisterHotKeys()` | `ProcessKey()` | main process | hotkey/input state |
| `suspend_hotkey` | `RegisterHotKeys()` | `ProcessKey()` | main process | hotkey/input state |
| tray schema/mode fields | `UpdateTrayTip()` | tray icon and tooltip | Rime session | tray presentation state |
| state-label globals | `UpdateStateLabels()` | status tooltip formatting | Rime session/schema | runtime label snapshot |

### 4.2 `RabbitGlobals`

| Property | Writers | Readers | Actual lifetime | Target owner |
|---|---|---|---|---|
| `process_ascii` | config load and `UpdateWinAscii()` | `UpdateWinAscii()` | main process | per-process input state |
| `on_tray_icon_click` | tray click handler | `UpdateWinAscii()` | one tray interaction | tray/input coordination state |
| `active_win` | `UpdateWinAscii()` | tray click handler | active-window interaction | per-process input state |
| `current_schema_icon` | startup and input processing | tray icon update | Rime schema/session | tray presentation state |
| `keyboard_layout` | `RabbitMain()` | deployer commands and exit | main process | app context |

These properties do not share one useful lifecycle. `RabbitGlobals` is therefore a service-locator-like collection
rather than a cohesive owner.

### 4.3 Static configuration and style state

| Container | State | Writers | Readers | Target |
|---|---|---|---|---|
| `RabbitConfig` | hotkey, tips, ASCII, schema icons, candidate/caret options | `RabbitConfig.load()` | main runtime modules | `RabbitConfigSnapshot` |
| `UIStyle` | fonts, geometry, colors, dark selection | config load, color changes, previews | both boxes and previews | `RabbitUIStyleSnapshot` |
| `LegacyCandidateBox` | GUI, colors, font options, debug flag/border | constructor/style/build | all legacy instances | instance state or immutable diagnostic option |
| `CandidateBox.isHidden` | `Show()` and `Hide()` | `Show()` and `Hide()` | candidate instance | instance state |

### 4.4 Callback-captured state, function statics, and lazy caches

| State | Mutation | Actual lifetime | Classification | Target owner |
|---|---|---|---|---|
| `SendTextByClipboard.clip_prev` | written by `SendTextByClipboard()`, read by its 50 ms timer | one delayed restore | timer-captured output state | clipboard output coordinator |
| `ProcessKey.prev_show` | updated after candidate visibility decisions | main process | candidate placement history | candidate placement coordinator |
| `ProcessKey.prev_x` / `prev_y` | updated after caret placement | main process | last fixed candidate position | candidate placement coordinator |
| `RabbitLogLimit.labels` | counts emitted messages by label | process | mutable rate-limit cache | logging helper/service |
| `GUIUtilities.GetFontArray.font_array` | populated on first font enumeration | process | lazy read-mostly cache | font enumeration service |
| `MonitorManage.monitors` | replaced and populated by enumeration | process | mutable write-only cache in current first-party code | monitor service or separately approved removal |

`ProcessKey.prev_*` is especially significant: `fix_candidate_box` changes whether the next candidate placement reuses
the previous coordinates. It is UI lifecycle state hidden inside the input callback and must move with placement policy,
not with key translation or the candidate renderer.

`RabbitLogLimit.labels` and `GUIUtilities.GetFontArray.font_array` may remain lazy caches. Their mutation and ownership
must still be explicit. A caller must not receive the internal font `Array` if it can mutate it; the service returns a
copy or exposes enumeration without sharing the cached container.

`SendTextByClipboard()` owns `clip_prev` until its one-shot timer callback restores the clipboard. Overlapping clipboard
sends may leave multiple pending restore callbacks with different captured values. This is a structural risk, not a
confirmed defect until its current behavior is reproduced.

### 4.5 Mutable containers used as immutable data

| Container | Contents | Current mutation | Policy |
|---|---|---|---|
| `KeyDef.mask` and key-code maps | key translation tables | initialized once | conventionally immutable lookup data |
| monitor structure offset statics | ABI offsets and sizes | initialized once | immutable scalar metadata |
| `GetCompositionText.cursor_text` / `cursor_size` | cursor encoding constants | initialized once | immutable scalar metadata |
| `SetupTrayMenu.rabbit_script` / `rabbit_ico` | resolved source paths | initialized once | immutable scalar metadata |
| remaining module globals | version/name, Windows messages, file attributes, monitor flags, window styles | initialized once | conventionally immutable constants |

These containers are not migration priorities, but their classification is explicit. Future code must not mutate the
`KeyDef` maps after class initialization; focused tests may verify lookup behavior rather than object identity.

### 4.6 Built-in and platform state changed by Rabbit

Rabbit also mutates AutoHotkey or Windows-owned state:

- `A_TrayMenu`, `A_IconTip`, and the tray icon;
- hotkey registrations and suspend state;
- `OnMessage` registrations for tray and Windows appearance events;
- repeating and one-shot timers;
- `A_Clipboard`, restored through a one-shot timer;
- the default keyboard layout;
- tooltips and tray tips.

These cannot live in a plain value snapshot. Their registration and restoration need explicit owners with deterministic
startup and disposal.

## 5. UI ownership and lifecycle inventory

| UI/resource | Current creator | Current practical owner | Inputs/events | Current disposal |
|---|---|---|---|---|
| modern candidate box | `RabbitMain()` | global `box` | input context, style globals | `CandidateBox.__Delete()` |
| modern candidate GUI | `CandidateBox.__New()` | `CandidateBox` | `Show()`/`Hide()` | GUI destroyed in `__Delete()` |
| Direct2D candidate renderer | `CandidateBox.__New()` | `CandidateBox` | render calls | transitive `__Delete()` |
| legacy candidate box | `RabbitMain()` | global `box` | input context, style globals | no explicit box disposal |
| legacy candidate GUI | `LegacyCandidateBox.Build()` | class-static field | build/show/hide | replaced implicitly; no explicit destroy |
| candidate placement history | `ProcessKey()` function statics | input callback | caret/fallback placement | process exit |
| switcher settings dialog | `ConfigureSwitcher()` | synchronous workflow | list and button events | `Destroy()` on accepted exit |
| style settings dialog | `ConfigureUI()` | synchronous workflow | theme selection and OK | `Destroy()` on accepted exit |
| style candidate preview | style dialog | dialog property | theme selection | reference release is implicit |
| dictionary dialog | `Configurator.DictManagement()` | synchronous workflow | list and file-operation events | window close observed by caller |
| dormant `ThemesGUI` | no first-party constructor found | none | theme/font callbacks | hides rather than destroys |
| tray menu | `SetupTrayMenu()` | process-global AHK tray | tray callbacks | process exit |
| hotkeys | `RegisterHotKeys()` | process-global AHK hotkey table | keyboard input | no unified unregister path |
| system messages | `RabbitMain()` | process-global message table | tray and color changes | process exit |
| ASCII timer | `RabbitMain()` | process-global timer table | active window polling | process exit |

### 5.1 Candidate-box coupling

- Both backends read the static mutable `UIStyle` directly.
- Both receive raw librime context data through `Build()`.
- `RabbitInput` owns context fetching, content building, placement policy, monitor correction, and visibility decisions.
- `RabbitTrayMenu` and the color-change handler reach the global box directly.
- `RabbitLegacyCandidateBox` includes `RabbitCandidateBox` only to reuse `GetCompositionText()`. This pulls the
  Direct2D implementation into a dependency that should be backend-neutral.
- Modern visibility and legacy GUI/style state are class-static even though only the selected candidate instance should
  own them.

### 5.2 Configuration-dialog coupling

- `Configurator` combines Rime deployment initialization, workflow dispatch, mutex acquisition, dialog creation, and
  workspace updates.
- Dialog completion is communicated through mutable `{ yes: false }` result objects.
- Dialog callbacks close over their GUI instances; explicit callback/resource teardown is not represented.
- `UIStyleSettingsDialog` creates `CandidatePreview` only on supported Windows, which is the correct point for lazy
  Direct2D construction.
- Theme discovery mutates the shared `UIStyle` once per preset and then restores it. This is a non-local transaction and
  a structural risk, but no user-visible defect has yet been established.

## 6. Current dependency direction

```text
Rabbit.ahk
  +-> RabbitInput
  |     +-> global rime/session_id/box
  |     +-> RabbitConfig
  |     +-> RabbitRuntimeState
  |     +-> RabbitTrayMenu
  +-> RabbitTrayMenu
  |     +-> global rime/session_id/box
  |     +-> RabbitConfig
  |     +-> RabbitGlobals
  +-> RabbitConfig
  |     +-> global rime/IS_DARK_MODE
  |     +-> UIStyle
  +-> RabbitUIStyle
        +-> global rime/IS_DARK_MODE/box

RabbitDeployer.ahk
  +-> RabbitConfigurator
        +-> global rime/rabbit_traits
        +-> switcher, style, and dictionary dialogs
        +-> RabbitUIStyleSettings
              +-> global rime
              +-> static UIStyle

LegacyCandidateBox
  +-> CandidateBox
        +-> Direct2D
```

The major direction violations are callbacks reaching back into global entry-owned state, style parsing reaching into
the active view, and the legacy backend depending on the modern rendering backend.

## 7. Target ownership model

### 7.1 `RabbitAppContext`

The app context owns main-process lifetime resources:

- the one Rime API instance and its traits;
- the active Rime session;
- the process mutex;
- the selected candidate-box instance or its top-level coordinator;
- the original keyboard layout;
- app-level maintenance and shutdown state.

`Rabbit.ahk` creates it. A top-level application coordinator may hold the full context. Input, tray, appearance, and
candidate components receive only the narrower dependencies they use.

### 7.2 `RabbitDeployerContext`

The deployer context owns deployer lifetime resources:

- its one Rime API instance and traits;
- the selected command and keyboard layout;
- workflow result and shutdown state;
- active workflow/dialog ownership where deterministic disposal requires it.

It does not contain input-session, candidate-box, or per-window ASCII state.

### 7.3 Value snapshots

`RabbitConfigSnapshot` contains values read at application startup. It does not contain active-window state, current
schema state, or mutable per-process ASCII choices.

`RabbitUIStyleSnapshot` contains fully resolved fonts, geometry, and colors. Candidate backends and previews consume a
snapshot without knowing whether it came from the active configuration, dark-mode resolution, or a temporary preview.

For this refactoring, “read-only snapshot” has the following executable meaning in AutoHotkey:

- one loader/builder writes all values before publishing the snapshot;
- application code does not assign snapshot properties after construction;
- constructors defensively copy incoming `Map` and `Array` values;
- snapshot APIs do not expose internal mutable collections directly;
- primitive-valued collections such as schema icons and preset process modes are exposed through query methods, or by
  returning a fresh copy when a caller needs enumeration;
- tests mutate constructor inputs and returned collection copies and verify that the published snapshot is unchanged.

This is convention-enforced read-only state with defensive collection boundaries, not a claim that AutoHotkey provides
deep language-level immutability. The initial snapshot collections contain only scalar keys and values, so defensive
copying is sufficient. If nested mutable values are added later, their copy/ownership policy must be defined explicitly
before they enter a snapshot.

### 7.4 Candidate UI boundary

The first boundary keeps raw Rime context input to reduce migration risk:

```text
UpdateStyle(style)
Build(rime_context, &width, &height)
Show(x, y)
Hide()
Dispose()
```

The Phase 1 contract uses independent `built`, `visible`, and `disposed` conditions rather than requiring both backends
to create native resources at the same time:

| Operation | Preconditions | Repetition and state effect |
|---|---|---|
| successful construction | factory supplies the initial style | `built = false`, `visible = false`, `disposed = false`; native GUI creation may remain lazy |
| `UpdateStyle(style)` | not disposed | repeatable; does not change visibility; current visible pixels need not repaint until the next build/show cycle |
| `Build(context, &width, &height)` | not disposed | repeatable; may lazily create GUI/render resources; assigns both output dimensions on every success; sets `built = true` without showing or hiding |
| `Show(x, y)` | built and not disposed | repeatable; redraws/repositions the current build and sets `visible = true` |
| `Hide()` | any state | repeatable no-op when already hidden, not yet built, or disposed; otherwise hides and sets `visible = false` |
| `Dispose()` | any completed-construction state | idempotent; hides, releases owned resources, and sets `disposed = true` |

After disposal, `Build()`, `Show()`, and `UpdateStyle()` raise an error so use-after-dispose is visible. `Hide()` and
`Dispose()` remain no-ops to make layered cleanup safe. Constructors initialize disposal flags and resource fields to
neutral values before acquiring resources. Each backend's `__New()` wraps its own acquisition in `try`/`catch`, calls
`this.Dispose()` on failure, and rethrows the original error. The factory can clean up only dependencies that it created
and still owns before invoking the backend constructor; it cannot assume access to an instance whose `__New()` failed.
The design does not manually allocate uninitialized objects to work around AutoHotkey construction semantics.

`Build()` is allowed to create the legacy GUI lazily; GUI allocation timing is not part of the common contract. The
contract does require that constructing or building one selected backend never constructs the other backend. Phase 1
retains the current backend-specific behavior for a style change while content is already visible; Phase 3 may define a
common immediate-repaint policy only if it is separately reviewed as a behavior decision.

The next phase introduces a backend-neutral `CandidatePresentation`. It owns preedit splitting, label selection, display
text, comments, and highlight state. Direct2D and legacy GUI code then own rendering only.

The factory receives an already resolved backend choice. It does not read Rime configuration:

```text
legacy := IsOldWindows() || config.use_legacy_candidate_box
candidate_box := factory.Create(legacy, style)
```

Selection occurs once after startup configuration loading. Runtime backend switching is out of scope.

## 8. Direct2D initialization policy

Including `Lib/Direct2D/Direct2D.ahk` defines the wrapper and initializes static GUID buffers, but it does not create a
Direct2D or DirectWrite factory. `Direct2D.__New()` starts GDI+ and constructs both factories. Resource-free paths must
therefore avoid constructing `Direct2D`, `CandidateBox`, or `CandidatePreview`.

| Process/path | Policy |
|---|---|
| main, modern backend | construct Direct2D when the candidate box is created |
| main, legacy backend on any supported OS | do not construct any Direct2D wrapper |
| deployer `deploy`, `dict`, or `sync` | do not construct any Direct2D wrapper |
| deployer style UI on old Windows | preview disabled; do not construct Direct2D |
| deployer style UI on supported Windows | construct lazily when the preview is displayed |

The compiled executable may still contain included Direct2D code. The requirement concerns initialization of GDI+,
Direct2D/DirectWrite factories, render targets, and drawing resources.

### 8.1 Direct2D acceptance method

Validation runs each case in a fresh AutoHotkey process so a previous modern renderer cannot contaminate the result.
First-party construction seams count calls to the modern backend, legacy backend, candidate preview, and the wrapper
factory that invokes `Direct2D.__New()`. A module/DLL presence check may supplement this counter, but it is not the
primary assertion because Windows or another component may load the same DLL independently.

| Process/path | Selection setup | Expected Direct2D wrapper constructions | Required by |
|---|---|---:|---|
| main, forced old-Windows path | old-version probe, config false | 0 | Phase 1 |
| main, configured legacy path | supported-version probe, config true | 0 | Phase 1 |
| main, modern path | supported-version probe, config false | 1 candidate renderer | Phase 1 |
| deployer ordinary commands | `deploy`, `dict`, and `sync` without style UI | 0 | Phase 5 |
| deployer old-Windows style page | old-version probe and style UI | 0 | Phase 5 |
| deployer supported style page | supported-version probe and style UI | 0 before preview creation; 1 after preview creation | Phase 3/5 |

Old-Windows selection is exercised through an injectable/version-selection seam on a modern development machine. An
actual Windows 7 manual run remains desirable when such an environment is available, but is not substituted with an
unverifiable OS claim.

## 9. Structural risk register

These findings are not classified as defects without a reproducible behavior or resource impact.

| ID | Finding | Planned handling |
|---|---|---|
| SR-001 | legacy candidate GUI and styles are class-static | move to instance ownership in candidate-boundary phase |
| SR-002 | modern candidate hidden state is class-static | move to instance ownership in candidate-boundary phase |
| SR-003 | normal candidate disposal relies on `__Delete()` | add explicit idempotent disposal |
| SR-004 | theme enumeration temporarily mutates shared `UIStyle` | replace with independent style snapshots |
| SR-005 | message, hotkey, and timer registrations have no unified owner | assign owners during app-context migration |
| SR-006 | `RabbitCommon` creates the Rime service and declares app state | separate constants/helpers from process ownership |
| SR-007 | `RabbitInput` combines key translation, Rime processing, presentation, placement, and clipboard output | split only at stable behavioral seams |
| SR-008 | dialog result objects and destruction paths are inconsistent | clarify during deployer-context migration |
| SR-009 | `ThemesGUI` has no first-party construction path | preserve until separately confirmed obsolete |
| SR-010 | overlapping clipboard sends may queue restores with different captured clipboard values | reproduce separately before treating as a defect |

Confirmed defects are added to a separate defect section with reproduction steps and do not share a refactoring commit.

## 10. Confirmed defect register

### BUG-001: Missing generated tray icons abort source startup

Status: Fixed by `302c687 fix(tray): skip missing icon files`

Reproduction:

1. Use a clean source worktree without the generated, ignored `Lib/rabbit.ico`, `Lib/rabbit-alt.ico`, and
   `Lib/rabbit-ascii.ico` files.
2. Start `Rabbit.ahk` without maintenance or run `RabbitDeployer.ahk deploy`.
3. `UpdateTrayIcon()` calls `TraySetIcon()` with a missing file and AutoHotkey displays an exception dialog.

Resolution:

- source-mode tray updates skip `TraySetIcon()` when the selected icon file does not exist;
- compiled resource-number behavior is unchanged;
- a missing custom schema icon is also skipped defensively.

Validation:

- with all three generated icons temporarily removed, the main application remained running without captured output or
  an exception dialog;
- with the icons removed, `RabbitDeployer.ahk deploy` exited with code 0 and no captured output or exception;
- the ignored local test icons were restored and remain outside the diff.

## 11. Refactoring phases

### Phase 0: Audit and baseline

Commit: `docs: document runtime ownership and refactoring plan`

Deliverables:

- current process lifecycles;
- mutable state and UI ownership inventories;
- current and target dependency direction;
- confirmed architectural constraints;
- staged plan and validation baseline.

Exit criteria:

- all first-party globals and class/function statics have an active-state, cache, or conventionally immutable
  classification;
- cross-callback and UI/resource instance state is grouped under a current and proposed owner;
- unresolved behavior is recorded as a risk rather than silently changed;
- both entry scripts receive proportionate baseline validation;
- the audit commit contains no runtime source changes.

### Phase 1: Candidate-box boundary

Commit: `refactor(ui): define candidate box boundary`

- add a backend-neutral candidate module and construction boundary;
- keep `Build(rime_context, ...)` behavior initially;
- make legacy and modern visibility, GUI, and style data instance-owned;
- add explicit idempotent disposal;
- remove the legacy backend's dependency on the Direct2D backend;
- verify that the unselected backend is not constructed.

Before changing backend state or disposal, Phase 1 adds the smallest characterization/contract harness needed to protect
the existing `Build()` input and output behavior. The Phase 1 checks include:

- both OS-forced and configuration-selected legacy paths construct only the legacy backend;
- the supported modern path constructs only the modern backend;
- neither backend fails when `Hide()` is repeated before build, after build, or after disposal;
- both backends tolerate repeated `Dispose()` and reject build/show/style operations after disposal;
- selecting and building the legacy backend leaves the Direct2D construction counter at zero;
- repeated `Build()` calls assign positive width and height consistently for fixed Rime-context fixtures;
- dimensions satisfy relationships such as configured minimum width rather than cross-machine fixed pixels;
- backend-specific pixel dimensions are compared before and after the refactor only in the same font, DPI, Windows
  version, architecture, and renderer environment.

These tests are written before the corresponding implementation changes within Phase 1. Phase 2 still owns the broader
presentation fixtures for UTF-8 selection, label fallback, and candidate mapping. Automated tests prefer assignment,
positivity, repeatability, and relationship constraints; recorded pixel baselines are local characterization evidence,
not portable golden values.

### Phase 2: Candidate presentation model

Commit: `refactor(ui): introduce candidate presentation model`

- move preedit splitting and label/candidate extraction out of renderers;
- preserve librime UTF-8 byte-offset and cursor insertion semantics;
- feed the same presentation to both candidate backends;
- use presentation fixtures for focused first-party tests;
- leave placement and screen correction behavior unchanged.

### Phase 3: Explicit style snapshots

Commit: `refactor(ui): pass explicit style snapshots`

- parse active configuration into `RabbitUIStyleSnapshot`;
- create independent preview snapshots without mutating active style;
- pass snapshots explicitly to both candidate backends and previews;
- preserve dark-mode and theme selection behavior.

### Phase 4: Main application context

Commit: `refactor(runtime): introduce application context`

- create the Rime API at the main entry rather than in `RabbitCommon`;
- introduce `RabbitAppContext` and a top-level lifecycle coordinator;
- separate config snapshot, session state, tray presentation, and per-window ASCII state;
- give input, tray, appearance, timer, message, and hotkey owners narrow dependencies;
- make normal shutdown explicit and ordered.

### Phase 5: Deployer context and dialog ownership

Commit: `refactor(deployer): make workflow ownership explicit`

- create the deployer Rime API at its entry;
- introduce `RabbitDeployerContext`;
- separate deployment workflow coordination from individual dialogs;
- make dialog and preview resource ownership explicit;
- retain lazy Direct2D preview initialization.

## 12. Validation strategy

Every implementation phase performs checks proportional to its changes and pauses after its commit.

Common checks:

- inspect `git diff` and submodule status;
- launch `Rabbit.ahk` and `RabbitDeployer.ahk` from source;
- confirm no generated/runtime files or submodule pointer changes enter the diff;
- restore any temporary local safety override before staging;
- stop an interfering prerelease `Rabbit.exe` without restoring it.

Candidate/UI checks:

- modern candidate input, paging, movement, hiding, and style refresh;
- configured legacy candidate input, paging, movement, hiding, and style refresh;
- tray menu actions and suspend/ASCII interactions;
- configuration, style preview, dictionary, deploy, and synchronization entry paths as affected;
- Direct2D construction policy for selected and unselected paths.

Safety constraint:

- local tests that can call `GetCaretPosEx` must never enable its hook;
- a temporary hard-coded `RabbitConfig.use_caret_hook` override is allowed only for local testing;
- the override must be restored and absent from every diff and commit.

Focused tests:

- snapshot construction and collection access do not retain or expose mutable `Map`/`Array` aliases;
- candidate lifecycle transitions, repeated hide/dispose, and post-dispose failures;
- candidate presentation conversion, including UTF-8 cursor and selection byte offsets;
- label fallback and highlighted candidate mapping;
- style snapshot parsing without shared-state mutation;
- backend factory selection without construction of the unselected backend.

## 13. Phase validation log

| Phase/commit | Checks | Result |
|---|---|---|
| Phase 0 | branch and recursive submodule baseline | Pass |
| Phase 0 | `Rabbit.ahk 0 0 1033` source startup for five seconds | Pass; remained running with no captured exception |
| Phase 0 | `RabbitDeployer.ahk` default source entry | Pass; opened its expected first-run configuration path |
| Phase 0 | `RabbitDeployer.ahk deploy` | Pass; exit code 0 with no captured exception |
| Phase 1 | caller-resolved factory selection in fresh processes | Pass; old-Windows and configured-legacy choices constructed 0 Direct2D renderers, modern constructed 1 |
| Phase 1 | configured legacy selection and build in a dedicated fresh process | Pass; a calibrated `Direct2D.__New()` probe observed 0 constructions while valid dimensions were produced |
| Phase 1 | candidate lifecycle and partial-construction cleanup contract tests | Pass for both backends, including repeated build, hide, and dispose |
| Phase 1 | local dimension characterization | Pass; modern remained 160 x 101 and legacy remained 172 x 99 in the same environment |
| Phase 1 | actual modern and configured-legacy input paths | Pass; preedit, candidates, comments, selection, and positioning rendered correctly |
| Phase 1 | configured-legacy main-process module inspection | Pass; `gdiplus`, `d2d1`, and `dwrite` were not loaded |
| Phase 1 | explicit main-application shutdown | Pass; the modern candidate renderer disposed without a captured exception |
| Phase 1 | injected candidate disposal failure | Pass; Rime session destruction, finalization, and mutex closure still ran in order |
| Phase 1 | deployer default UI and `deploy` command | Pass; the expected configuration window opened and deployment exited with code 0 |
| Phase 1 | local caret-hook safety override cleanup | Pass; `rabbit.custom.yaml` was restored and no override entered the diff |
| Phase 2 | candidate presentation fixtures | Pass; UTF-8 selection, cursor insertion, label sources, comments, highlighting, and empty menus |
| Phase 2 | backend lifecycle and local dimensions | Pass; modern remained 160 x 101 and legacy remained 172 x 99 |
| Phase 2 | dedicated legacy build process | Pass; calibrated `Direct2D.__New()` probe observed 0 constructions |
| Phase 2 | modern and legacy real-input paths | Pass; preedit, candidates, highlighting, paging, and hiding were exercised |
| Phase 2 | `Rabbit.ahk` and `RabbitDeployer.ahk` validation | Pass; both entry scripts exited validation with code 0 |
| Phase 2 | local caret-hook safety override cleanup | Pass; `rabbit.custom.yaml` was restored, redeployed, and absent from the diff |

The local source checks used the available AutoHotkey v2.0.26 interpreter with `/ErrorStdOut`, with both standard output
and standard error captured. A high-frequency visible-window probe was also used to identify the missing-icon exception
before it was fixed. CI remains authoritative for the pinned AutoHotkey v2.0.19 build. No input was sent during the main
application startup check, so the caret hook path was not invoked and no safety override was required.

The running prerelease `Rabbit.exe` was stopped before validation because it held the application runtime state. It was
not restarted.
