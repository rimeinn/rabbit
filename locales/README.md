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
loads the new language when it resumes after deployment. An already open deployer
keeps its language until reopened.

Supported values are `auto` (default), `zh-CN`, and `en-US`. `auto` uses the
Windows user locale: English locales use en-US; other locales currently fall
back to zh-CN. Unsupported preferences also fall back to zh-CN.

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
