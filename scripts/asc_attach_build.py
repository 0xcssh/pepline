#!/usr/bin/env python3
"""Waits for the newest processed build of the version and attaches it to the
editable App Store version (ready for "Add for Review").

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (or ASC_KEY_P8_FILE),
VERSION (default 1.0.0), MIN_BUILD (only builds above this number),
WAIT_MINUTES (default 30).
"""
import os
import sys
import time

import jwt
import requests

sys.stdout.reconfigure(encoding="utf-8")
KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
P8 = os.environ.get("ASC_KEY_P8") or open(os.environ["ASC_KEY_P8_FILE"]).read()
APP_ID = "6823184469"
VERSION = os.environ.get("VERSION", "1.0.0")
MIN_BUILD = int(os.environ.get("MIN_BUILD", "0"))
DEADLINE = time.time() + 60 * int(os.environ.get("WAIT_MINUTES", "30"))
BASE = "https://api.appstoreconnect.apple.com"


def call(method, path, body=None, params=None):
    now = int(time.time())
    tok = jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                     P8, algorithm="ES256", headers={"kid": KEY_ID})
    r = requests.request(method, BASE + path, json=body, params=params,
                         headers={"Authorization": f"Bearer {tok}"}, timeout=60)
    if r.status_code >= 400:
        raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:500]}")
    return r.json() if r.text else {}


while True:
    builds = call("GET", "/v1/builds", params={"filter[app]": APP_ID, "filter[preReleaseVersion.version]": VERSION,
                                               "limit": 50})["data"]
    newer = [b for b in builds if int(b["attributes"]["version"]) > MIN_BUILD]
    newest = max(newer, key=lambda b: int(b["attributes"]["version"]), default=None)
    state = newest["attributes"]["processingState"] if newest else "not visible yet"
    print(time.strftime("%H:%M"), "build", newest["attributes"]["version"] if newest else "-", state, flush=True)
    if newest and state == "VALID":
        break
    if newest and state in ("FAILED", "INVALID"):
        sys.exit("processing failed: check the email from App Store Connect")
    if time.time() > DEADLINE:
        sys.exit("timed out waiting for processing")
    time.sleep(60)

version = next(v for v in call("GET", f"/v1/apps/{APP_ID}/appStoreVersions")["data"]
               if v["attributes"]["versionString"] == VERSION)
call("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build",
     {"data": {"type": "builds", "id": newest["id"]}})
print(f"attached build {newest['attributes']['version']} to {VERSION}")
