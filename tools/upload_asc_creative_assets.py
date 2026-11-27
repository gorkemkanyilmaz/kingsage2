"""Upload Header and Search Results Creative Assets via App Store Connect Asset Library API."""

import hashlib
import json
import os
import pathlib
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

import jwt
import requests

BASE_URL = "https://api.appstoreconnect.apple.com"
DEFAULT_APP_ID = "6835198115"
TARGET_LOCALES = ["tr", "en-GB", "en-US"]
ASSET_PATH = pathlib.Path("appstore/creative_assets/creative_universal_5244x2950.png")
HEADER_PATH = pathlib.Path("appstore/creative_assets/header_3840x1646.png")
SEARCH_PATH = pathlib.Path("appstore/creative_assets/search_result_3840x2560.png")


class ASCClient:
    """Thin App Store Connect REST API wrapper with ES256 JWT auth."""

    def __init__(self, key_path: str, key_id: str, issuer_id: str) -> None:
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

    def request(
        self,
        method: str,
        path_or_url: str,
        json_body: Optional[Dict[str, Any]] = None,
    ) -> requests.Response:
        url = path_or_url if path_or_url.startswith("http") else f"{BASE_URL}{path_or_url}"
        headers = {
            "Authorization": f"Bearer {self._get_token()}",
            "Content-Type": "application/json",
        }
        return requests.request(method, url, headers=headers, json=json_body, timeout=60)

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


def find_editable_ios_version(client: ASCClient, app_id: str) -> Dict[str, Any]:
    rows = client.get_paginated(f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")
    for row in rows:
        if (row.get("attributes") or {}).get("appStoreState") == "PREPARE_FOR_SUBMISSION":
            return row
    raise RuntimeError("No PREPARE_FOR_SUBMISSION iOS version found")


def discover_ref_data(client: ASCClient) -> Dict[str, Any]:
    """Query Apple's Asset Library reference endpoint to discover exact enums."""
    for ep in ("/v1/appAssetLibraryRefData", "/v1/appAssetLibraryRefData?limit=200"):
        resp = client.request("GET", ep)
        print(f"GET {ep} -> {resp.status_code}")
        if resp.status_code == 200:
            body = resp.json()
            print("REF_DATA:", json.dumps(body, indent=2)[:4000])
            return body
        else:
            print("  Body:", resp.text[:600])
    return {}


def inspect_app_asset_library(client: ASCClient, app_id: str, loc_id: str) -> None:
    """Log available asset library images and placements for diagnostics."""
    for ep in (
        f"/v1/apps/{app_id}/appAssetLibraryImages?limit=50",
        f"/v1/appAssetLibraryImages?filter[app]={app_id}&limit=50",
        f"/v1/appStoreVersionLocalizations/{loc_id}/appAssetLibraryPlacements?limit=50",
        f"/v1/appAssetLibraryPlacements?filter[appStoreVersionLocalization]={loc_id}&limit=50",
    ):
        resp = client.request("GET", ep)
        print(f"PROBE {ep} -> {resp.status_code}: {resp.text[:500]}")


def reserve_and_upload_library_image(
    client: ASCClient,
    app_id: str,
    file_path: pathlib.Path,
) -> Tuple[str, Dict[str, Any]]:
    raw_bytes = file_path.read_bytes()
    file_size = len(raw_bytes)
    md5_hex = hashlib.md5(raw_bytes).hexdigest()

    # Try category combinations supported by Apple's Asset Library API
    attempts = [
        {
            "data": {
                "type": "appAssetLibraryImages",
                "attributes": {
                    "fileName": file_path.name,
                    "fileSize": file_size,
                    "category": "CREATIVE_ASSETS",
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                },
            }
        },
        {
            "data": {
                "type": "appAssetLibraryImages",
                "attributes": {
                    "fileName": file_path.name,
                    "fileSize": file_size,
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                },
            }
        },
    ]
    created_body: Optional[Dict[str, Any]] = None
    last_err = ""
    for payload in attempts:
        resp = client.request("POST", "/v1/appAssetLibraryImages", payload)
        print(f"POST /v1/appAssetLibraryImages -> {resp.status_code}")
        if resp.status_code in (200, 201):
            created_body = resp.json()["data"]
            break
        last_err = f"{resp.status_code}: {resp.text}"
        print(f"  Reserve attempt failed: {last_err[:600]}")

    if created_body is None:
        raise RuntimeError(f"Could not reserve appAssetLibraryImages: {last_err}")

    img_id = created_body["id"]
    attrs = created_body.get("attributes") or {}
    upload_ops = attrs.get("uploadOperations") or []
    print(f"Reserved image id={img_id}, ops={len(upload_ops)}, attrs_keys={list(attrs.keys())}")

    for op in upload_ops:
        method = str(op.get("method", "PUT")).upper()
        url = str(op["url"])
        offset = int(op.get("offset", 0))
        length = int(op.get("length", file_size - offset))
        chunk = raw_bytes[offset : offset + length]
        req_headers: Dict[str, str] = {}
        for h in op.get("requestHeaders") or []:
            if "name" in h and "value" in h:
                req_headers[str(h["name"])] = str(h["value"])
        up_resp = requests.request(method, url, headers=req_headers, data=chunk, timeout=180)
        if up_resp.status_code >= 400:
            raise RuntimeError(f"Chunk upload failed ({up_resp.status_code}): {up_resp.text}")

    # Commit uploaded=true (try with sourceFileChecksum first, fallback to uploaded-only)
    committed: Optional[Dict[str, Any]] = None
    for commit_attrs in (
        {"uploaded": True, "sourceFileChecksum": md5_hex},
        {"uploaded": True},
    ):
        c_resp = client.request(
            "PATCH",
            f"/v1/appAssetLibraryImages/{img_id}",
            {"data": {"type": "appAssetLibraryImages", "id": img_id, "attributes": commit_attrs}},
        )
        print(f"PATCH /v1/appAssetLibraryImages/{img_id} ({list(commit_attrs.keys())}) -> {c_resp.status_code}")
        if c_resp.status_code < 400:
            committed = c_resp.json()["data"]
            break
        print(f"  Commit attempt response: {c_resp.text[:500]}")

    if committed is None:
        raise RuntimeError(f"Failed committing appAssetLibraryImage {img_id}")

    # Poll briefly until Apple finishes analyzing asset
    deadline = time.time() + 60.0
    latest = committed
    while time.time() < deadline:
        g_resp = client.request("GET", f"/v1/appAssetLibraryImages/{img_id}")
        if g_resp.status_code == 200:
            latest = g_resp.json()["data"]
            l_attrs = latest.get("attributes") or {}
            state = l_attrs.get("state") or ((l_attrs.get("assetDeliveryState") or {}).get("state"))
            print(f"  Poll {img_id}: state={state}, specId={l_attrs.get('specId')}")
            if state in ("COMPLETE", "READY", "ACTIVE", "PREPARE_FOR_SUBMISSION", "PROCESSED"):
                return img_id, latest
            if state == "FAILED":
                raise RuntimeError(f"Apple processing failed for {img_id}: {json.dumps(l_attrs)}")
        time.sleep(4)

    return img_id, latest


def extract_placement_configs(ref_data: Dict[str, Any]) -> List[Tuple[str, str]]:
    """Find (placementType, placementGroup) pairs for Header and Search Results from refData or known defaults."""
    found: List[Tuple[str, str]] = []
    txt = json.dumps(ref_data)
    if "PRODUCT_PAGE_HEADER" in txt or "SEARCH_RESULTS" in txt or "placementType" in txt:
        # Walk dicts recursively for placementType / placementGroup entries matching header or search
        def walk(obj: Any) -> None:
            if isinstance(obj, dict):
                pt = obj.get("placementType")
                pg = obj.get("placementGroup")
                if isinstance(pt, str) and isinstance(pg, str):
                    u = (pt + " " + pg).upper()
                    if "HEADER" in u or "SEARCH" in u:
                        pair = (pt, pg)
                        if pair not in found:
                            found.append(pair)
                for v in obj.values():
                    walk(v)
            elif isinstance(obj, list):
                for item in obj:
                    walk(item)

        walk(ref_data)

    if not found:
        found = [
            ("PRODUCT_PAGE_HEADER", "PRODUCT_PAGE_HEADER"),
            ("APP_STORE_SEARCH_RESULTS", "APP_STORE_SEARCH_RESULTS"),
        ]
    return found


def create_placement(
    client: ASCClient,
    loc_id: str,
    image_id: str,
    placement_type: str,
    placement_group: str,
) -> Dict[str, Any]:
    payload = {
        "data": {
            "type": "appAssetLibraryPlacements",
            "attributes": {
                "placementType": placement_type,
                "placementGroup": placement_group,
            },
            "relationships": {
                "image": {"data": {"type": "appAssetLibraryImages", "id": image_id}},
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                },
            },
        }
    }
    resp = client.request("POST", "/v1/appAssetLibraryPlacements", payload)
    print(f"POST placement ({placement_type}/{placement_group}, loc={loc_id}) -> {resp.status_code}")
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Create placement failed ({resp.status_code}): {resp.text}")
    return resp.json()["data"]


