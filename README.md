# Accentuate

Type French on a US keyboard, skip the accents, and let them appear on their own.

Accentuate lives in the menu bar. When you finish a word, it turns `ecole` into `école`, `tres` into `très` and `deja` into `déjà`, in any app. It only steps in when you are writing French, and it works entirely offline.

## Using it

1. Run `Scripts/bundle.sh --install`. It builds Accentuate, copies it to `/Applications` and launches it.
2. Allow Accentuate under **System Settings → Privacy & Security → Accessibility**. The menu bar item shows the status and links straight to that pane.
3. Type. Accents are added as soon as you hit space, punctuation, tab or return.

Menu bar options:

- **Enabled** – pause and resume.
- **Assume French** – always correct, without waiting for French to be detected.

## Good to know

- **Undo:** press Backspace right after a correction to get your original word back. It will not be corrected again.
- **Context matters:** `decide` becomes `décidé` in "nous avons decide" and `décide` in "il decide". Words that are valid both ways (`a`/`à`, `ou`/`où`, `sur`/`sûr`, `la`/`là`, `mange`/`mangé`…) are only changed when the words before them make the accent obvious, as in "par rapport à" or "bien sûr". When in doubt, nothing happens.
- **Capitalization is kept:** `Ecole` becomes `École`, `ECOLE` becomes `ÉCOLE`.
- **Names stay untouched:** capitalized words in the middle of a sentence are left alone.
- **Stays out of the way:** it ignores password fields, shortcuts, arrow keys and mouse clicks, and starts fresh when you switch apps.
- **Fast bursts:** with keys arriving faster than about 30 ms apart (well beyond fast typing) a correction can garble the word.

## Development

```
swift test            # unit tests for the core logic
Scripts/bundle.sh     # build a signed Accentuate.app in ./build
```

Accents come from the French spell checker built into macOS, so no network or extra download is needed. `Tools/build_dictionary.py` regenerates the word-frequency table from `Tools/dict-src/fr_50k.txt`.

Data sources and licenses are listed in [NOTICE](NOTICE).
