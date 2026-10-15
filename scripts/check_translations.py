"""Fail CI unless every string in every String Catalog is translated into
every language of scripts/locales.json, with the same format specifiers.

Usage: python3 scripts/check_translations.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
locales = json.loads((ROOT / "scripts" / "locales.json").read_text(encoding="utf-8"))["app"]
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f)")


def values(localization):
    """Every string of one localization, including plural/device variations."""
    if "stringUnit" in localization:
        yield localization["stringUnit"]
    for cases in localization.get("variations", {}).values():
        for case in cases.values():
            yield from values(case)


problems = []
catalogs = sorted(ROOT.glob("Pepline/**/*.xcstrings"))
for catalog in catalogs:
    strings = json.loads(catalog.read_text(encoding="utf-8"))["strings"]
    for key, entry in strings.items():
        if entry.get("shouldTranslate") is False:
            continue
        expected = sorted(SPECIFIER.findall(key))
        localizations = entry.get("localizations", {})
        for locale in locales:
            if locale not in localizations:
                problems.append(f"{catalog.name}: {key!r} missing {locale}")
                continue
            for unit in values(localizations[locale]):
                if unit.get("state") != "translated" or not unit.get("value"):
                    problems.append(f"{catalog.name}: {key!r} {locale} not translated")
                elif "variations" not in localizations[locale] and sorted(SPECIFIER.findall(unit["value"])) != expected:
                    problems.append(f"{catalog.name}: {key!r} {locale} format specifiers differ")

print(f"{len(catalogs)} catalog(s), {len(locales)} languages checked")
if problems:
    print("\n".join(problems))
    sys.exit(f"{len(problems)} translation problem(s)")
