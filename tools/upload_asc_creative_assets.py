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


def get_asset_library_id(client: ASCClient, app_id: str) -> str:
    resp = client.request("GET", f"/v1/apps/{app_id}/assetLibrary")
    print(f"GET /v1/apps/{app_id}/assetLibrary -> {resp.status_code}")
    if resp.status_code >= 400:
        raise RuntimeError(f"Failed getting assetLibrary ({resp.status_code}): {resp.text}")
    data = resp.json().get("data") or {}
    lib_id = str(data.get("id", ""))
    if not lib_id:
        raise RuntimeError(f"Empty assetLibrary id: {resp.text}")
    print(f"Found assetLibrary id={lib_id}")
    return lib_id


def discover_ref_data(client: ASCClient) -> Dict[str, Any]:
    """Query Apple's Asset Library reference endpoint and log APP_STORE_VERSIONS Header/Search policies."""
    resp = client.request("GET", "/v1/appAssetLibraryRefData?limit=200")
    print(f"GET /v1/appAssetLibraryRefData -> {resp.status_code}")
    if resp.status_code >= 400:
        print("  RefData err:", resp.text[:600])
        return {}
    body = resp.json()
    for row in body.get("data") or []:
        features = (row.get("attributes") or {}).get("features") or []
        for feat in features:
            if feat.get("featureId") == "APP_STORE_VERSIONS":
                for pol in feat.get("placementPolicies") or []:
                    pt = str(pol.get("placementType", ""))
                    if "HEADER" in pt.upper() or "SEARCH" in pt.upper():
                        print(f"POLICY ({pt}):", json.dumps(pol, indent=2))
    return body


def extract_placement_configs(ref_data: Dict[str, Any]) -> List[Tuple[str, Optional[str]]]:
    """Extract exact (placementType, placementGroup) configs for Header and Search Results."""
    found: List[Tuple[str, Optional[str]]] = []
    for row in ref_data.get("data") or []:
        features = (row.get("attributes") or {}).get("features") or []
        for feat in features:
            if feat.get("featureId") != "APP_STORE_VERSIONS":
                continue
            for pol in feat.get("placementPolicies") or []:
                pt = str(pol.get("placementType", "")).strip()
                if not pt or ("HEADER" not in pt.upper() and "SEARCH" not in pt.upper()):
                    continue
                pgs = pol.get("placementGroups")
                pg_single = pol.get("placementGroup")
                if isinstance(pg_single, str) and pg_single.strip():
                    pair = (pt, pg_single.strip())
                    if pair not in found:
                        found.append(pair)
                elif isinstance(pgs, list) and pgs:
                    for item in pgs:
                        if isinstance(item, dict):
                            name = item.get("placementGroup") or item.get("id") or item.get("name")
                            if isinstance(name, str) and name.strip():
                                pair = (pt, name.strip())
                                if pair not in found:
                                    found.append(pair)
                        elif isinstance(item, str) and item.strip():
                            pair = (pt, item.strip())
                            if pair not in found:
                                found.append(pair)
                else:
                    pair = (pt, None)
                    if pair not in found:
                        found.append(pair)

    if not found:
        found = [
            ("PRODUCT_PAGE_HEADER_ASSET", None),
            ("APP_STORE_SEARCH_RESULTS_ASSET", None),
        ]
    return found


def reserve_and_upload_library_image(
    client: ASCClient,
    asset_library_id: str,
    file_path: pathlib.Path,
) -> Tuple[str, Dict[str, Any]]:
    raw_bytes = file_path.read_bytes()
    file_size = len(raw_bytes)
    md5_hex = hashlib.md5(raw_bytes).hexdigest()

    payload = {
        "data": {
            "type": "appAssetLibraryImages",
            "attributes": {
                "category": "CREATIVE_ASSETS",
                "fileName": file_path.name,
                "fileSize": file_size,
            },
            "relationships": {
                "assetLibrary": {
                    "data": {"type": "appAssetLibraries", "id": asset_library_id}
                }
            },
        }
    }
    resp = client.request("POST", "/v1/appAssetLibraryImages", payload)
    print(f"POST /v1/appAssetLibraryImages -> {resp.status_code}")
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Reserve appAssetLibraryImages failed ({resp.status_code}): {resp.text}")

    created_body = resp.json()["data"]
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
        print(f"  Commit attempt failed: {c_resp.text[:500]}")

    if committed is None:
        raise RuntimeError(f"Failed committing appAssetLibraryImage {img_id}")

    deadline = time.time() + 60.0
    latest = committed
    while time.time() < deadline:
        g_resp = client.request("GET", f"/v1/appAssetLibraryImages/{img_id}")
        if g_resp.status_code == 200:
            latest = g_resp.json()["data"]
            l_attrs = latest.get("attributes") or {}
            state = l_attrs.get("state") or ((l_attrs.get("assetDeliveryState") or {}).get("state"))
            print(f"  Poll {img_id}: state={state}, specId={l_attrs.get('specId')}")
            if state in ("COMPLETE", "READY", "ACTIVE", "PREPARE_FOR_SUBMISSION", "PROCESSED", "AWAITING_REVIEW"):
                return img_id, latest
            if state == "FAILED":
                raise RuntimeError(f"Apple processing failed for {img_id}: {json.dumps(l_attrs)}")
        time.sleep(4)

    return img_id, latest


def create_placement(
    client: ASCClient,
    loc_id: str,
    image_id: str,
    placement_type: str,
    placement_group: Optional[str],
) -> Dict[str, Any]:
    attrs: Dict[str, Any] = {"placementType": placement_type}
    if placement_group:
        attrs["placementGroup"] = placement_group

    payload = {
        "data": {
            "type": "appAssetLibraryPlacements",
            "attributes": attrs,
            "relationships": {
                "image": {"data": {"type": "appAssetLibraryImages", "id": image_id}},
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                },
            },
        }
    }
    resp = client.request("POST", "/v1/appAssetLibraryPlacements", payload)
    print(f"POST placement ({attrs}, loc={loc_id}) -> {resp.status_code}")
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

    asset_library_id = get_asset_library_id(client, app_id)
    ref_data = discover_ref_data(client)
    placements = extract_placement_configs(ref_data)
    print("Extracted placement configs:", placements)

    uni_id, uni_data = reserve_and_upload_library_image(client, asset_library_id, ASSET_PATH)
    print("Uploaded universal asset:", uni_id, json.dumps(uni_data.get("attributes") or {}, indent=2))

    for code in TARGET_LOCALES:
        loc_id = loc_by_code[code]
        for pt, pg in placements:
            try:
                res = create_placement(client, loc_id, uni_id, pt, pg)
                print(f"  Placed {pt} ({pg}) on {code}: {res['id']}")
            except Exception as exc:
                print(f"  Placement attempt failed ({code}, {pt}/{pg}): {exc}")
                return 1

    print("\nALL_CREATIVE_ASSETS_PLACED_SUCCESSFULLY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
