#!/usr/bin/env python3
"""Replace the iPhone 6.7" screenshots of every localization of the editable
App Store version with the images in SHOTS_DIR/<locale>/<n>.jpg (or .png).

Locales without their own folder fall back (en-GB/en-AU/en-CA -> en-US).
Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (or ASC_KEY_P8_FILE), APP_ID, SHOTS_DIR, DRY_RUN,
VERSION (version string to create if no editable version exists).
"""
import hashlib
import json
import os
import sys
import time

import jwt
import requests

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
P8 = os.environ.get("ASC_KEY_P8") or open(os.environ["ASC_KEY_P8_FILE"]).read()
APP_ID = os.environ.get("APP_ID", "6823184469")
DRY = os.environ.get("DRY_RUN", "1") == "1"
SHOTS = os.environ.get("SHOTS_DIR", "shots")
VERSION = os.environ.get("VERSION", "1.0")
# 1290 x 2796 PNGs from PeplineTests/MarketingScreenshotTests.
DISPLAY = "APP_IPHONE_67"
FALLBACK = {"en-GB": "en-US", "en-AU": "en-US", "en-CA": "en-US"}
BASE = "https://api.appstoreconnect.apple.com"


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      P8, algorithm="ES256", headers={"kid": KEY_ID})


def call(method, path, body=None, params=None):
    if DRY and method != "GET":
        print(f"  [dry] {method} {path}")
        return {"data": {"id": "DRY", "attributes": {"uploadOperations": []}}}
    r = requests.request(method, BASE + path, json=body, params=params,
                         headers={"Authorization": f"Bearer {token()}"}, timeout=120)
    if r.status_code >= 400:
        raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:600]}")
    return r.json() if r.text else {}


def paged(path, params=None):
    out, url = [], path
    while url:
        j = call("GET", url.replace(BASE, ""), params=params)
        out += j["data"]
        url = j.get("links", {}).get("next")
        params = None
    return out


# ---- editable version
versions = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions", params={"limit": 5})["data"]
editable = [v for v in versions if v["attributes"]["appVersionState"] in
            ("PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW")]
if editable:
    version = editable[0]
else:
    print(f"no editable version — creating {VERSION}")
    version = call("POST", "/v1/appStoreVersions",
                   {"data": {"type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": VERSION},
                             "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]
print(f"version {version['attributes'].get('versionString', VERSION)} ({version['attributes'].get('appVersionState')})")

locs = paged(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
for loc in locs:
    locale = loc["attributes"]["locale"]
    src = FALLBACK.get(locale, locale)
    folder = os.path.join(SHOTS, src)
    files = sorted((f for f in os.listdir(folder) if f.endswith((".png", ".jpg"))), key=lambda f: int(f.split(".")[0])) if os.path.isdir(folder) else []
    if not files:
        print(f"{locale}: no images for {src}, skipped")
        continue
    sets = paged(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY), None)
    if sset is None:
        sset = call("POST", "/v1/appScreenshotSets",
                    {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY},
                              "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
        old = []
    else:
        old = paged(f"/v1/appScreenshotSets/{sset['id']}/appScreenshots")
    print(f"{locale}: {len(old)} existing -> {len(files)} new (from {src})")
    for o in old:
        call("DELETE", f"/v1/appScreenshots/{o['id']}")
    for f in files:
        data = open(os.path.join(folder, f), "rb").read()
        res = call("POST", "/v1/appScreenshots",
                   {"data": {"type": "appScreenshots",
                             "attributes": {"fileName": f"{src}-{f}", "fileSize": len(data)},
                             "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})
        sid = res["data"]["id"]
        for op in res["data"]["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
            r = requests.request(op["method"], op["url"], data=chunk, headers=headers, timeout=300)
            r.raise_for_status()
        call("PATCH", f"/v1/appScreenshots/{sid}",
             {"data": {"type": "appScreenshots", "id": sid,
                       "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"  uploaded {len(files)}")
print("DRY RUN — nothing written" if DRY else "done")
