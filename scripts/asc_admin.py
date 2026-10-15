#!/usr/bin/env python3
"""Pepline Pro subscriptions through the App Store Connect API, driven by
scripts/store.json and scripts/locales.json. Idempotent: every action checks
what exists first, so it can be re-run after a partial failure.

Actions (ACTION env var; DRY_RUN=1, the default, prints without writing):
  status   group, subscriptions, USA price, trial, localizations, grace period
  setup    create the group and every product of store.json: localizations
           in every language, availability, USA base price + equalized
           territories, free trial in every territory
  grace    opt into the 16-day billing grace period (all renewals)

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (PEM text), APP_ID.
Ported from ../replock/scripts/asc_admin.py (pitfalls in docs/LESSONS.md §1.5:
availability before price, the API does not equalize prices, descriptions
max 55 characters).
"""
import json
import os
import pathlib
import sys
import time

import jwt
import requests

sys.stdout.reconfigure(encoding="utf-8")  # Windows consoles default to cp1252
ROOT = pathlib.Path(__file__).resolve().parent
STORE = json.loads((ROOT / "store.json").read_text(encoding="utf-8"))
LOCALES = json.loads((ROOT / "locales.json").read_text(encoding="utf-8"))
ASC_LOCALE = LOCALES["asc"]

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
P8 = os.environ["ASC_KEY_P8"]
APP_ID = os.environ["APP_ID"]
DRY = os.environ.get("DRY_RUN", "1") == "1"
ACTION = os.environ.get("ACTION", "status")
BASE = "https://api.appstoreconnect.apple.com"


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      P8, algorithm="ES256", headers={"kid": KEY_ID})


def call(method, path, body=None, params=None, ok404=False):
    if DRY and method != "GET":
        print(f"  [dry] {method} {path} {json.dumps(body, ensure_ascii=False)[:300]}")
        return {"data": {"id": "DRY"}}
    r = requests.request(method, BASE + path, json=body, params=params,
                         headers={"Authorization": f"Bearer {token()}"}, timeout=60)
    if r.status_code == 404 and ok404:
        return None
    if r.status_code >= 400:
        raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:800]}")
    return r.json() if r.text else {}


def paged(path, params=None):
    if path.startswith("/v1/subscriptions/DRY") or path.startswith("/v1/subscriptionGroups/DRY"):
        return []
    out, url = [], path
    while url:
        j = call("GET", url.replace(BASE, ""), params=params)
        out += j["data"]
        url = j.get("links", {}).get("next")
        params = None
    return out


def rel(kind, id_):
    return {"data": {"type": kind, "id": id_}}


def discover():
    groups = call("GET", f"/v1/apps/{APP_ID}/subscriptionGroups", params={"include": "subscriptions"})
    group = next((g for g in groups["data"] if g["attributes"]["referenceName"] == STORE["group"]["referenceName"]), None)
    subs = {s["attributes"]["productId"]: s for s in groups.get("included", []) if s["type"] == "subscriptions"}
    return group, subs


def price_point(sub_id, territory, customer_price):
    pts = paged(f"/v1/subscriptions/{sub_id}/pricePoints",
                {"filter[territory]": territory, "limit": 200, "fields[subscriptionPricePoints]": "customerPrice,proceeds"})
    for p in pts:
        if p["attributes"]["customerPrice"] == customer_price:
            return p
    raise SystemExit(f"no price point {customer_price} in {territory}")


