import os
import sys
import json
import copy
import time
import tempfile

# İzole test veritabanı için çevre değişkenini ayarlayıp modülü yükle
os.environ.pop("DATABASE_URL", None)
os.environ["VERCEL"] = ""

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

import api.index as srv


def make_bot_villages(count: int = 106):
    villages = []
    tiles = {}
    x, y = 10, 10
    for vid in range(1, count + 1):
        villages.append({
            "id": vid,
            "name": f"BotKale {vid}",
            "x": x,
            "y": y,
            "owner": f"Bot {vid}",
            "is_bot": True,
            "is_barbarian": False,
            "bonus_type": "",
            "points": 110,
            "buildings": {"main": 1, "farm": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "wall": 0, "hide": 1},
            "resources": {"wood": 1000, "stone": 1000, "iron": 1000},
            "units": {"spear": 10},
            "support": [],
        })
        tiles[f"{x},{y}"] = vid
        x += 12
        if x > 190:
            x = 10
            y += 12
    return villages, tiles


def make_player_world(player_name: str, vid: int, vx: int, vy: int, now: int, tutorial_done: bool = False):
    villages, tiles = make_bot_villages(106)
    pv = {
        "id": vid,
        "name": f"Başkent {player_name}",
        "x": vx,
        "y": vy,
        "owner": player_name,
        "is_bot": False,
        "is_barbarian": False,
        "bonus_type": "",
        "points": 110,
        "buildings": {"main": 1, "farm": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "wall": 0, "hide": 1},
        "resources": {"wood": 1000, "stone": 1000, "iron": 1000},
        "units": {"spear": 20, "sword": 10},
        "support": [],
        "created_unix": now,
        "starter_boost_until_unix": now + 7 * 86400,
    }
    villages.append(pv)
    tiles[f"{vx},{vy}"] = vid
    return {
        "world_id": 1,
        "world_name": "Dünya 1",
        "seed": 1001,
        "created_unix": now,
        "last_saved_unix": now,
        "registered_real_players": [player_name],
        "state": {
            "active_village_id": vid,
            "player": {
                "id": 1,
                "name": player_name,
                "points": 110,
                "created_unix": now,
                "starter_boost_until_unix": now + 7 * 86400,
                "tutorial_completed": tutorial_done,
                "tutorial_step": 10 if tutorial_done else 1,
                "quests": {"claimed": ["q1"] if tutorial_done else [], "stats": {}},
                "gold_armour": 50 if tutorial_done else 0,
            },
            "villages": villages,
            "queues": [],
            "movements": [],
            "reports": [],
            "messages": [],
            "alliances": [],
            "world": {
                "world_id": 1,
                "size": 200,
                "tiles": tiles,
                "villages": villages,
                "player_profiles": {},
                "player_starter_boost": {
                    player_name: {"created_unix": now, "starter_boost_until_unix": now + 7 * 86400}
                },
            },
        },
    }


