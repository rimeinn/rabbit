# Rabbit Runtime Architecture Refactoring

Status: Phase 5 implemented; post-Phase 5 nightly validation in progress
Last updated: 2026-07-31

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
  -> create the Rime API and RabbitApplication
  -> RabbitApplication creates RabbitAppContext
       -> choose and load the keyboard layout
       -> acquire the process-wide Rime mutex
       -> initialize Rime and create its session
       -> run first-start deployment or Rime maintenance
       -> load RabbitConfigSnapshot and RabbitUIStyleSnapshot
       -> construct the selected candidate backend
       -> construct input, runtime-state, tray, and appearance owners
       -> register hotkeys, timers, tray messages, and appearance messages
  -> process input and UI events
  -> on exit, unregister callbacks and dispose the context in order
```

`RabbitApplication` coordinates startup and owns the top-level callbacks. `RabbitAppContext` owns process-lifetime
resources and disposes input hotkeys, the runtime timer, appearance messages, the candidate box, the Rime session,
Rime, and the mutex in order. Runtime components receive only their direct dependencies.

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
| main `rime` | constructed by `Rabbit.ahk` | app context and narrow runtime owners | process | implemented app-context ownership |
| deployer `rime` | constructed by `RabbitDeployer.ahk` | deployer UI | process | deployer context in Phase 5 |
| `rabbit_traits` | app context and `Configurator.Initialize()` | Rime setup lifetime | initialization/process | app implemented; deployer Phase 5 |
| `session_id` | `RabbitApplication` | input, runtime state, tray, shutdown | Rime session | implemented app-context ownership |
| `mutex` | `RabbitApplication` | startup and shutdown | main process | implemented app-context ownership |
| candidate box | `RabbitApplication` | input, tray, appearance, shutdown | main process UI | implemented app-context ownership |
| maintenance state | application/deployer workflow | tray menu and icon | process/workflow | workflow coordinator |
| active dark mode and style | appearance controller | appearance callback and candidate box | main process | implemented appearance ownership |
| placement and suspend fields | input controller | input processing | main process | implemented input ownership |
| tray schema/mode fields | tray controller | tray icon and tooltip | Rime session | implemented tray ownership |
| state labels | runtime state | status tooltip formatting | Rime session/schema | implemented runtime-state ownership |

### 4.2 Former `RabbitGlobals`

| Property | Writers | Readers | Actual lifetime | Target owner |
|---|---|---|---|---|
| `process_ascii` | runtime state | runtime state | main process | implemented runtime-state ownership |
| `on_tray_icon_click` | tray controller | runtime state | one tray interaction | implemented runtime-state ownership |
| `active_win` | runtime state | tray controller | active-window interaction | implemented runtime-state ownership |
| `current_schema_icon` | tray controller | tray controller | Rime schema/session | implemented tray ownership |
| `keyboard_layout` | application coordinator | tray and shutdown | main process | implemented app-context ownership |

These properties did not share one useful lifecycle. Phase 4 removed `RabbitGlobals` and moved each property to its
cohesive owner.

### 4.3 Static configuration and resolved style state

| Container | State | Writers | Readers | Target |
|---|---|---|---|---|
| `RabbitConfigSnapshot` | hotkey, tips, ASCII, schema icons, candidate/caret options | constructed by `RabbitConfigLoader` | main runtime modules | implemented snapshot |
| `RabbitUIStyleSnapshot` | resolved fonts, geometry, colors, dark selection | constructed before publication | both boxes and previews | implemented snapshot |
| `LegacyCandidateBox` | GUI, colors, font options, debug flag/border | constructor/style/build | all legacy instances | instance state or immutable diagnostic option |
| `CandidateBox.isHidden` | `Show()` and `Hide()` | `Show()` and `Hide()` | candidate instance | instance state |

### 4.4 Callback-captured state, function statics, and lazy caches

| State | Mutation | Actual lifetime | Classification | Target owner |
|---|---|---|---|---|
| `SendTextByClipboard.clip_prev` | written by `SendTextByClipboard()`, read by its 50 ms timer | one delayed restore | timer-captured output state | clipboard output coordinator |
| `ProcessKey.prev_show` | updated after candidate visibility decisions | main process | candidate placement history | candidate placement coordinator |
| `ProcessKey.prev_x` / `prev_y` | updated after caret placement | main process | last fixed candidate position | candidate placement coordinator |
| `RabbitLogLimit.labels` | counts emitted messages by label | process | mutable rate-limit cache | logging helper/service |
| `MonitorManage.monitors` | replaced and populated by enumeration | process | mutable write-only cache in current first-party code | monitor service or separately approved removal |

`ProcessKey.prev_*` is especially significant: `fix_candidate_box` changes whether the next candidate placement reuses
the previous coordinates. It is UI lifecycle state hidden inside the input callback and must move with placement policy,
not with key translation or the candidate renderer.

`RabbitLogLimit.labels` may remain a lazy cache. Its mutation and ownership must still be explicit.

`SendTextByClipboard()` owns `clip_prev` until its one-shot timer callback restores the clipboard. Overlapping clipboard
sends may leave multiple pending restore callbacks with different captured values. This is a structural risk, not a
confirmed defect until its current behavior is reproduced.

### 4.5 Mutable containers used as immutable data

| Container | Contents | Current mutation | Policy |
|---|---|---|---|
| `KeyDef.mask` and key-code maps | key translation tables | initialized once | conventionally immutable lookup data |
| monitor structure offset statics | ABI offsets and sizes | initialized once | immutable scalar metadata |
| `RabbitGetCompositionText.cursor_text` / `cursor_size` | cursor encoding constants | initialized once | immutable scalar metadata |
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
| tray menu | `SetupTrayMenu()` | process-global AHK tray | tray callbacks | process exit |
| hotkeys | `RegisterHotKeys()` | process-global AHK hotkey table | keyboard input | no unified unregister path |
| system messages | `RabbitMain()` | process-global message table | tray and color changes | process exit |
| ASCII timer | `RabbitMain()` | process-global timer table | active window polling | process exit |

### 5.1 Candidate-box coupling

- Both backends receive a resolved `RabbitUIStyleSnapshot` explicitly.
- Both receive raw librime context data through `Build()`.
- `RabbitInput` owns context fetching, content building, placement policy, monitor correction, and visibility decisions.
- `RabbitTrayMenu` and the color-change handler reach the global box directly.
- Candidate presentation conversion is backend-neutral, and the legacy backend does not depend on the Direct2D backend.
- Modern and legacy visibility, GUI, and backend style state are instance-owned.

### 5.2 Configuration-dialog coupling

- `Configurator` combines Rime deployment initialization, workflow dispatch, mutex acquisition, dialog creation, and
  workspace updates.
- Dialog completion is communicated through mutable `{ yes: false }` result objects.
- Dialog callbacks close over their GUI instances; explicit callback/resource teardown is not represented.
- `UIStyleSettingsDialog` creates `CandidatePreview` only on supported Windows, which remains the lazy Direct2D
  construction point.
- Theme discovery creates an independent resolved snapshot per preset and does not mutate the active runtime snapshot.

## 6. Current dependency direction

```text
Rabbit.ahk
  +-> RabbitApplication
        +-> RabbitAppContext
        |     +-> rime/session/mutex/candidate/config
        |     +-> ordered runtime disposal
        +-> RabbitConfigLoader
        |     +-> RabbitConfigSnapshot
        |     +-> RabbitUIStyleSnapshot
        +-> RabbitInputController
        |     +-> rime/session/candidate/config/runtime state/tray
        +-> RabbitRuntimeState
        |     +-> rime/session/config and tray updates
        +-> RabbitTrayController
        |     +-> rime/session/candidate/config/runtime state
        +-> RabbitAppearanceController
              +-> rime/candidate/current style and dark mode