def ensure_group():
    group, _ = discover()
    if group:
        print(f"group exists: {group['id']}")
        gid = group["id"]
    else:
        gid = call("POST", "/v1/subscriptionGroups",
                   {"data": {"type": "subscriptionGroups",
                             "attributes": {"referenceName": STORE["group"]["referenceName"]},
                             "relationships": {"app": rel("apps", APP_ID)}}})["data"]["id"]
        print(f"group created: {gid}")
    have = {l["attributes"]["locale"] for l in paged(f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations")}
    for lang, name in STORE["group"]["name"].items():
        if ASC_LOCALE[lang] in have:
            continue
        call("POST", "/v1/subscriptionGroupLocalizations",
             {"data": {"type": "subscriptionGroupLocalizations",
                       "attributes": {"locale": ASC_LOCALE[lang], "name": name},
                       "relationships": {"subscriptionGroup": rel("subscriptionGroups", gid)}}})
    print(f"group localizations: {len(STORE['group']['name']) - len(have & set(ASC_LOCALE.values()))} added")
    return gid


def ensure_product(gid, product, subs):
    pid = product["productId"]
    if pid in subs:
        sid = subs[pid]["id"]
        print(f"{pid}: exists ({subs[pid]['attributes']['state']})")
    else:
        sid = call("POST", "/v1/subscriptions",
                   {"data": {"type": "subscriptions",
                             "attributes": {"name": product["referenceName"], "productId": pid,
                                            "subscriptionPeriod": product["period"], "familySharable": False,
                                            "reviewNote": product["reviewNote"]},
                             "relationships": {"group": rel("subscriptionGroups", gid)}}})["data"]["id"]
        print(f"{pid}: created {sid}")

    # Localizations: name + description in every app language.
    have = {l["attributes"]["locale"] for l in paged(f"/v1/subscriptions/{sid}/subscriptionLocalizations")}
    for lang, name in product["name"].items():
        if ASC_LOCALE[lang] in have:
            continue
        description = STORE["description"][lang]
        assert len(description) <= 55, (lang, description)
        call("POST", "/v1/subscriptionLocalizations",
             {"data": {"type": "subscriptionLocalizations",
                       "attributes": {"locale": ASC_LOCALE[lang], "name": name, "description": description},
                       "relationships": {"subscription": rel("subscriptions", sid)}}})

    if sid == "DRY":
        print(f"  [dry] would set availability, USA {product['usd']} + equalizations, trial {product['freeTrial']}")
        return

    # Availability must exist before any price can be attached.
    territories = [t["id"] for t in paged("/v1/territories", {"limit": 200})]
    if call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", ok404=True) is None:
        call("POST", "/v1/subscriptionAvailabilities",
             {"data": {"type": "subscriptionAvailabilities",
                       "attributes": {"availableInNewTerritories": True},
                       "relationships": {"subscription": rel("subscriptions", sid),
                                         "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]}}}})
        print(f"  availability: {len(territories)} territories")

    # Prices: the USA base price, then one row per territory from Apple's
    # equalizations (the API does not equalize by itself).
    priced = {p["relationships"]["territory"]["data"]["id"]
              for p in paged(f"/v1/subscriptions/{sid}/prices", {"limit": 200, "include": "territory"})
              if p.get("relationships", {}).get("territory", {}).get("data")}
    base = price_point(sid, "USA", product["usd"])
    points = [base] + paged(f"/v1/subscriptionPricePoints/{base['id']}/equalizations",
                            {"limit": 200, "include": "territory"})
    added = 0
    for point in points:
        territory = (point.get("relationships", {}).get("territory", {}).get("data") or {"id": "USA"})["id"]
        if territory in priced:
            continue
        call("POST", "/v1/subscriptionPrices",
             {"data": {"type": "subscriptionPrices",
                       "relationships": {"subscription": rel("subscriptions", sid),
                                         "subscriptionPricePoint": rel("subscriptionPricePoints", point["id"])}}})
        priced.add(territory)
        added += 1
    print(f"  prices: {added} territories added, {len(priced)} total")

    # Free trial: one introductory offer per territory.
    if product["freeTrial"]:
        offers = paged(f"/v1/subscriptions/{sid}/introductoryOffers", {"limit": 200, "include": "territory"})
        have_trial = {(o.get("relationships", {}).get("territory", {}).get("data") or {}).get("id") for o in offers}
        created = 0
        for territory in territories:
            if territory in have_trial:
                continue
            call("POST", "/v1/subscriptionIntroductoryOffers",
                 {"data": {"type": "subscriptionIntroductoryOffers",
                           "attributes": {"duration": product["freeTrial"], "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                           "relationships": {"subscription": rel("subscriptions", sid),
                                             "territory": rel("territories", territory)}}})
            created += 1
        print(f"  free trial {product['freeTrial']}: {created} territories added")


if ACTION == "status":
    group, subs = discover()
    print("group:", group and (group["id"], group["attributes"]["referenceName"]))
    gp = call("GET", f"/v1/apps/{APP_ID}/subscriptionGracePeriod", ok404=True)
    print("grace period:", gp and gp["data"]["attributes"])
    for pid, s in subs.items():
        a = s["attributes"]
        usa = paged(f"/v1/subscriptions/{s['id']}/prices",
                    {"filter[territory]": "USA", "include": "subscriptionPricePoint", "limit": 5})
        allp = paged(f"/v1/subscriptions/{s['id']}/prices", {"limit": 200})
        trials = paged(f"/v1/subscriptions/{s['id']}/introductoryOffers", {"limit": 200})
        locs = paged(f"/v1/subscriptions/{s['id']}/subscriptionLocalizations")
        print(f"{pid}: {a['state']} {a['subscriptionPeriod']} level={a.get('groupLevel')} "
              f"prices={len(allp)} USA_rows={len(usa)} trials={len(trials)} locales={sorted(l['attributes']['locale'] for l in locs)}")
    sys.exit(0)

if ACTION == "setup":
    gid = ensure_group()
    _, subs = discover()
    for product in STORE["products"]:
        ensure_product(gid, product, subs)
elif ACTION == "grace":
    gp = call("GET", f"/v1/apps/{APP_ID}/subscriptionGracePeriod")
    gid = gp["data"]["id"]
    call("PATCH", f"/v1/subscriptionGracePeriods/{gid}",
         {"data": {"type": "subscriptionGracePeriods", "id": gid,
                   "attributes": {"optIn": True, "sandboxOptIn": True, "duration": "SIXTEEN_DAYS",
                                  "renewalType": "ALL_RENEWALS"}}})
    print("grace period: 16 days, all renewals")
else:
    sys.exit(f"unknown action {ACTION}")
print("DRY RUN — nothing written" if DRY else "done")
