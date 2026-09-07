# Rabbit translations

The migration covers the tray menu, all modern settings pages, key binding,
color scheme and advanced font dialogs, and the standalone About dialog.
Settings status messages, confirmations and validation messages are translated.
Legacy deployer dialogs and frontend notifications are not fully migrated.
Schema names, user content and Rime-provided mode labels retain their original text.

## Choose a language

In the control panel, open **Input and behavior → Interface**, choose a language,
and select **Apply and redeploy**. This writes the `language` patch in
`rabbit.custom.yaml`. Alternatively, edit that file in the Rime user folder:

```yaml
patch:
  language: en-US
```

Merge this into the existing `patch` mapping, then redeploy Rabbit. Both
executables read the deployed `rabbit` configuration after initializing Rime;
editing the custom file alone does not change the active language. The frontend
loads the new language when it resumes after deployment. After a successful deployment, the open control panel is rebuilt only if the
resolved UI language changes. Its page, selected subtab and screen position are
restored (position is clamped to the available work area). Other deployments keep
the existing window. Failed deployments do not trigger reconstruction. If other
settings still have unsaved changes, reconstruction waits until they are resolved;
closing the panel still closes the session instead of reopening it.

Official values are `auto` (default), `zh-CN`, `en-US`, `zh-HK`, and `zh-TW`.
Aliases `zh`/`zh-Hans`, `zh-Hant`, and `en` select zh-CN, zh-TW, and en-US.
The picker also discovers additional catalogs as described below. `auto` uses the Windows
user locale. English locales map to en-US; zh-HK/zh-MO (including zh-Hant-HK/MO)
map to zh-HK; zh-TW and other zh-Hant locales map to zh-TW. Simplified Chinese
locales and unsupported preferences fall back to zh-CN. An explicit zh-Hans
script remains Simplified Chinese even if its region is HK.

The Hong Kong and Taiwan catalogs are maintained independently to preserve
regional terminology (for example 用戶/使用者 and 快捷鍵/快速鍵). Catalog checks
verify both against the default Chinese catalog, including placeholder names.

The bundled `ja-JP.ini` provides a complete Japanese translation and is discovered
through its metadata. It is included in the catalog completeness tests without
being added to the hard-coded official language choices.

## Additional languages

Place `<lang-code>.ini` in `locales`, for example `ja-JP.ini`:

```ini
[meta]
locale=ja-JP
language_name=日本語

[common]
cancel=キャンセル
```

Both metadata values must be present and nonempty. `meta.locale` must match the
filename (case-insensitively); codes use letters and digits separated by hyphens,
with a 2–8-letter initial language subtag and 1–8-character subsequent subtags.
The language picker displays `meta.language_name`. Missing metadata, mismatched
codes and duplicate metadata keys are skipped. Discovery reads only metadata and
does not check translation completeness; even a metadata-only catalog is allowed.
Missing messages use the normal Chinese fallback. Runtime loading still handles
malformed catalog syntax with the existing fallback and diagnostics.

Official choices and their reserved aliases remain available without files and
cannot be duplicated by alias-named files. Extra languages appear after official
choices in filename order. An exact discovered locale (such as en-GB) takes
precedence over regional fallback; reserved aliases such as en still select the
official language. A configured but unavailable extra language displays its
fallback without adding an invalid catalog entry, and its saved code is retained
when only unrelated settings are edited. Reopen the panel to refresh its list
after adding catalogs, then apply and redeploy to change language.

## Catalog format

Files are UTF-8, with or without BOM. Use `[feature]` sections and stable semantic
`snake_case` keys. Code calls `RabbitI18n.Text("feature.key")`. Keys are case
sensitive. Blank lines and full-line `;` comments are supported. Do not quote
values. Leading/trailing whitespace is trimmed; inline semicolons are literal.
Duplicate keys, invalid lines, and unknown escapes are errors.

Use complete sentences and named placeholders such as `{schema}`. Supply values
with `RabbitI18n.Text("notification.schema_changed", Map("schema", schema_name))`.
Placeholders can be reordered and repeated. Replacement values are inserted once
and never interpreted as templates. Unsupplied placeholders remain visible.
Use `\n` for line breaks, `\r` for carriage returns and `\\` for a literal
backslash. Other characters, including equals signs, are literal in values.

Lookup order is the selected locale file, the Chinese locale file, then the
embedded Chinese catalog. Missing or empty values fall back to the next level.
The application can start without the entire `locales` directory. Missing,
unreadable or malformed external catalogs are ignored at runtime and reported to
OutputDebug and `RabbitI18n.diagnostics`; `ReadCatalog` remains strict for tests.
Keys absent from all three levels are displayed as keys and reported to OutputDebug.
The embedded catalog is included in compiled executables and source distributions.

After changing `locales/zh-CN.ini`, regenerate its checked-in fallback:

```powershell
python scripts/generate_locale_fallback.py
```

The unit suite verifies exact key and value parity with the Chinese source.
Python is needed only for regeneration, not for running Rabbit.
Keep layout dimensions out of catalogs. Add translator context with comments.
Plural selection is not implemented; do not build English-only plural rules into
call sites. Add a dedicated plural API when a real count-dependent message needs it.

## Validation

Run from the repository root:

```powershell
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitI18nTest.ahk
```

The test checks bundled catalog keys and placeholder sets, locale resolution,
fallback, escape decoding, and literal placeholder substitution. It also runs
through `tests/unit/RabbitTests.ahk`. Package the `locales/*.ini` files beside both
executables; CI includes them in both release artifacts.

## Settings regression tests

```powershell
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitLocalizationTest.ahk
```

This checks English controls and dialog creation, delayed static labels, unchanged
configuration keys and user content, and catalog references in first-party modules.
The complete unit suite also checks Chinese behavior. Manual layout and interaction
verification is required for each language, especially at higher DPI settings.
