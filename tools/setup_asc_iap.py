"""App Store Connect API v2 In-App Purchase provisioning script for Taht ve Kilic."""

import argparse
import json
import os
import sys
import time
from typing import Any, Dict, List, Optional

import jwt
import requests

DEFAULT_KEY_PATH = ""
KEY_ID = ""
ISSUER_ID = ""
APP_ID = "6835198115"
BASE_URL = "https://api.appstoreconnect.apple.com"

IAP_DEFINITIONS: List[Dict[str, Any]] = [
    {
        "id": "diamonds_10",
        "product_id": "com.tahtkilic.kingsage2.diamonds_10",
        "ref_name": "Avuc Dolusu Elmas (10)",
        "diamonds": 10,
        "target_usd": 0.99,
        "localizations": {
            "tr": {
                "name": "Avuç Dolusu Elmas",
                "description": "Hızlandırma parşömenleri için 10 Elmas.",
            },
            "en-US": {
                "name": "Handful of Diamonds",
                "description": "10 Diamonds for speedup scrolls in Taht ve Kilic.",
            },
        },
        "review_note": "Consumable currency pack granting 10 Diamonds in the Royal Market.",
    },
    {
        "id": "diamonds_50",
        "product_id": "com.tahtkilic.kingsage2.diamonds_50",
        "ref_name": "Kese Elmas (50)",
        "diamonds": 50,
        "target_usd": 4.99,
        "localizations": {
            "tr": {
                "name": "Kese Elmas",
                "description": "Hızlandırma parşömenleri için 50 Elmas.",
            },
            "en-US": {
                "name": "Pouch of Diamonds",
                "description": "50 Diamonds for speedup scrolls in Taht ve Kilic.",
            },
        },
        "review_note": "Consumable currency pack granting 50 Diamonds in the Royal Market.",
    },
    {
        "id": "diamonds_100",
        "product_id": "com.tahtkilic.kingsage2.diamonds_100",
        "ref_name": "Hazine Sandigi (100)",
        "diamonds": 100,
        "target_usd": 7.99,
        "localizations": {
            "tr": {
                "name": "Hazine Sandığı",
                "description": "Hızlandırma parşömenleri için 100 Elmas.",
            },
            "en-US": {
                "name": "Treasure Chest",
                "description": "100 Diamonds for speedup scrolls in Taht ve Kilic.",
            },
        },
        "review_note": "Consumable currency pack granting 100 Diamonds in the Royal Market.",
    },
    {
        "id": "diamonds_250",
        "product_id": "com.tahtkilic.kingsage2.diamonds_250",
        "ref_name": "Kraliyet Kasasi (250)",
        "diamonds": 250,
        "target_usd": 17.99,
        "localizations": {
            "tr": {
                "name": "Kraliyet Kasası",
                "description": "Hızlandırma parşömenleri için 250 Elmas.",
            },
            "en-US": {
                "name": "Royal Vault",
                "description": "250 Diamonds for speedup scrolls in Taht ve Kilic.",
            },
        },
        "review_note": "Consumable currency pack granting 250 Diamonds in the Royal Market.",
    },
    {
        "id": "diamonds_1000",
        "product_id": "com.tahtkilic.kingsage2.diamonds_1000",
        "ref_name": "Imparator Hazinesi (1000)",
        "diamonds": 1000,
        "target_usd": 59.99,
        "localizations": {
            "tr": {
                "name": "İmparator Hazinesi",
                "description": "Hızlandırma parşömenleri için 1000 Elmas.",
            },
            "en-US": {
                "name": "Emperor's Hoard",
                "description": "1000 Diamonds for speedup scrolls in Taht ve Kilic.",
            },
        },
        "review_note": "Consumable currency pack granting 1000 Diamonds in the Royal Market.",
    },
]


