"""test_notifications_server.py — Build 27 Sunucu Vezir Bildirim & APNs Token Testleri.

Testler:
  1. POST /api/notifications/register, GET /api/notifications/pending, POST /api/notifications/unregister
  2. İki gerçek oyuncu ortak dünyada oynarken Saldıranın /api/game/save ile gönderdiği yeni saldırı,
     Savunan için 1 adet tekil (dedup'lı) `incoming_attack` bildirimi oluşturur (tekrar save'de çoğalmaz).
  3. Oyuncu A'nın /api/game/save ve /api/messages/send ile gönderdiği mesaj,
     Oyuncu B için `incoming_message` Vezir bildirimi oluşturur; pending ack=1 sonrasında tüketilir.
"""

import os
import sys
import tempfile
import time

os.environ.pop("DATABASE_URL", None)
os.environ.pop("VERCEL", None)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SERVER_DIR = os.path.join(ROOT, "server")
if SERVER_DIR not in sys.path:
    sys.path.insert(0, SERVER_DIR)

import api.index as srv  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402


def _assert(cond: bool, msg: str) -> None:
    if not cond:
        print(f"[FAIL] {msg}")
        sys.exit(1)
    print(f"[PASS] {msg}")


def main() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        srv.DB_PATH = os.path.join(tmpdir, "test_notif.db")
        srv.IS_POSTGRES = False
        srv._PG_SCHEMA_INITIALIZED = False
        srv._PG_EPOCH_VERIFIED = False
        srv.init_db()

        with TestClient(srv.app) as client:
            r1 = client.post(
                "/api/auth/login",
                json={
                    "provider": "apple",
                    "display_name": "Lord Saldiran",
                    "email": "att@test.local",
                    "provider_uid": "att_uid_1",
                },
            )
            _assert(r1.status_code == 200 and r1.json().get("ok"), "Saldıran giriş yaptı")
            tok_att = r1.json()["token"]

            r2 = client.post(
                "/api/auth/login",
                json={
                    "provider": "google",
                    "display_name": "Lord Savunan",
                    "email": "def@test.local",
                    "provider_uid": "def_uid_1",
                },
            )
            _assert(r2.status_code == 200 and r2.json().get("ok"), "Savunan giriş yaptı")
            tok_def = r2.json()["token"]

            hdr_att = {"Authorization": f"Bearer {tok_att}"}
            hdr_def = {"Authorization": f"Bearer {tok_def}"}

            # 1) APNs Push Token kaydetme
            reg_res = client.post(
                "/api/notifications/register",
                headers=hdr_def,
                json={"platform": "ios", "token": "a1b2c3d4e5f60708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f80", "sandbox": True},
            )
            _assert(reg_res.status_code == 200 and reg_res.json().get("ok"), "Push token kaydedildi")

            now = int(time.time())
            att_state = {
                "world_id": 1,
                "world_name": "Dünya 1",
                "seed": 1001,
                "last_saved_unix": now,
                "state": {
                    "player": {"name": "Lord Saldiran"},
                    "villages": [
                        {
                            "id": 901,
                            "name": "Saldıran Kale",
                            "x": 50,
                            "y": 50,
                            "owner": "Lord Saldiran",
                            "is_bot": False,
                            "is_barbarian": False,
                            "buildings": {"main": 3, "wood": 2, "stone": 2, "iron": 2, "storage": 2, "farm": 3, "barracks": 1},
                            "resources": {"wood": 500, "stone": 500, "iron": 500},
                            "units": {"axe": 20},
                        },
                        {
                            "id": 902,
                            "name": "Savunan Başkent",
                            "x": 60,
                            "y": 60,
                            "owner": "Lord Savunan",
                            "is_bot": False,
                            "is_barbarian": False,
                            "buildings": {"main": 3, "wood": 2, "stone": 2, "iron": 2, "storage": 2, "farm": 2},
                            "resources": {"wood": 500, "stone": 500, "iron": 500},
                            "units": {"spear": 10},
                        },
                    ],
                    "movements": [],
                    "queues": [],
                    "messages": [],
                    "reports": [],
                    "alliances": [],
                    "world": {"world_id": 1},
                },
            }
            s_init = client.post("/api/game/save", headers=hdr_att, json=att_state)
            _assert(s_init.status_code == 200 and s_init.json().get("ok"), "İlk dünya durumu kaydedildi")

            # 2) Saldırı başlatıp save et -> Savunan için incoming_attack bildirimi oluşmalı
            arrive_ts = now + 900
            att_state["last_saved_unix"] = now + 1
            att_state["state"]["movements"] = [
                {
                    "id": 501,
                    "from_village_id": 901,
                    "to_village_id": 902,
                    "owner": "Lord Saldiran",
                    "type": "attack",
                    "state": "outgoing",
                    "depart_unix": now + 1,
                    "arrive_unix": arrive_ts,
                    "units": {"axe": 20},
                }
            ]
            s_atk1 = client.post("/api/game/save", headers=hdr_att, json=att_state)
            _assert(s_atk1.status_code == 200 and s_atk1.json().get("ok"), "Saldırı kaydedildi")

            # Tekrar aynı durumu kaydetmek bildirim çoğaltmamalı (dedup)
            att_state["last_saved_unix"] = now + 2
            client.post("/api/game/save", headers=hdr_att, json=att_state)

            # 3) Dünya state mesajı + /api/messages/send testi
            att_state["last_saved_unix"] = now + 3
            att_state["state"]["messages"] = [
                {
                    "from": "Lord Saldiran",
                    "to": "Lord Savunan",
                    "subject": "Savaş İlanı",
                    "body": "Surlarınızı savunun!",
                    "created_unix": now + 3,
                    "read": False,
                }
            ]
            client.post("/api/game/save", headers=hdr_att, json=att_state)

            msg_res = client.post(
                "/api/messages/send",
                headers=hdr_att,
                json={"to_name": "Lord Savunan", "subject": "Barış Teklifi", "body": "Antlaşma yapalım."},
            )
            _assert(msg_res.status_code == 200 and msg_res.json().get("ok"), "/api/messages/send başarılı")

            # Savunan pending bildirimlerini ack=0 ile oku
            p0 = client.get("/api/notifications/pending?ack=0", headers=hdr_def).json()
            notifs = p0.get("notifications") or []
            types = [n.get("type") for n in notifs]
            _assert(types.count("incoming_attack") == 1, f"Tam olarak 1 incoming_attack bildirimi oluştu (bulunan={types.count('incoming_attack')})")
            _assert(types.count("incoming_message") == 2, f"2 incoming_message bildirimi oluştu (save + send endpoint, bulunan={types.count('incoming_message')})")
            atk_n = [n for n in notifs if n.get("type") == "incoming_attack"][0]
            _assert("Vezir" in atk_n["title"] and "Lord Saldiran" in atk_n["body"], f"Saldırı bildirimi Vezir metni doğru: {atk_n['body']}")
            msg_n = [n for n in notifs if n.get("type") == "incoming_message"][0]
            _assert(msg_n["payload"].get("route") == "messages", "Mesaj bildirimi 'messages' rotasına yönlendiriyor")

            # Saldıran kendisine giden mesaj/saldırı için yanlış bildirim almamalı
            p_att = client.get("/api/notifications/pending?ack=0", headers=hdr_att).json()
            _assert(len(p_att.get("notifications") or []) == 0, "Saldıran kendi saldırısı/mesajı için yabancı bildirim almadı")

            # ack=1 ile tüketilince bir sonraki sorguda boş dönmeli
            p1 = client.get("/api/notifications/pending?ack=1", headers=hdr_def).json()
            _assert(len(p1.get("notifications") or []) == 3, "ack=1 tüm 3 bildirimi döndürdü")
            p2 = client.get("/api/notifications/pending?ack=1", headers=hdr_def).json()
            _assert(len(p2.get("notifications") or []) == 0, "ack=1 sonrası bekleyen bildirim kalmadı")

            # Token kaldırma
            unreg_res = client.post("/api/notifications/unregister", headers=hdr_def, json={})
            _assert(unreg_res.status_code == 200 and unreg_res.json().get("ok"), "Push token unregister başarılı")

    print("✅ TÜM BİLDİRİM SUNUCU TESTLERİ BAŞARILI!")


if __name__ == "__main__":
    main()