def main():
    tmp_dir = tempfile.mkdtemp(prefix="kingsage_shared_test_")
    srv.DB_PATH = os.path.join(tmp_dir, "test_shared.db")
    srv.IS_POSTGRES = False
    srv.init_db()

    try:
        from fastapi.testclient import TestClient
    except Exception:
        TestClient = None

    now = int(time.time())

    # 1. Üç farklı telefon girişi (Google, Apple, Google)
    if TestClient is not None:
        client = TestClient(srv.app)
        def post_login(provider, name):
            r = client.post("/api/auth/login", json={"provider": provider, "display_name": name})
            assert r.status_code == 200, r.text
            return r.json()
        def post_save(token, w_data):
            r = client.post("/api/game/save", headers={"Authorization": f"Bearer {token}"}, json=w_data)
            assert r.status_code == 200, r.text
            return r.json()
        def get_state(token):
            r = client.get("/api/game/state", headers={"Authorization": f"Bearer {token}"})
            assert r.status_code == 200, r.text
            return r.json()
        def get_worlds():
            r = client.get("/api/worlds")
            assert r.status_code == 200, r.text
            return r.json()
    else:
        def post_login(provider, name):
            return srv.auth_login(srv.AuthLoginRequest(provider=provider, display_name=name))
        def _user(token):
            return srv.get_current_user(f"Bearer {token}")
        def post_save(token, w_data):
            return srv.post_cloud_save(w_data, _user(token))
        def get_state(token):
            return srv.get_cloud_state(_user(token))
        def get_worlds():
            return srv.get_worlds()

    res1 = post_login("google", "Lord Arthur")
    res2 = post_login("apple", "Lord Lancelot")
    res3 = post_login("google", "Lord Mordred")
    tok1, tok2, tok3 = res1["token"], res2["token"], res3["token"]
    assert res1["has_village"] is False
    assert res2["has_village"] is False

    # 2. Üç telefon aynı anda yerel olarak aynı başlangıç ID (107) ve koordinatla (100,100) kayıt yolluyor!
    w1 = make_player_world("Lord Arthur", 107, 100, 100, now, tutorial_done=True)
    w2 = make_player_world("Lord Lancelot", 107, 100, 100, now + 1, tutorial_done=False)
    w3 = make_player_world("Lord Mordred", 107, 100, 100, now + 2, tutorial_done=False)

    s1 = post_save(tok1, w1)
    s2 = post_save(tok2, w2)
    s3 = post_save(tok3, w3)

    cs3 = s3["cloud_state"]
    reg = cs3["registered_real_players"]
    assert set(reg) == {"Lord Arthur", "Lord Lancelot", "Lord Mordred"}, f"Beklenen 3 gerçek oyuncu, gelen: {reg}"

    real_vs = [v for v in cs3["state"]["villages"] if not v["is_bot"] and not v["is_barbarian"]]
    assert len(real_vs) == 3, f"Beklenen 3 gerçek oyuncu köyü, gelen: {len(real_vs)}"
    vids = {v["owner"]: v["id"] for v in real_vs}
    assert len(set(vids.values())) == 3, f"Çakışan köy ID tespit edildi: {vids}"
    assert vids["Lord Arthur"] == 107
    assert vids["Lord Lancelot"] == 108
    assert vids["Lord Mordred"] == 109

    # S2 yanıtı Lancelot'un remap edilmiş ID'sini döndürmüş olmalı
    assert s2["cloud_state"]["state"]["active_village_id"] == 108, f"Lancelot aktif köy ID 108 olmalıydı: {s2['cloud_state']['state']['active_village_id']}"
    assert cs3["state"]["active_village_id"] == 109, f"Mordred aktif köy ID 109 olmalıydı: {cs3['state']['active_village_id']}"

    # 3. Minimum 9 kare mesafe kuralı tüm köyler arasında sağlanıyor mu?
    all_vs = cs3["state"]["villages"]
    for i in range(len(real_vs)):
        a = real_vs[i]
        for b in all_vs:
            if a["id"] == b["id"]:
                continue
            dist = max(abs(a["x"] - b["x"]), abs(a["y"] - b["y"]))
            assert dist >= 9, f"Köy {a['owner']} ({a['x']},{a['y']}) ile {b['id']} ({b['x']},{b['y']}) mesafesi < 9: {dist}"

    # 4. Telefondan tekrar state çekme ve oyuncu profillerinin izole korunması
    st1 = get_state(tok1)["cloud_state"]
    st2 = get_state(tok2)["cloud_state"]
    assert st1["state"]["player"]["name"] == "Lord Arthur"
    assert st1["state"]["player"]["tutorial_completed"] is True
    assert st1["state"]["player"]["active_village_id"] if "active_village_id" in st1["state"]["player"] else st1["state"]["active_village_id"] == 107
    assert st2["state"]["player"]["name"] == "Lord Lancelot"
    assert st2["state"]["player"]["tutorial_completed"] is False
    assert st2["state"]["active_village_id"] == 108

    # /api/worlds gerçek oyuncu sayısını göstermeli
    wm_list = get_worlds()["worlds"]
    w1_meta = [w for w in wm_list if w["id"] == 1][0]
    w2_meta = [w for w in wm_list if w["id"] == 2][0]
    assert w1_meta["registered_players"] == 3, w1_meta
    assert w1_meta["is_active"] == 1
    assert w2_meta["is_active"] == 0

    # 5. Eşzamanlı bina geliştirme çakışmasızlığı (Lancelot eski Arthur verisiyle save yollasa bile Arthur'un binası ezilmemeli!)
    st1_edit = copy.deepcopy(st1)
    for v in st1_edit["state"]["villages"]:
        if v["id"] == 107:
            v["buildings"]["main"] = 7
    post_save(tok1, st1_edit)

    st2_edit = copy.deepcopy(st2)  # Arthur burada hala main=1 görünüyor!
    for v in st2_edit["state"]["villages"]:
        if v["id"] == 108:
            v["buildings"]["barracks"] = 4
    post_save(tok2, st2_edit)

    st_check = get_state(tok3)["cloud_state"]
    v107 = [v for v in st_check["state"]["villages"] if v["id"] == 107][0]
    v108 = [v for v in st_check["state"]["villages"] if v["id"] == 108][0]
    assert v107["buildings"]["main"] == 7, f"Arthur binası ezildi: {v107['buildings']}"
    assert v108["buildings"]["barracks"] == 4, f"Lancelot binası kaydedilmedi: {v108['buildings']}"

    # 6. İttifak kurma + davet + katılma + sohbet senkronizasyonu
    st1_ally = copy.deepcopy(get_state(tok1)["cloud_state"])
    st1_ally["state"]["alliances"] = [{
        "id": 1,
        "name": "Yuvarlak Masa",
        "tag": "YM",
        "leader": "Lord Arthur",
        "members": [{"name": "Lord Arthur", "rank": "leader", "is_leader": True, "joined_unix": now}],
        "invitations": [{"player_name": "Lord Lancelot", "invited_by": "Lord Arthur", "created_unix": now + 10}],
        "chat_messages": [{"sender": "Lord Arthur", "text": "Hoş geldiniz!", "timestamp_unix": now + 10}],
        "diplomacy": {"allies": [], "nap": [], "enemies": []},
    }]
    post_save(tok1, st1_ally)

    st2_ally = copy.deepcopy(get_state(tok2)["cloud_state"])
    assert len(st2_ally["state"]["alliances"]) == 1
    assert st2_ally["state"]["alliances"][0]["invitations"][0]["player_name"] == "Lord Lancelot"
    st2_ally["state"]["alliances"][0]["invitations"] = []
    st2_ally["state"]["alliances"][0]["members"].append({
        "name": "Lord Lancelot", "rank": "member", "is_leader": False, "joined_unix": now + 20
    })
    st2_ally["state"]["alliances"][0]["chat_messages"].append({
        "sender": "Lord Lancelot", "text": "Kılıcım sizinle Lordum!", "timestamp_unix": now + 21
    })
    post_save(tok2, st2_ally)

    st1_after_ally = get_state(tok1)["cloud_state"]
    ym = st1_after_ally["state"]["alliances"][0]
    m_names = {m["name"] for m in ym["members"]}
    assert m_names == {"Lord Arthur", "Lord Lancelot"}, f"İttifak üyeleri eksik: {m_names}"
    assert len(ym["chat_messages"]) == 2

    # 7. Destek gönderme ve varış senkronizasyonu (Arthur -> Lancelot'a 15 silahtar)
    st1_sup = copy.deepcopy(st1_after_ally)
    for v in st1_sup["state"]["villages"]:
        if v["id"] == 108:
            v["units"]["spear"] = v["units"].get("spear", 0) + 15
            v["support"].append({
                "from_village_id": 107,
                "owner": "Lord Arthur",
                "village_id": 108,
                "units": {"spear": 15},
                "arrive_unix": now + 30,
            })
    # Eşzamanlı mesaj da göndersin
    st1_sup["state"]["messages"].append({
        "id": 99001, "from": "Lord Arthur", "to": "Lord Lancelot",
        "subject": "Destek Geldi", "body": "15 silahtar yola çıktı.", "created_unix": now + 30, "read": False
    })
    post_save(tok1, st1_sup)

    st2_sup = get_state(tok2)["cloud_state"]
    v108_sup = [v for v in st2_sup["state"]["villages"] if v["id"] == 108][0]
    assert v108_sup["buildings"]["barracks"] == 4, "Destek sonrası Lancelot binaları korunmalı!"
    assert v108_sup["units"]["spear"] == 35, f"Lancelot'un 20 + 15 = 35 silahtarı olmalı, gelen: {v108_sup['units']}"
    assert len(v108_sup["support"]) == 1
    assert any(m["subject"] == "Destek Geldi" for m in st2_sup["state"]["messages"])

    # 7b. Çok dalgalı Kont fethi + bayat telefon kaydı koruma testi (Dünya 1)
    # Arthur (107), Mordred'in (109) köyüne 1. Kont saldırısını yapar (fetih henüz gerçekleşmez, realm_of_power düşer)
    st_war1 = copy.deepcopy(get_state(tok1)["cloud_state"])
    v109_before = [v for v in st_war1["state"]["villages"] if v["id"] == 109][0]
    v109_before["realm_of_power"] = 1000
    st_war1["state"]["reports"].append({
        "id": 8801,
        "type": "battle",
        "village_id": 107,
        "created_unix": now + 40,
        "data": {
            "target_village_id": 109,
            "from_village_id": 107,
            "conquered": False,
            "realm_before": 1000,
            "realm_after": 500,
            "defender_losses": {"spear": 5},
            "loot": {"wood": 200, "stone": 150, "iron": 100},
        },
    })
    post_save(tok1, st_war1)
    # Mordred eski bayat yerel önbelleğiyle (raporu görmeden!) save yollasa bile Dalga 1 Güç Alanı hasarı silinmemeli!
    st3_stale = copy.deepcopy(get_state(tok3)["cloud_state"])
    st3_stale["state"]["reports"] = [r for r in st3_stale["state"].get("reports", []) if r.get("id") != 8801]
    for v in st3_stale["state"]["villages"]:
        if v["id"] == 109:
            v["realm_of_power"] = 1000
    post_save(tok3, st3_stale)
    v109_after_stale = [v for v in get_state(tok1)["cloud_state"]["state"]["villages"] if v["id"] == 109][0]
    assert v109_after_stale["realm_of_power"] == 500, f"Bayat telefon kaydı Dalga 1 hasarını sildi: {v109_after_stale['realm_of_power']}"

    # Arthur 2. Kont saldırısıyla Mordred'in 109 nolu köyünü fetheder!
    st_war2 = copy.deepcopy(get_state(tok1)["cloud_state"])
    for v in st_war2["state"]["villages"]:
        if v["id"] == 109:
            v["owner"] = "Lord Arthur"
            v["realm_of_power"] = 300
    st_war2["state"]["reports"].append({
        "id": 8802,
        "type": "battle",
        "village_id": 107,
        "created_unix": now + 50,
        "data": {
            "target_village_id": 109,
            "from_village_id": 107,
            "conquered": True,
            "realm_before": 500,
            "realm_after": 300,
            "defender_losses": {},
            "loot": {"wood": 100, "stone": 100, "iron": 100},
        },
    })
    post_save(tok1, st_war2)
    # Mordred fethi görmeden bayat save atsa bile 109 klonlanmamalı, sahip Lord Arthur kalmalı!
    post_save(tok3, st3_stale)
    st_after_conq = get_state(tok1)["cloud_state"]
    real_vills_post = [v for v in st_after_conq["state"]["villages"] if not v["is_bot"] and not v["is_barbarian"]]
    v109_final = [v for v in real_vills_post if v["id"] == 109][0]
    assert v109_final["owner"] == "Lord Arthur", f"Fetih sonrası 109 sahibi Arthur kalmalıydı: {v109_final['owner']}"
    assert len(real_vills_post) == 3, f"Fethedilen köy klonlanmamalıydı (3 gerçek köy bekleniyordu): {len(real_vills_post)}"

    # 8. 100 gerçek oyuncu kapasitesi dolunca Dünya 2'nin otomatik açılması
    st_cap = copy.deepcopy(st2_sup)
    next_vid = 200
    for idx in range(4, 101):
        pname = f"Lord Oyuncu{idx}"
        px, py = srv._find_free_spot_on_server(st_cap["state"]["villages"], 50, 50, 1, 200)
        st_cap["state"]["villages"].append({
            "id": next_vid, "name": f"Kale {idx}", "x": px, "y": py, "owner": pname,
            "is_bot": False, "is_barbarian": False, "bonus_type": "", "points": 110,
            "buildings": {"main": 1}, "resources": {"wood": 500, "stone": 500, "iron": 500},
            "units": {}, "support": []
        })
        st_cap["registered_real_players"].append(pname)
        next_vid += 1
    cap_res = post_save(tok1, st_cap)
    cap_worlds = {w["id"]: w for w in cap_res["worlds_meta"]}
    assert cap_worlds[1]["registered_players"] == 100, cap_worlds[1]
    assert cap_worlds[2]["is_active"] == 1, f"100 oyuncu dolunca Dünya 2 açılmalıydı: {cap_worlds[2]}"

    print("[PASS] Tum ortak dunya coklu oyuncu testleri basariyla gecti!")
    print(f"  - 3 telefon cakisan ID (107->107,108,109) & koordinat (<9 kare -> >=9 kare) duzeltildi")
    print(f"  - Oyuncu profilleri izole korundu, binalar/kuyruklar ezilmedi")
    print(f"  - Ittifak, sohbet, destek, mesajlar ve 100 oyuncu -> Dunya 2 acilisi dogrulandi")


if __name__ == "__main__":
    main()