class ASCClient:
    """Thin wrapper over App Store Connect REST API with automatic ES256 JWT auth."""

    def __init__(self, key_path: str, key_id: str, issuer_id: str):
        with open(key_path, "r", encoding="utf-8") as f:
            self.private_key = f.read()
        self.key_id = key_id
        self.issuer_id = issuer_id
        self._token: Optional[str] = None
        self._token_exp: int = 0

    def _get_token(self) -> str:
        now = int(time.time())
        if self._token and now < self._token_exp - 60:
            return self._token
        exp = now + 900
        payload = {
            "iss": self.issuer_id,
            "iat": now,
            "exp": exp,
            "aud": "appstoreconnect-v1",
        }
        headers = {"kid": self.key_id, "typ": "JWT"}
        token = jwt.encode(payload, self.private_key, algorithm="ES256", headers=headers)
        if isinstance(token, bytes):
            token = token.decode("utf-8")
        self._token = token
        self._token_exp = exp
        return token

    def request(self, method: str, path_or_url: str, json_body: Optional[Dict[str, Any]] = None) -> requests.Response:
        url = path_or_url if path_or_url.startswith("http") else f"{BASE_URL}{path_or_url}"
        headers = {
            "Authorization": f"Bearer {self._get_token()}",
            "Content-Type": "application/json",
        }
        return requests.request(method, url, headers=headers, json=json_body, timeout=30)

    def get_paginated(self, path: str) -> List[Dict[str, Any]]:
        items: List[Dict[str, Any]] = []
        next_url: Optional[str] = path
        while next_url:
            resp = self.request("GET", next_url)
            if resp.status_code >= 400:
                raise RuntimeError(f"GET {next_url} failed ({resp.status_code}): {resp.text}")
            body = resp.json()
            items.extend(body.get("data") or [])
            next_url = (body.get("links") or {}).get("next")
        return items


def fetch_existing_iaps(client: ASCClient, app_id: str) -> Dict[str, Dict[str, Any]]:
    rows = client.get_paginated(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=200")
    by_pid: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        pid = (row.get("attributes") or {}).get("productId", "")
        if pid:
            by_pid[pid] = row
    return by_pid


def ensure_iap_created(client: ASCClient, app_id: str, existing: Dict[str, Dict[str, Any]], spec: Dict[str, Any]) -> Dict[str, Any]:
    pid = spec["product_id"]
    if pid in existing:
        row = existing[pid]
        print(f"  [OK] Exists: {pid} (id={row['id']}, state={row.get('attributes', {}).get('state')})")
        return row

    payload = {
        "data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": spec["ref_name"],
                "productId": pid,
                "inAppPurchaseType": "CONSUMABLE",
                "reviewNote": spec["review_note"],
            },
            "relationships": {
                "app": {
                    "data": {"type": "apps", "id": app_id}
                }
            },
        }
    }
    resp = client.request("POST", "/v2/inAppPurchases", payload)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Failed creating IAP {pid} ({resp.status_code}): {resp.text}")
    row = resp.json()["data"]
    print(f"  [CREATED] {pid} -> id={row['id']}")
    return row


def ensure_localizations(client: ASCClient, iap_id: str, spec: Dict[str, Any]) -> None:
    resp = client.request("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations?limit=50")
    existing_by_locale: Dict[str, Dict[str, Any]] = {}
    if resp.status_code == 200:
        for loc in resp.json().get("data") or []:
            lc = (loc.get("attributes") or {}).get("locale", "")
            if lc:
                existing_by_locale[lc] = loc

    for locale, meta in spec["localizations"].items():
        if locale in existing_by_locale:
            loc_obj = existing_by_locale[locale]
            cur_attrs = loc_obj.get("attributes") or {}
            if cur_attrs.get("name") == meta["name"] and cur_attrs.get("description") == meta["description"]:
                print(f"    [OK] Localization {locale} already set")
                continue
            patch_payload = {
                "data": {
                    "type": "inAppPurchaseLocalizations",
                    "id": loc_obj["id"],
                    "attributes": {
                        "name": meta["name"],
                        "description": meta["description"],
                    },
                }
            }
            pr = client.request("PATCH", f"/v1/inAppPurchaseLocalizations/{loc_obj['id']}", patch_payload)
            if pr.status_code in (200, 201):
                print(f"    [UPDATED] Localization {locale}: {meta['name']}")
                continue
            raise RuntimeError(f"Localization {locale} patch failed ({pr.status_code}): {pr.text}")

        payload = {
            "data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {
                    "locale": locale,
                    "name": meta["name"],
                    "description": meta["description"],
                },
                "relationships": {
                    "inAppPurchaseV2": {
                        "data": {"type": "inAppPurchases", "id": iap_id}
                    }
                },
            }
        }
        r = client.request("POST", "/v1/inAppPurchaseLocalizations", payload)
        if r.status_code == 409 and locale not in existing_by_locale and "DUPLICATE" in r.text:
            time.sleep(2.0)
            r = client.request("POST", "/v1/inAppPurchaseLocalizations", payload)
        if r.status_code in (200, 201):
            print(f"    [CREATED] Localization {locale}: {meta['name']}")
        elif r.status_code == 409 and "DUPLICATE" in r.text:
            print(f"    [OK] Localization {locale} already exists (409)")
        else:
            raise RuntimeError(f"Localization {locale} failed ({r.status_code}): {r.text}")


