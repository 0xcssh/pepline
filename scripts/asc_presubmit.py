#!/usr/bin/env python3
"""Pre-submission settings App Store Connect needs before 1.0 can be submitted.

Idempotent: reads first, writes only what is missing or different.
- App Store version string = the builds' CFBundleShortVersionString (1.0.0)
- Copyright (same owner line as RepLock)
- Content rights: uses third-party content (Open Food Facts data, ODbL)
- Price: free (USA base territory)
- Availability: every territory except mainland China (needs an ICP filing
  number we do not have), new territories on.
Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (or ASC_KEY_P8_FILE), DRY_RUN.
"""
import json
import os
import sys
import time

import jwt
import requests

sys.stdout.reconfigure(encoding="utf-8")
KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
P8 = os.environ.get("ASC_KEY_P8") or open(os.environ["ASC_KEY_P8_FILE"]).read()
DRY = os.environ.get("DRY_RUN", "1") == "1"
APP_ID = "6823184469"
VERSION = "1.0.0"
COPYRIGHT = "2026 Awdi Ltd"
EXCLUDED = {"CHN"}
BASE = "https://api.appstoreconnect.apple.com"


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      P8, algorithm="ES256", headers={"kid": KEY_ID})


def call(method, path, body=None, params=None, ok=(200, 201, 204)):
    if DRY and method != "GET":
        print(f"  [dry] {method} {path}")
        return {}
    r = requests.request(method, BASE + path, json=body, params=params,
                         headers={"Authorization": f"Bearer {token()}"}, timeout=60)
    if r.status_code not in ok:
        raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:700]}")
    return r.json() if r.text else {}


# Version string and copyright on the editable version.
versions = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions")["data"]
version = next(v for v in versions if v["attributes"]["appVersionState"] == "PREPARE_FOR_SUBMISSION")
attrs = {}
if version["attributes"]["versionString"] != VERSION:
    attrs["versionString"] = VERSION
if version["attributes"].get("copyright") != COPYRIGHT:
    attrs["copyright"] = COPYRIGHT
print(f"version {version['attributes']['versionString']}: {attrs or 'unchanged'}")
if attrs:
    call("PATCH", f"/v1/appStoreVersions/{version['id']}",
         {"data": {"type": "appStoreVersions", "id": version["id"], "attributes": attrs}})

# Content rights.
app = call("GET", f"/v1/apps/{APP_ID}")["data"]
if app["attributes"].get("contentRightsDeclaration") != "USES_THIRD_PARTY_CONTENT":
    print("content rights: USES_THIRD_PARTY_CONTENT (Open Food Facts, ODbL)")
    call("PATCH", f"/v1/apps/{APP_ID}",
         {"data": {"type": "apps", "id": APP_ID, "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"}}})
else:
    print("content rights: unchanged")

# Price: free.
r = requests.get(f"{BASE}/v1/apps/{APP_ID}/appPriceSchedule/manualPrices", headers={"Authorization": f"Bearer {token()}"})
if r.status_code == 200 and r.json().get("data"):
    print("price: already set")
else:
    points = call("GET", f"/v1/apps/{APP_ID}/appPricePoints", params={"filter[territory]": "USA", "limit": 5})["data"]
    free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0)
    print("price: free")
    call("POST", "/v1/appPriceSchedules", {
        "data": {"type": "appPriceSchedules",
                 "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}},
                                   "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                                   "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}",
                      "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})

# Availability.
r = requests.get(f"{BASE}/v1/apps/{APP_ID}/appAvailabilityV2", headers={"Authorization": f"Bearer {token()}"})
if r.status_code == 200:
    print("availability: already set")
else:
    # Every territory must be listed; the excluded ones are marked unavailable.
    territories = [t["id"] for t in call("GET", "/v1/territories", params={"limit": 200})["data"]]
    print(f"availability: {len(territories) - len(EXCLUDED)} territories (excluded {sorted(EXCLUDED)})")
    call("POST", "/v2/appAvailabilities", {
        "data": {"type": "appAvailabilities",
                 "attributes": {"availableInNewTerritories": True},
                 "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}},
                                   "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in territories]}}},
        "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}",
                      "attributes": {"available": t not in EXCLUDED},
                      "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for t in territories]})
print("dry run, nothing written" if DRY else "done")
