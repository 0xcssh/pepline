#!/usr/bin/env python3
"""Apply product-page updates to App Store Connect from a JSON file.

Runs in CI or locally. Input file shape (scripts/listing/<version>.json):

{
  "version": "1.0.3",
  "localizations": {
    "en-US": {"description": "...", "whatsNew": "...", "promotionalText": "...", "keywords": "..."},
    "fr-FR": {...}
  },
  "appInfo": {
    "es-ES": {"name": "...", "subtitle": "..."}
  },
  "urls": {"privacyPolicyUrl": "...", "supportUrl": "...", "marketingUrl": "..."}
}

Version localizations that do not exist yet are created; appInfo
localizations too. `urls` go to every locale (privacy policy on the app
info, support and marketing on the version). Only the keys present are
changed. Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (or ASC_KEY_P8_FILE),
APP_ID, LISTING_FILE, DRY_RUN ("1" = print only).
"""
import json
import os
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")

import jwt
import requests

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
P8 = os.environ.get("ASC_KEY_P8") or open(os.environ["ASC_KEY_P8_FILE"]).read()
APP_ID = os.environ.get("APP_ID", "6823184469")
DRY = os.environ.get("DRY_RUN", "0") == "1"
BASE = "https://api.appstoreconnect.apple.com"

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotionalText": 170,
          "description": 4000, "whatsNew": 4000}


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      P8, algorithm="ES256", headers={"kid": KEY_ID})


def call(method, path, body=None, params=None):
    r = requests.request(method, BASE + path, json=body, params=params,
                         headers={"Authorization": f"Bearer {token()}"}, timeout=60)
    if r.status_code >= 400:
        raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:500]}")
    return r.json() if r.text else {}


def check_limits(locale, attrs):
    for k, v in attrs.items():
        if k in LIMITS and v is not None and len(v) > LIMITS[k]:
            sys.exit(f"{locale}.{k} is {len(v)} chars, limit {LIMITS[k]}")


spec = json.load(open(os.environ["LISTING_FILE"], encoding="utf-8"))
version_string = spec["version"]
urls = spec.get("urls", {})
for locale in spec.get("localizations", {}):
    spec["localizations"][locale] = dict(spec["localizations"][locale],
                                         **{k: v for k, v in urls.items() if k in ("supportUrl", "marketingUrl")})
for locale in spec.get("appInfo", {}):
    if "privacyPolicyUrl" in urls:
        spec["appInfo"][locale] = dict(spec["appInfo"][locale], privacyPolicyUrl=urls["privacyPolicyUrl"])
# Fail before writing anything if one field is over its limit.
for locale, attrs in list(spec.get("localizations", {}).items()) + list(spec.get("appInfo", {}).items()):
    check_limits(locale, attrs)

versions = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions",
                params={"filter[versionString]": version_string})["data"]
if not versions:
    sys.exit(f"no App Store version {version_string} found")
version = versions[0]
print(f"version {version_string}: {version['attributes']['appVersionState']} ({version['id']})")

# ---- version-level localizations (description, keywords, what's new, promo text)
existing = {l["attributes"]["locale"]: l for l in
            call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations",
                 params={"limit": 50})["data"]}
for locale, attrs in spec.get("localizations", {}).items():
    check_limits(locale, attrs)
    if locale in existing:
        loc = existing[locale]
        changed = {k: v for k, v in attrs.items() if loc["attributes"].get(k) != v}
        if not changed:
            print(f"  {locale}: unchanged")
            continue
        print(f"  {locale}: update {sorted(changed)}")
        if not DRY:
            call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}",
                 {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": changed}})
    else:
        print(f"  {locale}: CREATE with {sorted(attrs)}")
        if not DRY:
            call("POST", "/v1/appStoreVersionLocalizations",
                 {"data": {"type": "appStoreVersionLocalizations",
                           "attributes": dict(attrs, locale=locale),
                           "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})

# ---- app-info localizations (name, subtitle) on the editable appInfo
if spec.get("appInfo"):
    infos = call("GET", f"/v1/apps/{APP_ID}/appInfos")["data"]
    editable = [i for i in infos if i["attributes"].get("state") != "READY_FOR_DISTRIBUTION"] or infos
    info = editable[0]
    print(f"appInfo {info['id']} ({info['attributes'].get('state')})")
    existing = {l["attributes"]["locale"]: l for l in
                call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations", params={"limit": 50})["data"]}
    for locale, attrs in spec["appInfo"].items():
        check_limits(locale, attrs)
        if locale in existing:
            loc = existing[locale]
            changed = {k: v for k, v in attrs.items() if loc["attributes"].get(k) != v}
            if not changed:
                print(f"  {locale}: unchanged")
                continue
            print(f"  {locale}: update {sorted(changed)}")
            if not DRY:
                call("PATCH", f"/v1/appInfoLocalizations/{loc['id']}",
                     {"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": changed}})
        else:
            print(f"  {locale}: CREATE with {sorted(attrs)}")
            if not DRY:
                call("POST", "/v1/appInfoLocalizations",
                     {"data": {"type": "appInfoLocalizations",
                               "attributes": dict(attrs, locale=locale),
                               "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
print("dry run, nothing written" if DRY else "done")