def ensure_availability(client: ASCClient, iap_id: str, territory_ids: List[str]) -> None:
    check = client.request("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability")
    if check.status_code == 200 and (check.json().get("data") or {}).get("id"):
        print("    [OK] Availability already configured")
        return

    payload = {
        "data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {
                "availableInNewTerritories": True,
            },
            "relationships": {
                "availableTerritories": {
                    "data": [{"type": "territories", "id": tid} for tid in territory_ids]
                },
                "inAppPurchase": {
                    "data": {"type": "inAppPurchases", "id": iap_id}
                },
            },
        }
    }
    r = client.request("POST", "/v1/inAppPurchaseAvailabilities", payload)
    if r.status_code in (200, 201):
        print(f"    [CREATED] Availability across {len(territory_ids)} territories")
    elif r.status_code == 409:
        print("    [OK] Availability already exists (409)")
    else:
        raise RuntimeError(f"Availability failed ({r.status_code}): {r.text}")


def _lookup_schedule_prices(client: ASCClient, iap_id: str) -> Dict[str, str]:
    import base64
    out: Dict[str, str] = {}
    for kind in ("manualPrices", "automaticPrices"):
        next_url: Optional[str] = f"/v1/inAppPurchasePriceSchedules/{iap_id}/{kind}?include=inAppPurchasePricePoint&limit=200"
        while next_url and len(out) < 3:
            r = client.request("GET", next_url)
            if r.status_code != 200:
                break
            body = r.json()
            pts = {
                inc["id"]: inc.get("attributes", {})
                for inc in (body.get("included") or [])
                if inc.get("type") == "inAppPurchasePricePoints"
            }
            for row in body.get("data") or []:
                pt_id = (((row.get("relationships") or {}).get("inAppPurchasePricePoint") or {}).get("data") or {}).get("id")
                if not pt_id or pt_id not in pts:
                    continue
                attrs = pts[pt_id]
                try:
                    dec = json.loads(base64.b64decode(pt_id + "==").decode("utf-8", errors="ignore"))
                    terr = dec.get("t", "")
                except Exception:
                    terr = ""
                if terr in ("USA", "TUR", "DEU") and terr not in out:
                    out[terr] = str(attrs.get("customerPrice", ""))
            next_url = (body.get("links") or {}).get("next")
    return out


