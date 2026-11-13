#!/usr/bin/env python3
"""Builds Sources/AccentuateCore/Resources/accents.tsv from the FrequencyWords French list.

Input (Tools/dict-src):
  fr_50k.txt   "word count" frequency list (https://github.com/hermitdave/FrequencyWords)

Output line: <unaccented key> TAB <spelling>:<freq> TAB <spelling>:<freq> ...
Only keys with at least one accented spelling are written; the plain spelling is
listed too when the corpus has it. The app uses this only as evidence of which
spelling is the common one, the spell checker decides what is a word.
"""
import pathlib
import re
import unicodedata

root = pathlib.Path(__file__).resolve().parent
src = root / "dict-src"
out = root.parent / "Sources/AccentuateCore/Resources/accents.tsv"

WORD = re.compile(r"^[a-zàâäçéèêëîïôöùûüÿœæ]+$")


def strip(word: str) -> str:
    word = word.replace("œ", "oe").replace("æ", "ae")
    return "".join(
        c for c in unicodedata.normalize("NFD", word) if unicodedata.category(c) != "Mn"
    )


groups: dict[str, dict[str, int]] = {}
for line in (src / "fr_50k.txt").read_text(encoding="utf-8").splitlines():
    parts = line.split()
    if len(parts) == 2 and WORD.match(parts[0]):
        groups.setdefault(strip(parts[0]), {})[parts[0]] = int(parts[1])

lines = []
for key, spellings in sorted(groups.items()):
    if not any(w != key for w in spellings):
        continue
    ranked = sorted(spellings.items(), key=lambda kv: -kv[1])
    lines.append(key + "\t" + "\t".join(f"{w}:{c}" for w, c in ranked))

out.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"{len(lines)} keys -> {out}")