def main() -> int:
    key_path = os.environ.get("ASC_KEY_PATH", "").strip()
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    issuer_id = os.environ.get("ASC_ISSUER_ID", "").strip()
    app_id = os.environ.get("APP_ID", DEFAULT_APP_ID).strip() or DEFAULT_APP_ID

    if not key_path or not os.path.exists(key_path):
        print(f"ERROR: Missing ASC_KEY_PATH file: {key_path}", file=sys.stderr)
        return 2
    if not ASSET_PATH.exists():
        print(f"ERROR: Missing asset file: {ASSET_PATH}", file=sys.stderr)
        return 2

    client = ASCClient(key_path, key_id, issuer_id)
    version = find_editable_ios_version(client, app_id)
    locs = client.get_paginated(
        f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=50"
    )
    loc_by_code = {
        (l.get("attributes") or {}).get("locale", ""): l["id"]
        for l in locs
        if (l.get("attributes") or {}).get("locale")
    }
    print("Editable version localizations:", loc_by_code)

    ref_data = discover_ref_data(client)
    first_loc = next(iter(loc_by_code.values()))
    inspect_app_asset_library(client, app_id, first_loc)

    # Upload universal 5244x2950 asset (16:9 - supported for both Header and Search Results)
    uni_id, uni_data = reserve_and_upload_library_image(client, app_id, ASSET_PATH)
    print("Uploaded universal asset:", uni_id, json.dumps(uni_data.get("attributes") or {}, indent=2))

    placements = extract_placement_configs(ref_data)
    print("Target placement configs:", placements)

    for code in TARGET_LOCALES:
        loc_id = loc_by_code[code]
        for pt, pg in placements:
            try:
                res = create_placement(client, loc_id, uni_id, pt, pg)
                print(f"  Placed {pt} on {code}: {res['id']}")
            except Exception as exc:
                print(f"  Placement attempt failed ({code}, {pt}/{pg}): {exc}")
                return 1

    print("\nALL_CREATIVE_ASSETS_PLACED_SUCCESSFULLY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