def ensure_price_schedule(client: ASCClient, iap_id: str, target_usd: float) -> Dict[str, Any]:
    sched = client.request("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule?include=manualPrices")
    has_manual = False
    if sched.status_code == 200:
        rels = (sched.json().get("data") or {}).get("relationships") or {}
        manual_data = (rels.get("manualPrices") or {}).get("data") or []
        has_manual = len(manual_data) > 0
    if has_manual:
        prices = _lookup_schedule_prices(client, iap_id)
        print(f"    [OK] Price schedule active: {prices}")
        return {"status": "exists", "prices": prices}

    usa_points = client.get_paginated(f"/v2/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200")
    if not usa_points:
        raise RuntimeError(f"No USA price points returned for IAP {iap_id}")

    def _usd_val(pt: Dict[str, Any]) -> float:
        try:
            return float((pt.get("attributes") or {}).get("customerPrice", "0"))
        except ValueError:
            return 0.0

    best_pt = min(usa_points, key=lambda pt: abs(_usd_val(pt) - target_usd))
    chosen_usd = (best_pt.get("attributes") or {}).get("customerPrice")
    pt_id = best_pt["id"]

    payload = {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "baseTerritory": {
                    "data": {"type": "territories", "id": "USA"}
                },
                "inAppPurchase": {
                    "data": {"type": "inAppPurchases", "id": iap_id}
                },
                "manualPrices": {
                    "data": [{"type": "inAppPurchasePrices", "id": "${price1}"}]
                },
            },
        },
        "included": [
            {
                "type": "inAppPurchasePrices",
                "id": "${price1}",
                "attributes": {
                    "startDate": None,
                },
                "relationships": {
                    "inAppPurchasePricePoint": {
                        "data": {"type": "inAppPurchasePricePoints", "id": pt_id}
                    }
                },
            }
        ],
    }
    r = client.request("POST", "/v1/inAppPurchasePriceSchedules", payload)
    if r.status_code in (200, 201):
        prices = _lookup_schedule_prices(client, iap_id)
        print(f"    [CREATED] Price schedule USA=${chosen_usd} (target=${target_usd:.2f}, point={pt_id}) -> {prices}")
        return {"status": "created", "usd": chosen_usd, "point_id": pt_id, "prices": prices}
    raise RuntimeError(f"Price schedule failed ({r.status_code}): {r.text}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Provision Taht ve Kilic Consumable IAPs in App Store Connect.")
    parser.add_argument("--key-path", default=os.getenv("ASC_KEY_PATH", DEFAULT_KEY_PATH))
    parser.add_argument("--key-id", default=os.getenv("ASC_KEY_ID", KEY_ID))
    parser.add_argument("--issuer-id", default=os.getenv("ASC_ISSUER_ID", ISSUER_ID))
    parser.add_argument("--app-id", default=os.getenv("ASC_APP_ID", APP_ID))
    parser.add_argument("--dry-run", action="store_true", help="Read-only check without creating or modifying IAPs.")
    args = parser.parse_args()

    if not args.key_path or not args.key_id or not args.issuer_id:
        print("[ERROR] --key-path, --key-id ve --issuer-id (veya ASC_* env değişkenleri) zorunludur.", file=sys.stderr)
        return 1
    if not os.path.exists(args.key_path):
        print(f"[ERROR] ASC private key not found: {args.key_path}", file=sys.stderr)
        return 1

    client = ASCClient(args.key_path, args.key_id, args.issuer_id)
    existing = fetch_existing_iaps(client, args.app_id)
    print(f"Found {len(existing)} existing IAP(s) on app {args.app_id}.")

    if args.dry_run:
        for spec in IAP_DEFINITIONS:
            pid = spec["product_id"]
            status = "EXISTS" if pid in existing else "MISSING"
            print(f"  [{status}] {pid} -> {spec['ref_name']} (target ${spec['target_usd']:.2f})")
        return 0

    territories = client.get_paginated("/v1/territories?limit=200")
    territory_ids = [t["id"] for t in territories if t.get("id")]
    print(f"Loaded {len(territory_ids)} App Store territories.")

    summary: List[Dict[str, Any]] = []
    for spec in IAP_DEFINITIONS:
        print(f"\nProcessing {spec['product_id']}...")
        iap = ensure_iap_created(client, args.app_id, existing, spec)
        iap_id = iap["id"]
        ensure_localizations(client, iap_id, spec)
        ensure_availability(client, iap_id, territory_ids)
        price_res = ensure_price_schedule(client, iap_id, float(spec["target_usd"]))
        summary.append({
            "product_id": spec["product_id"],
            "iap_id": iap_id,
            "price": price_res,
        })

    print("\n=== Provisioning Summary ===")
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