RabbitDeployer.ahk
  +-> RabbitConfigurator
        +-> global rime/rabbit_traits
        +-> switcher, style, and dictionary dialogs
        +-> RabbitUIStyleSettings
              +-> global rime
              +-> RabbitUIStyleSnapshot
```

Main callbacks no longer reach back into global entry-owned state. The remaining major direction violations are in
deployer workflows, which still rely on the explicit deployer-entry Rime and traits globals until Phase 5. Style and
configuration parsing publish defensive value snapshots, and the legacy backend is independent of the modern renderer.

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
legacy := RabbitIsOldWindows() || config.use_legacy_candidate_box
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

| ID | Finding | Disposition |
|---|---|---|
| SR-001 | legacy candidate GUI and styles were class-static | resolved in Phase 1 with instance-owned GUI and style state |
| SR-002 | modern candidate hidden state was class-static | resolved in Phase 1 with instance-owned lifecycle state |
| SR-003 | normal candidate disposal relied on `__Delete()` | resolved in Phase 1 with explicit idempotent disposal |
| SR-004 | theme enumeration temporarily mutates shared `UIStyle` | resolved in Phase 3 with independent style snapshots |
| SR-005 | message, hotkey, and timer registrations had no unified owner | resolved across the main app and deployer by Phase 5 |
| SR-006 | `RabbitCommon` created the Rime service and declared app state | resolved in Phase 4 |
| SR-007 | `RabbitInput` combined key translation, Rime processing, presentation, placement, and clipboard output | controller ownership established in Phase 4; split further only at stable behavioral seams |
| SR-008 | dialog result objects and destruction paths were inconsistent | resolved for deployer dialogs in Phase 5 |
| SR-009 | `ThemesGUI` had no first-party construction path | resolved after Phase 5 by removing the obsolete dialog and retaining `CandidatePreview` as an independent module |
| SR-010 | overlapping clipboard sends may queue restores with different captured clipboard values | reproduce separately before treating as a defect |
| SR-011 | event, hotkey, tray, and workflow entry functions remained in AutoHotkey's global function namespace | resolved for application and deployer owners by Phase 5; remaining reusable helpers use the `Rabbit` prefix |

Confirmed defects are added to a separate defect section with reproduction steps and do not share a refactoring commit.

### 9.1 Global function namespace scope

The post-Phase 2 namespace cleanup is intentionally limited to reusable helper functions. These helpers use the
`Rabbit` prefix, including caret lookup, platform detection, traits construction, configuration-file creation,
candidate text conversion, and log cleanup.

Main-application event entries such as Rime notification handling, hotkey registration and processing, tray clicks,
appearance messages, keyboard restoration, and exit handling are methods on their runtime owners. Phase 5 completed
the equivalent migration for deployer and active dialog workflows. Remaining reusable helpers use the `Rabbit` prefix,
and new global callback entry points should be avoided.

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

### BUG-002: Legacy candidate box displays an empty custom label

Status: Fixed by `fix(ui): fall back from empty custom labels`

Reproduction:

1. Provide a non-empty `select_labels[0]` marker so the custom-label path is selected.
2. Leave one candidate's custom label empty.
3. Build the legacy candidate box; the corresponding label is empty while the modern backend falls back to its ordinal.

Resolution:

- the shared candidate presentation model resolves an empty custom label to the candidate ordinal;
- both candidate backends consume the same resolved label.

Validation:

- the focused presentation fixture checks a non-empty custom label and an empty label in the same menu;
- the empty label resolves to its formatted candidate ordinal.

### BUG-003: Legacy candidate updates leave auxiliary GUI windows visible

Status: Fixed by `fix(ui): destroy legacy measurement windows`

Reproduction:

1. Select the legacy candidate backend and keep `use_caret_hook: false`.
2. Start Rabbit, focus a verified text editor window, and enter `shuru`.
3. Enumerate Rabbit's visible top-level windows after each input update.
4. Press `Esc` to hide the candidate.
5. The active `172 x 190` candidate window is hidden, but three same-position auxiliary GUI windows created during
   prior updates remain visible.

Characterization:

- the behavior predates Phase 3 and is present in the reorganized baseline;
- `LegacyCandidateBox.BoxGui.Update()` constructs a temporary `BoxGui` for measurement on every update;
- the main candidate hide contract still targets the active GUI instance, while the auxiliary native windows remain;
- the legacy process continues to satisfy the no-Direct2D policy.

Resolution:

- the existing GUI-based measurement algorithm is unchanged;
- `Update()` now explicitly destroys its temporary measurement GUI after copying the measured values;
- replacing GUI-based measurement with direct GDI or Win32 measurement remains a separate optional refactoring.

Validation:

- repeated legacy `Build()` calls leave the process with only the owned candidate GUI, and disposal restores the
  native GUI count to its baseline;
- the modern and legacy lifecycle fixtures retain their local `160 x 101` and `172 x 99` dimensions;
- real legacy input displayed and updated the candidate, and `Esc` left no auxiliary candidate window visible;
- the configured-legacy process did not load Direct2D, DirectWrite, or GDI+.

### BUG-004: Chromium-class windows may expose invalid successful MSAA caret rectangles

Status: Confirmed in direct-source runs; mitigated in CI packages by the historical
`Lib/GetCaretPosEx/GetCaretPosEx.patch`

Affected observations:

- confirmed and instrumented in `Feishu.exe`, `ahk_class Chrome_WidgetWin_1`;
- reported with the same visible behavior in `ChatGPT.exe`, `ahk_class Chrome_WidgetWin_1`;
- other Chromium or Electron desktop applications may expose the same accessibility behavior.

Source/package distinction:

- `Lib/GetCaretPosEx/GetCaretPosEx.patch` is a tracked packaging patch; the Chromium/Electron change was added by
  `169cc16` (`fix: wrong caret position in some electron apps`) on 2025-08-06;
- the `build-rabbit` CI job runs `git apply` on this patch before uploading the package;
- direct execution from the repository does not apply the patch and therefore uses the checked-in provider order
  `MSAA -> UIA -> hook` for `Chrome_WidgetWin_*`;
- the patch gives `Chrome_WidgetWin_*` the provider order `UIA -> hook`, deliberately skipping MSAA; with
  `use_caret_hook: false`, the packaged path uses only UIA;
- the patch also contains Adobe-window handling and a Windows 7 guard around `GetDpiForWindow`; those changes are
  unrelated to this Chromium symptom.

Current reproduction:

- direct execution from `D:\rime-repos\rabbit` reproduced the misplaced Y coordinate;
- the package installed at `D:\Apps\rabbit` did not reproduce it because its distributed
  `Lib/GetCaretPosEx/GetCaretPosEx.ahk` already contained the applied Chromium patch;
- the package being one application commit behind the working tree was not the cause of the behavioral difference;
- the earlier `refactor-nightly` daily-use result therefore demonstrated the historical patch's mitigation rather than
  the underlying MSAA result becoming valid.

Historical reproduction:

1. Keep `use_caret_hook: false`.
2. Focus an editable control in an affected `Chrome_WidgetWin_1` application.
3. Start a Rime composition so Rabbit requests the caret rectangle.
4. The candidate X coordinate follows the real caret, while its Y coordinate remains near the top of the screen.
5. On `master`, the observed lookup failure instead sends the candidate to the existing mouse-position fallback.

Characterization:

- the current branch and `master` contain the same unpatched `GetCaretPosEx` MSAA algorithm, while CI packages apply
  the additional tracked patch;
- no refactoring statement caused the invalid rectangle; direct-source versus packaged behavior differs by design
  because only the packaging workflow applies the patch;
- the difference is runtime-state or timing-sensitive: `master` was observed to reject or fail the lookup, while the
  current branch receives a successful MSAA result;
- in the instrumented Feishu case, `GetGUIThreadInfo` returned no caret HWND and the hook path was skipped;
- MSAA returned success with the normalized rectangle `x=-1739, y=-1, w=1, h=17`;
- Rabbit accepted the rectangle without checking whether it intersected the relevant window client area;
- candidate placement consequently calculated `new_y = -1 + 17 + 4 = 20`;
- the ChatGPT observation is user-reported and was not separately instrumented;
- patched packages avoid this exact failure by never querying MSAA for `Chrome_WidgetWin_*`.

Safety and future-fix constraints:

- diagnosis and future regression tests must keep the hook disabled and must not execute its remote-thread path;
- negative screen coordinates are valid on monitors left of or above the primary monitor and cannot be rejected
  categorically;
- a general fix should validate an MSAA rectangle against the relevant client area, continue with UIA when the MSAA
  result is invalid, and retain the existing mouse fallback when all caret providers fail;
- do not add executable-name special cases for Feishu or ChatGPT; the existing window-class patch remains a package
  mitigation until a general validation fix replaces it;
- a future general fix must reconcile or remove the packaging patch so direct-source and packaged provider behavior do
  not silently diverge;
- validation should cover both direct-source execution and the post-patch package while keeping the hook disabled.

### BUG-005: Main application may launch the deployer before releasing Rime

Status: Resolved after Phase 5 nightly validation

Affected observations:

- `重新部署` could start the deployer while the main process still owned its Rime session and mutex, causing the
  deployer to exit without visible feedback;
- `用户词典管理` could reach the same race and report that another deployment task was running;
- `输入法设定` visibly started the deployer before the main process exited, but its additional UI setup usually
  delayed Rime access enough to hide the conflict.

Characterization:

- the tray helper called `Run()` before `ExitApp(1)`, so child-process startup raced the main application's `OnExit`
  cleanup;
- the ordering predates Phase 4, but Phase 4's explicit disposal of input, runtime, appearance, candidate, session,
  Rime, and mutex owners widened the interval and made the race reproducible;
- the deployer mutex warning was accurate: the main process had not completed its own mutex and Rime release.

Resolution:

- tray commands now delegate deployer handoff to `RabbitApplication`;
- the application completes its idempotent `Shutdown(1)` before launching the deployer, then exits without repeating
  cleanup;
- first-run installation uses the same ordered handoff.

Validation:

- the handoff fixture records input, runtime, appearance, candidate, session, Rime, and mutex cleanup before the
  deployer launch callback;
- a tray fixture verifies that deployer commands retain the current keyboard layout when delegated to the application;
- the complete first-party test suite passes with the caret hook disabled.

### BUG-006: An interrupted candidate render may overwrite a newer result

Status: Fixed by `fix(input): prevent stale candidate rendering`

Affected observations:

- when candidate rendering is slow, a previous key's candidate result may appear after the latest key's result and
  remain visible;
- the behavior predates the runtime refactoring and affects the shared candidate update structure on `master`.

Characterization:

- each registered input hotkey starts an AutoHotkey logical thread, and a slow `ProcessKey()` becomes interruptible;
- a newer key can therefore complete its candidate `Build()` and `Show()` before the interrupted older thread resumes;
- both candidate backends mutate one shared candidate-box instance, so the resumed thread can overwrite the newer
  layout, GUI controls, or Direct2D render target;
- Direct2D `BeginDraw()` and `EndDraw()` are synchronous calls; the ordering failure comes from AutoHotkey thread
  interruption rather than asynchronous renderer completion;
- the `S0` hotkey option controls exemption from `Suspend` and does not serialize hotkey callbacks.

Resolution:

- every `ProcessKey()` receives a monotonically increasing candidate revision;
- candidate `Build()`, `Show()`, and `Hide()` operations reject an older revision before touching shared UI state;
- the revision check and accepted candidate update execute in one short `Critical` section, preventing another input
  thread from interleaving with the renderer;
- Rime processing, caret lookup, and text delivery remain outside the critical section.

Validation:

- the focused input-controller fixture verifies that an outdated revision cannot reach the renderer;
- the accepted revision is observed as critical while executing, and both successful and failed updates restore the
  caller's previous critical state;
- the complete first-party test suite passes with the caret hook disabled.

### BUG-007: Composition survives a foreground-window change

Status: Fixed by `fix(input): clear composition on focus change`

Affected observations:

- switching foreground windows while composing leaves the old candidate box visible;
- the first key in the new window continues the old window's Rime composition;
- [issue #26](https://github.com/rimeinn/rabbit/issues/26) reports the same behavior and identifies
  `clear_composition()` as the Rime reset operation.

Characterization:

- Rabbit uses one Rime session for input in every application and did not associate an active composition with its
  originating foreground window;
- candidate visibility was updated only while handling input, so a foreground change alone could not hide it;
- the existing runtime timer tracks process names for per-process ASCII state, is disabled by `global_ascii`, and cannot
  distinguish two top-level windows from the same process;
- hiding the candidate box without clearing Rime leaves the composition available to the next intercepted key.

Resolution:

- the input controller records the foreground HWND that owns a non-empty composition or candidate menu;
- an independent 50 ms polling timer clears the composition and hides the candidate box when that HWND loses the
  foreground, without installing a Windows event hook;
- `ProcessKey()` performs the same check before sending a new key to Rime, covering a key that arrives before the next
  timer tick;
- focus cleanup increments the candidate revision before hiding, so an interrupted render from the old window cannot
  show the candidate box again;
- input-controller disposal stops the focus timer before unregistering hotkeys and releasing Rime.

Validation:

- the focused input-controller fixture verifies that unchanged focus preserves composition;
- a changed HWND clears the correct Rime session, hides the candidate box, drops its owner, resets previous-placement
  state, and invalidates older rendering;
- an empty Rime context drops the recorded composition owner.

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

Implementation result:

- `RabbitUIStyleSnapshot` resolves all scalar font, geometry, and color values before publication;
- active runtime style and each preview preset are independent snapshot instances;
- constructor and `With()` inputs are copied into scalar properties rather than retained as mutable containers;
- candidate factories, both candidate backends, and the Direct2D preview require explicit styles;
- appearance changes replace the active snapshot and pass the replacement to the selected backend.

### Phase 4: Main application context

Commit: `refactor(runtime): introduce application context`

- create the Rime API at the main entry rather than in `RabbitCommon`;
- introduce `RabbitAppContext` and a top-level lifecycle coordinator;
- separate config snapshot, session state, tray presentation, and per-window ASCII state;
- give input, tray, appearance, timer, message, and hotkey owners narrow dependencies;
- make normal shutdown explicit and ordered.

Implementation result:

- `Rabbit.ahk` constructs its Rime API and delegates startup to `RabbitApplication`;
- `RabbitAppContext` owns the mutex, Rime lifecycle, session, candidate box, configuration, keyboard layout, and
  disposable runtime controllers;
- `RabbitConfigLoader` publishes `RabbitConfigSnapshot` and `RabbitUIStyleSnapshot` values without retaining mutable
  configuration collection aliases;
- input hotkeys and placement state, per-window ASCII and timer state, tray presentation, and appearance messages have
  explicit instance owners;
- normal shutdown unregisters the tray message before disposing hotkeys, the timer, appearance messages, the candidate
  box, the Rime session, Rime, and the mutex;
- the deployer constructs its own explicit Rime API; its context and workflow ownership migration is completed in
  Phase 5.

### Phase 5: Deployer context and dialog ownership

Commit: `refactor(deployer): make workflow ownership explicit`

- create the deployer Rime API at its entry;
- introduce `RabbitDeployerContext`;
- separate deployment workflow coordination from individual dialogs;
- make dialog and preview resource ownership explicit;
- retain lazy Direct2D preview initialization.

Implementation result:

- `RabbitDeployer.ahk` constructs its Rime API and delegates command dispatch and shutdown to
  `RabbitDeployerApplication`;
- `RabbitDeployerContext` owns deployer traits, command state, the Rime initialization boundary, and idempotent
  finalization;
- `RabbitDeployerWorkflow` coordinates configuration, deployment, dictionary, and synchronization paths through an
  explicit Rime dependency, with mutex closure guaranteed on success, early return, and failure;
- settings and dictionary dialogs receive their Rime/levers dependencies, own their acceptance state, and release
  schema lists, dictionary iterators, custom settings, GUI resources, preview bitmaps, and preview renderers explicitly;
- deploy and synchronization paths do not construct levers or dialog services, while old-Windows style configuration
  does not construct a preview; Direct2D remains limited to the supported style-preview path.

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

- the caret hook is disabled by default and remains an explicit user opt-in;
- local tests that can call `GetCaretPosEx` must never enable its hook;
- temporary local caret-hook overrides must be restored and absent from every unrelated diff and commit.

Focused tests:

- snapshot construction and collection access do not retain or expose mutable `Map`/`Array` aliases;
- candidate lifecycle transitions, repeated hide/dispose, and post-dispose failures;
- candidate presentation conversion, including UTF-8 cursor and selection byte offsets;
- label fallback and highlighted candidate mapping;
- style snapshot parsing without shared-state mutation;
- backend factory selection without construction of the unselected backend;
- deployer context initialization/finalization and partial-construction cleanup;
- workflow mutex cleanup and absence of unrelated dialog services in deploy/synchronization paths;
- old-Windows preview suppression and supported-preview disposal.

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
| Phase 3 | style snapshot construction and parsing fixtures | Pass; constructor and override Maps were not retained, and active, dark, and explicit preview schemes stayed independent |
| Phase 3 | candidate lifecycle and local dimensions | Pass; modern remained 160 x 101 and legacy remained 172 x 99 with explicit default snapshots |
| Phase 3 | fresh-process candidate factory and legacy build modes | Pass; all selection modes passed and the calibrated legacy Direct2D probe remained at zero |
| Phase 3 | `Rabbit.ahk` and `RabbitDeployer.ahk` validation | Pass; both entry scripts exited validation with code 0 |
| Phase 3 | supported style preview integration | Pass; preset snapshots rendered positive dimensions and `rabbit.custom.yaml` remained byte-for-byte unchanged |
| Phase 3 | modern real-input path | Pass; `shuru`, `Down`, and `Esc` showed, updated, and hid a `160 x 190` candidate while Direct2D, DirectWrite, and GDI+ were loaded |
| Phase 3 | configured legacy real-input path | Pass with BUG-003 recorded; the active `172 x 190` candidate showed, updated, and hid, and no Direct2D, DirectWrite, or GDI+ module loaded |
| Phase 3 | local configuration restoration | Pass; `use_legacy_candidate_box: true` and `use_caret_hook: false` were restored and redeployed |
| Phase 4 | config snapshot collection boundaries | Pass; constructor inputs and returned copies can be mutated without changing the published snapshot |
| Phase 4 | application-context disposal and partial construction | Pass; every initialized owner is disposed in order and downstream cleanup continues after injected failures |
| Phase 4 | input hotkey registration ownership | Pass; registered hotkeys are disabled by idempotent controller disposal |
| Phase 4 | source validation and focused regression suite | Pass; both entries and both test entries validated, and all first-party fixtures passed |
| Phase 4 | main source startup | Pass; configured-legacy startup remained running for five seconds without a captured exception |
| Phase 4 | modern real-input path | Pass; `shuru`, `Down`, and `Esc` showed, updated, and hid a `160 x 190` candidate while Direct2D, DirectWrite, and GDI+ were loaded |
| Phase 4 | configured legacy real-input path | Pass with BUG-003 unchanged; the active `172 x 190` candidate showed, updated, and hid, and no Direct2D, DirectWrite, or GDI+ module loaded |
| Phase 4 | normal application shutdown | Pass; posting the normal close message exercised the exit callback and the process exited with code 0 |
| Phase 4 | local configuration restoration | Pass; `use_legacy_candidate_box: true` and `use_caret_hook: false` were restored and redeployed |
| Phase 5 | deployer context and workflow ownership fixtures | Pass; Rime finalized once, partial contexts stayed safe, and deploy/sync mutexes closed on success and injected failure |
| Phase 5 | preview construction policy fixtures | Pass; forced old-Windows configuration constructed no preview, while the supported path constructed and disposed exactly one |
| Phase 5 | real levers dialog integration | Pass; hidden switcher and dictionary dialogs loaded actual data and released schema lists, the dictionary iterator, GUI resources, and custom settings |
| Phase 5 | supported style preview integration | Pass; actual preset snapshots rendered positive dimensions and the dialog explicitly released its bitmap and Direct2D preview |
| Phase 5 | `RabbitDeployer.ahk deploy` | Pass; the real deployment path exited with code 0 after explicit workflow and Rime cleanup |
| Phase 5 | repository scope and safety | Pass; no submodule pointer, caret-hook setting, generated runtime file, or BUG-004 behavior changed |
| Post-Phase 5 | nightly deployer handoff regression | Pass after BUG-005 fix; application and tray fixtures require complete main-process Rime and mutex cleanup before child launch |

The local source checks used the available AutoHotkey v2.0.26 interpreter with `/ErrorStdOut`, with both standard output
and standard error captured. A high-frequency visible-window probe was also used to identify the missing-icon exception
before it was fixed. CI remains authoritative for the pinned AutoHotkey v2.0.19 build. No input was sent during the main
application startup check, so the caret hook path was not invoked and no safety override was required.

The running prerelease `Rabbit.exe` was stopped before validation because it held the application runtime state. It was
not restarted.
