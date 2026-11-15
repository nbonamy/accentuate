# Accentuate

Type French, Spanish, Italian, Portuguese or German on a US keyboard, skip the accents, and let them appear on their own.

Accentuate lives in the menu bar. When you finish a word, it turns `ecole` into `école`, `tres` into `très` and `manana` into `mañana`, in any app. It works out the language as you type, or you can pick one, and it works entirely offline. French gets the most care, since it has the most ambiguous words.

## Using it

1. Download the latest zip from [Releases](https://github.com/nbonamy/accentuate/releases), drag Accentuate to `/Applications` and open it. (Or run `Scripts/bundle.sh --install` to build it yourself.)
2. Allow Accentuate under **System Settings → Privacy & Security → Accessibility**. The menu bar item shows the status and links straight to that pane.
3. Type. Accents are added as soon as you hit space, punctuation, tab or return. Accentuate rereads the whole sentence at every word and once more at the closing `.`, `?`, `!` or return, so early words and ambiguous ones get fixed once the rest of the sentence is known.

Open **Settings** from the menu bar icon to:

- pause and resume corrections, and choose the language or let Accentuate detect it,
- set how sure Accentuate must be that you are writing that language (cautious, balanced or eager) before it adds anything, so English text, commands and code are left alone,
- start Accentuate at login,
- hide the menu bar icon,
- list apps where it should never correct.

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
Scripts/bundle.sh     # build a signed Accentuate.app in ./build (add --install for /Applications)
Scripts/release.sh 1.0.0   # sign, notarize and publish a GitHub release
```

Accents come from the spell checker built into macOS, so no network or extra download is needed. `Tools/build_dictionary.py` regenerates the French word-frequency table from `Tools/dict-src/fr_50k.txt`.

Data sources and licenses are listed in [NOTICE](NOTICE).
