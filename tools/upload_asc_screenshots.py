"""Upload Build 43 App Store screenshots (TR, en-GB, en-US) via Apple App Store Connect API v1."""

import hashlib
import os
import pathlib
import sys
import time
from typing import Any, Dict, List, Optional

import jwt
import requests

BASE_URL = "https://api.appstoreconnect.apple.com"
DEFAULT_APP_ID = "6835198115"

# Map each localization to (ScreenshotDisplayType -> local folder of 7 PNGs).
# APP_IPHONE_61 corresponds to iPhone with Dynamic Island (medium display, 1206x2622, Required).
# APP_IPHONE_67 corresponds to iPhone with Dynamic Island (large display, 1320x2868).
LOCALE_SCREENSHOT_MAP: Dict[str, Dict[str, str]] = {
    "tr": {
        "APP_IPHONE_61": "appstore/screenshots_6_3",
        "APP_IPHONE_67": "appstore/screenshots_6_9",
    },
    "en-GB": {
        "APP_IPHONE_61": "appstore/screenshots_6_3_en",
        "APP_IPHONE_67": "appstore/screenshots_en",
    },
    "en-US": {
        "APP_IPHONE_61": "appstore/screenshots_6_3_en",
        "APP_IPHONE_67": "appstore/screenshots_en",
    },
}


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
    rows = client.get_paginated(
        f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20"
    )
    if not rows:
        raise RuntimeError(f"No iOS appStoreVersions found for app {app_id}")
    for row in rows:
        state = (row.get("attributes") or {}).get("appStoreState", "")
        if state == "PREPARE_FOR_SUBMISSION":
            return row
    states = [
        f"{(r.get('attributes') or {}).get('versionString')} ({(r.get('attributes') or {}).get('appStoreState')})"
        for r in rows
    ]
    raise RuntimeError(f"No PREPARE_FOR_SUBMISSION iOS version found. Available: {states}")


def get_or_create_screenshot_set(
    client: ASCClient,
    loc_id: str,
    existing_sets: Dict[str, Dict[str, Any]],
    display_type: str,
) -> Dict[str, Any]:
    if display_type in existing_sets:
        return existing_sets[display_type]
    payload = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                }
            },
        }
    }
    resp = client.request("POST", "/v1/appScreenshotSets", payload)
    if resp.status_code not in (200, 201):
        raise RuntimeError(
            f"POST /v1/appScreenshotSets ({display_type}) failed ({resp.status_code}): {resp.text}"
        )
    created = resp.json()["data"]
    existing_sets[display_type] = created
    print(f"    Created screenshot set {display_type} -> id={created['id']}")
    return created


def upload_one_screenshot(
    client: ASCClient,
    set_id: str,
    file_path: pathlib.Path,
) -> str:
    raw_bytes = file_path.read_bytes()
    file_size = len(raw_bytes)
    md5_hex = hashlib.md5(raw_bytes).hexdigest()

    reserve_payload = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": file_path.name,
                "fileSize": file_size,
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}
                }
            },
        }
    }
    resp = client.request("POST", "/v1/appScreenshots", reserve_payload)
    if resp.status_code not in (200, 201):
        raise RuntimeError(
            f"Reserve screenshot {file_path.name} failed ({resp.status_code}): {resp.text}"
        )

    shot_data = resp.json()["data"]
    shot_id = shot_data["id"]
    upload_ops = (shot_data.get("attributes") or {}).get("uploadOperations") or []
    if not upload_ops:
        raise RuntimeError(f"No uploadOperations returned for {file_path.name} (id={shot_id})")

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
        up_resp = requests.request(method, url, headers=req_headers, data=chunk, timeout=120)
        if up_resp.status_code >= 400:
            raise RuntimeError(
                f"Upload chunk {file_path.name} ({offset}+{length}) failed ({up_resp.status_code}): {up_resp.text}"
            )

    commit_payload = {
        "data": {
            "type": "appScreenshots",
            "id": shot_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": md5_hex,
            },
        }
    }
    commit_resp = client.request("PATCH", f"/v1/appScreenshots/{shot_id}", commit_payload)
    if commit_resp.status_code >= 400:
        raise RuntimeError(
            f"Commit screenshot {file_path.name} ({shot_id}) failed ({commit_resp.status_code}): {commit_resp.text}"
        )
    print(f"    Uploaded & committed {file_path.name} ({file_size} bytes, id={shot_id})")
    return shot_id


