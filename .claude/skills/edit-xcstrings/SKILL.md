---
name: edit-xcstrings
description: Read, navigate, and edit the String Catalog (Localizable.xcstrings). Use whenever adding or changing translations, or looking up an existing localization.
---

# Edit xcstrings

`Localizable.xcstrings` is a large (~1600+ line) JSON String Catalog. The source language is `en`; translations live under `localizations.<lang>.stringUnit.value`. Editing it naively corrupts it — follow this workflow.

## Golden rule

**Never rewrite the file with Python / `json.dump`.** It reorders keys, re-escapes accented characters (`é`, `à`, apostrophes), and produces a massive diff that's easy to corrupt. Python is **read-only** here: use it to *locate* and to *validate*, never to write. All writes go through the `Edit` tool on a small, unique snippet.

## Workflow

1. **Locate** the key — don't read the whole file:
   ```sh
   grep -n '"the exact key"' Localizable.xcstrings
   ```
   Or list/inspect with read-only Python:
   ```sh
   python3 -c "import json; d=json.load(open('Localizable.xcstrings')); print(json.dumps(d['strings']['KEY'], ensure_ascii=False, indent=2))"
   ```

2. **Read narrowly** — `Read` with `offset`/`limit` around the line(s) `grep` reported. Never slurp the full file into context.

3. **Iterate in chat first** — propose and refine the wording with the user. Touch no file until they confirm the final text.

4. **Edit surgically** — once confirmed, use the `Edit` tool per key. Include enough surrounding context to match exactly one location.
   - **Watch for duplicate values.** Different keys can share an English/translated string (e.g. the literal `"Add a metric"` key vs `empty_dashboard.add_metric`). If `Edit` reports multiple matches, add more context to disambiguate — do **not** blindly `replace_all`.
   - A key with no translation yet looks like `"Key" : {\n\n    },` — replace the empty body with a full `localizations` block (see shape below).

5. **Validate** — confirm the JSON still parses and the change landed:
   ```sh
   python3 -c "import json; d=json.load(open('Localizable.xcstrings')); print(d['strings']['KEY']['localizations']['fr']['stringUnit']['value'])"
   ```

## Entry shape

```json
"Some key" : {
  "localizations" : {
    "fr" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "La traduction"
      }
    }
  }
}
```

- Indentation is 2 spaces; Xcode writes `"key" : {` with a space before the colon — match it.
- Set `"state" : "translated"` for finished translations.
- Languages currently in the catalog: `en` (source), `es`, `fr`.