def sync_screenshot_set(
    client: ASCClient,
    set_id: str,
    display_type: str,
    folder: pathlib.Path,
) -> None:
    pngs = sorted(folder.glob("*.png"))
    if len(pngs) != 7:
        raise RuntimeError(f"Expected 7 PNG files in {folder}, found {len(pngs)}")

    existing_shots = client.get_paginated(f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=50")
    if existing_shots:
        print(f"    Deleting {len(existing_shots)} existing screenshots in {display_type} ({set_id})...")
        for old in existing_shots:
            del_resp = client.request("DELETE", f"/v1/appScreenshots/{old['id']}")
            if del_resp.status_code >= 400 and del_resp.status_code != 404:
                raise RuntimeError(
                    f"DELETE screenshot {old['id']} failed ({del_resp.status_code}): {del_resp.text}"
                )

    uploaded_ids: List[str] = []
    for p in pngs:
        uploaded_ids.append(upload_one_screenshot(client, set_id, p))

    # Explicitly pin 1..7 order
    order_payload = {
        "data": [{"type": "appScreenshots", "id": sid} for sid in uploaded_ids]
    }
    order_resp = client.request(
        "PATCH", f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots", order_payload
    )
    if order_resp.status_code >= 400:
        raise RuntimeError(
            f"Reorder screenshots in {set_id} failed ({order_resp.status_code}): {order_resp.text}"
        )

    # Poll briefly up to 45s to verify processing does not fail
    deadline = time.time() + 45.0
    while time.time() < deadline:
        shots = client.get_paginated(f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=50")
        states = []
        failed = []
        pending = False
        for s in shots:
            attrs = s.get("attributes") or {}
            fname = attrs.get("fileName", s["id"])
            st = ((attrs.get("assetDeliveryState") or {}).get("state")) or "UNKNOWN"
            states.append(f"{fname}:{st}")
            if st == "FAILED":
                errs = (attrs.get("assetDeliveryState") or {}).get("errors") or []
                failed.append(f"{fname}: {errs}")
            elif st not in ("COMPLETE", "UPLOAD_COMPLETE"):
                pending = True
        if failed:
            raise RuntimeError(f"Apple processing FAILED for {display_type}: {failed}")
        if not pending and len(shots) == len(uploaded_ids):
            print(f"    Verified {display_type}: {', '.join(states)}")
            return
        time.sleep(3)

    print(f"    Completed upload for {display_type}; Apple still finalizing delivery state asynchronously.")


def main() -> int:
    key_path = os.environ.get("ASC_KEY_PATH", "").strip()
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    issuer_id = os.environ.get("ASC_ISSUER_ID", "").strip()
    app_id = os.environ.get("APP_ID", DEFAULT_APP_ID).strip() or DEFAULT_APP_ID

    if not key_path or not os.path.exists(key_path):
        print(f"ERROR: Missing ASC_KEY_PATH file: {key_path}", file=sys.stderr)
        return 2
    if not key_id or not issuer_id:
        print("ERROR: ASC_KEY_ID and ASC_ISSUER_ID env vars are required", file=sys.stderr)
        return 2

    client = ASCClient(key_path, key_id, issuer_id)
    version = find_editable_ios_version(client, app_id)
    v_str = (version.get("attributes") or {}).get("versionString", "?")
    print(f"Target editable iOS version: {v_str} (id={version['id']})")

    locs = client.get_paginated(
        f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=50"
    )
    loc_by_code: Dict[str, Dict[str, Any]] = {}
    for loc in locs:
        code = (loc.get("attributes") or {}).get("locale", "")
        if code:
            loc_by_code[code] = loc
    print(f"Found localizations: {sorted(loc_by_code.keys())}")

    for locale_code, display_map in LOCALE_SCREENSHOT_MAP.items():
        if locale_code not in loc_by_code:
            raise RuntimeError(
                f"Expected localization '{locale_code}' not found on version {v_str}: {list(loc_by_code.keys())}"
            )
        loc_id = loc_by_code[locale_code]["id"]
        print(f"\n=== Processing locale: {locale_code} (loc_id={loc_id}) ===")
        sets = client.get_paginated(
            f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=50"
        )
        existing_sets: Dict[str, Dict[str, Any]] = {}
        for s in sets:
            dt = (s.get("attributes") or {}).get("screenshotDisplayType", "")
            if dt:
                existing_sets[dt] = s
        print(f"  Existing screenshot sets: {sorted(existing_sets.keys())}")

        for display_type, rel_folder in display_map.items():
            folder = pathlib.Path(rel_folder)
            if not folder.is_dir():
                raise RuntimeError(f"Screenshot folder missing: {folder}")
            sset = get_or_create_screenshot_set(client, loc_id, existing_sets, display_type)
            print(f"  Syncing {display_type} from {folder}...")
            sync_screenshot_set(client, sset["id"], display_type, folder)

    print("\nALL_ASC_SCREENSHOTS_UPLOADED_SUCCESSFULLY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
