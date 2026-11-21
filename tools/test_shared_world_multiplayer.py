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

    # 7c. Tüm köylerini kaybeden Mordred sunucudan active_village_id == -1 alır ve farklı konumda sıfırdan başlar
    st3_lost = get_state(tok3)["cloud_state"]
    assert st3_lost["state"]["active_village_id"] == -1, f"Fethedilen oyuncu active_village_id == -1 almalı: {st3_lost['state']['active_village_id']}"
    assert st3_lost["state"]["player"]["points"] == 0, "Fethedilen oyuncu puanı 0 olmalı"

    st3_restart = copy.deepcopy(st3_lost)
    new_v110 = {
        "id": 110,
        "name": "Başkent",
        "x": 35,
        "y": 165,
        "owner": "Lord Mordred",
        "is_bot": False,
        "is_barbarian": False,
        "points": 110,
        "realm_of_power": 110,
        "buildings": {"main": 1, "farm": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "hide": 1},
        "resources": {"wood": 1000, "stone": 1000, "iron": 1000},
        "units": {"spear": 0, "sword": 0, "spy": 0, "snob": 0},
        "researched": {},
        "support": [],
    }
    st3_restart["state"]["villages"].append(new_v110)
    st3_restart["state"]["active_village_id"] = 110
    st3_restart["state"]["player"]["tutorial_completed"] = False
    st3_restart["state"]["player"]["quests"] = {"claimed": [], "stats": {}}
    st3_restart["last_saved_unix"] = now + 60
    post_save(tok3, st3_restart)

    st_after_restart = get_state(tok3)["cloud_state"]
    assert st_after_restart["state"]["active_village_id"] == 110, "Yeniden başlayan oyuncu 110 nolu yeni köyünde aktif olmalı"
    mordred_vills = [v for v in st_after_restart["state"]["villages"] if v.get("owner") == "Lord Mordred"]
    assert len(mordred_vills) == 1 and mordred_vills[0]["id"] == 110
    assert (mordred_vills[0]["x"], mordred_vills[0]["y"]) != (120, 120), "Mordred yeni koordinatta başlamalı"
    arthur_vills = [v for v in st_after_restart["state"]["villages"] if v.get("owner") == "Lord Arthur"]
    assert len(arthur_vills) == 2, f"Arthur'un 2 köyü (107 + 109) korunmalıydı: {len(arthur_vills)}"

    # 7d. Çift başlangıç köyü engeli + id=None temizliği + oyuncular arası ticaret teslimatı + tutorial_skipped
    st_dup = copy.deepcopy(get_state(tok2)["cloud_state"])
    # Lancelot mevcut starter (108)'in yanında yanlışlıkla ikinci bir Başkent (999) + id=None Test Kale göndermeye çalışsın
    st_dup["state"]["villages"].append({
        "id": None, "name": "Test Kale", "x": 15, "y": 15, "owner": "",
        "is_bot": False, "is_barbarian": False, "bonus_type": ""
    })
    st_dup["state"]["villages"].append({
        "id": 999, "name": "Başkent", "x": 180, "y": 180, "owner": "Lord Lancelot",
        "is_bot": False, "is_barbarian": False, "bonus_type": "", "points": 110,
        "buildings": {"main": 1}, "resources": {"wood": 500, "stone": 500, "iron": 500},
        "units": {}, "support": []
    })
    st_dup["state"]["player"]["tutorial_skipped"] = True
    # Lancelot (108) -> Mordred (110) ticaret teslim raporu
    st_dup["state"].setdefault("reports", []).append({
        "id": 77701,
        "type": "trade",
        "unix": now + 65,
        "village_id": 108,
        "data": {
            "type": "trade",
            "from_village_id": 108,
            "target_village_id": 110,
            "resources": {"wood": 450, "stone": 300, "iron": 250}
        }
    })
    post_save(tok2, st_dup)
    st_lance = get_state(tok2)["cloud_state"]
    assert all(v.get("id") is not None and int(v.get("id")) > 0 for v in st_lance["state"]["villages"]), "Geçersiz id=None/0 köyler sunucudan temizlenmeliydi"
    lance_vills = [v for v in st_lance["state"]["villages"] if v.get("owner") == "Lord Lancelot"]
    assert len(lance_vills) == 1, f"Lancelot ikinci başlangıç köyü alamamalıydı: {len(lance_vills)}"
    assert st_lance["state"]["player"].get("tutorial_skipped") is True, "tutorial_skipped bulutta korunmalıydı"
    st_mord = get_state(tok3)["cloud_state"]
    m110 = [v for v in st_mord["state"]["villages"] if int(v["id"]) == 110][0]
    assert m110["resources"]["wood"] == 1450, f"Ticaret ile 450 odun Mordred'e geçmeliydi: {m110['resources']}"

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

    if TestClient is not None:
        test_bots_and_unique_lord_name(TestClient)


def test_bots_and_unique_lord_name(TestClient):
    tmp_dir2 = tempfile.mkdtemp(prefix="kingsage_bots_auth_test_")
    srv.DB_PATH = os.path.join(tmp_dir2, "test_bots_auth.db")
    srv.IS_POSTGRES = False
    srv.init_db()

    client = TestClient(srv.app)

    # 1. İlk açılışta Dünya 1 otomatik 50 barışçıl bot içermeli
    r_health = client.get("/api/health")
    assert r_health.status_code == 200, r_health.text
    jh = r_health.json()
    assert jh["world_reset_epoch"] == 5, jh
    assert jh["world1_bot_villages"] == 50, jh

    r_map = client.get("/api/worlds/1/map")
    assert r_map.status_code == 200, r_map.text
    jm = r_map.json()
    bot_vills = [v for v in jm.get("villages", []) if v.get("is_bot")]
    assert len(bot_vills) == 50, f"Beklenen 50 bot, gelen: {len(bot_vills)}"
    assert {int(v["id"]) for v in bot_vills} == set(range(1, 51))

    # 2. Barışçıl sunucu bot simülasyonu: puan & asker artmalı, kaynaklar >= 0, saldırı olmamalı
    conn = srv.get_db()
    with conn:
        cur = conn.cursor()
        cur.execute("SELECT state_json FROM world_states WHERE world_id = 1")
        w_data = json.loads(cur.fetchone()["state_json"])
        sim_now = int(time.time())
        pts_before = sum(int(v.get("points", 0)) for v in w_data["state"]["villages"] if v.get("is_bot"))
        for _ in range(10):
            sim_now += 1800
            srv._simulate_server_bots(w_data, cur, sim_now)
        pts_after = sum(int(v.get("points", 0)) for v in w_data["state"]["villages"] if v.get("is_bot"))
        total_troops = sum(
            int(cnt or 0)
            for v in w_data["state"]["villages"]
            if v.get("is_bot")
            for cnt in v.get("units", {}).values()
        )
        assert pts_after > pts_before, f"Botlar gelişmedi: {pts_before} -> {pts_after}"
        assert total_troops > 0, "Botlar hiç asker eğitmedi!"
        assert len(w_data["state"].get("movements", [])) == 0, "Barışçıl botlar saldırı çıkarmamalı!"
        for v in w_data["state"]["villages"]:
            if v.get("is_bot"):
                res = v.get("resources", {})
                assert res["wood"] >= 0 and res["stone"] >= 0 and res["iron"] >= 0, f"Negatif kaynak: {res}"

    # 3. Hesap kontrolü (/api/auth/check_account) ve benzersiz Lord ismi kontrolü (409 NAME_TAKEN)
    r_chk0 = client.post("/api/auth/check_account", json={
        "provider": "apple", "email": "alparslan@icloud.com", "provider_uid": "apple_u1"
    })
    assert r_chk0.status_code == 200, r_chk0.text
    assert r_chk0.json()["exists"] is False

    r_reg = client.post("/api/auth/login", json={
        "provider": "apple",
        "display_name": "Alparslan",
        "email": "alparslan@icloud.com",
        "provider_uid": "apple_u1",
    })
    assert r_reg.status_code == 200, r_reg.text
    assert r_reg.json()["display_name"] == "Lord Alparslan"

    r_chk1 = client.post("/api/auth/check_account", json={
        "provider": "apple", "email": "alparslan@icloud.com", "provider_uid": "apple_u1"
    })
    assert r_chk1.status_code == 200, r_chk1.text
    assert r_chk1.json()["exists"] is True
    assert r_chk1.json()["display_name"] == "Lord Alparslan"

    for dup_name in ("Alparslan", "Lord Alparslan", "Lord Edward"):
        r_dup = client.post("/api/auth/login", json={
            "provider": "google",
            "display_name": dup_name,
            "email": "other@gmail.com",
            "provider_uid": "google_u2",
        })
        assert r_dup.status_code == 409, f"Çakışan isim ({dup_name}) 409 dönmeliydi: {r_dup.status_code} {r_dup.text}"
        assert r_dup.json()["error_code"] == "NAME_TAKEN"

    print("[PASS] 50 bariscil bot, check_account ve benzersiz Lord ismi (409 NAME_TAKEN) dogrulandi!")
    test_store_endpoints(client)


def test_store_endpoints(client):
    # 1. Mağaza kataloğu & başlangıç 35 elmas
    r_cat = client.get("/api/store/catalog")
    assert r_cat.status_code == 200, r_cat.text
    j_cat = r_cat.json()
    assert j_cat["starter_diamonds"] == 35
    assert len(j_cat["diamond_packs"]) == 5
    assert len(j_cat["speedup_scrolls"]) == 12

    r_usr = client.post("/api/auth/login", json={
        "provider": "apple",
        "display_name": "Pazar Lordu",
        "email": "pazar@icloud.com",
        "provider_uid": "apple_pazar_1",
    })
    assert r_usr.status_code == 200, r_usr.text
    ju = r_usr.json()
    tok = ju["token"]
    assert ju["diamonds"] == 35, f"Başlangıç elması 35 olmalı: {ju}"
    assert ju["scrolls"] == {}, ju

    # 2. Elmas ile parşömen satın alma (build_10m = 5 elmas -> 30 kalır)
    r_buy = client.post("/api/store/buy_scroll", headers={"Authorization": f"Bearer {tok}"}, json={
        "scroll_id": "build_10m", "qty": 1
    })
    assert r_buy.status_code == 200, r_buy.text
    jb = r_buy.json()
    assert jb["diamonds"] == 30 and jb["scrolls"]["build_10m"] == 1, jb

    # Yetersiz elmasta 400 dönmeli (march_60m x2 = 60 > 30)
    r_fail = client.post("/api/store/buy_scroll", headers={"Authorization": f"Bearer {tok}"}, json={
        "scroll_id": "march_60m", "qty": 2
    })
    assert r_fail.status_code == 400, r_fail.text

    # 3. IAP doğrulama (50 elmas paketi) + mükerrer transaction_id engeli
    r_iap1 = client.post("/api/store/verify_iap", headers={"Authorization": f"Bearer {tok}"}, json={
        "product_id": "com.tahtkilic.kingsage2.diamonds_50",
        "transaction_id": "tx_asc_unique_001",
        "platform": "ios",
    })
    assert r_iap1.status_code == 200, r_iap1.text
    ji1 = r_iap1.json()
    assert ji1["diamonds"] == 80 and ji1["added"] == 50 and ji1["duplicate"] is False, ji1

    r_iap_dup = client.post("/api/store/verify_iap", headers={"Authorization": f"Bearer {tok}"}, json={
        "product_id": "com.tahtkilic.kingsage2.diamonds_50",
        "transaction_id": "tx_asc_unique_001",
        "platform": "ios",
    })
    assert r_iap_dup.status_code == 200, r_iap_dup.text
    jid = r_iap_dup.json()
    assert jid["diamonds"] == 80 and jid["added"] == 0 and jid["duplicate"] is True, jid

    # 4. Yeniden girişte elmas ve parşömen cüzdanı korunmalı
    r_relog = client.post("/api/auth/check_account", json={
        "provider": "apple", "email": "pazar@icloud.com", "provider_uid": "apple_pazar_1"
    })
    assert r_relog.status_code == 200, r_relog.text
    jr = r_relog.json()
    assert jr["diamonds"] == 80 and jr["scrolls"].get("build_10m") == 1, jr
    print("[PASS] Elmas magazasi (/api/store/*), 35 baslangic elmasi, parşomen alimi ve IAP tekrar korumasi dogrulandi!")
    test_scroll_wallet_persistence_and_resource_packs(client, jr["token"])


def test_scroll_wallet_persistence_and_resource_packs(client, tok):
    hdr = {"Authorization": f"Bearer {tok}"}
    cat = client.get("/api/store/catalog").json()
    assert len(cat["resource_packs"]) == 6, cat.get("resource_packs")

    # Parşömen bayat /api/game/save ile silinmemeli
    st = client.get("/api/game/state", headers=hdr).json()
    assert st["scrolls"].get("build_10m") == 1, st["scrolls"]
    stale = copy.deepcopy(st["cloud_state"]) if st.get("cloud_state") else None
    if stale:
        stale["state"]["player"]["scrolls"] = {}
        stale["state"]["player"]["diamonds"] = 35
        r_save = client.post("/api/game/save", headers=hdr, json=stale)
        assert r_save.status_code == 200, r_save.text
        st2 = client.get("/api/game/state", headers=hdr).json()
        assert st2["scrolls"].get("build_10m") == 1, f"Bayat save parsomeni sildi: {st2['scrolls']}"
        assert st2["diamonds"] == 80, f"Bayat save elmasi ezdi: {st2['diamonds']}"

    # use_scroll envanterden düşer
    r_use = client.post("/api/store/use_scroll", headers=hdr, json={"scroll_id": "build_10m", "category": "build"})
    assert r_use.status_code == 200, r_use.text
    assert r_use.json()["scrolls"].get("build_10m", 0) == 0, r_use.json()
    r_use2 = client.post("/api/store/use_scroll", headers=hdr, json={"scroll_id": "build_10m", "category": "build"})
    assert r_use2.status_code == 400, r_use2.text

    # Elmasla kaynak alma
    r_res = client.post("/api/store/buy_resources", headers=hdr, json={"pack_id": "res_bundle_1500"})
    assert r_res.status_code == 200, r_res.text
    assert r_res.json()["diamonds"] == 80 - 12, r_res.json()
    r_bad = client.post("/api/store/buy_resources", headers=hdr, json={"pack_id": "yok_boyle_paket"})
    assert r_bad.status_code == 400, r_bad.text
    print("[PASS] Parsomen cuzdani kalici, use_scroll ve elmasla kaynak alma (buy_resources) dogrulandi!")

    # Rapor okundu / silindi imzaları server merge_world_state ile korunmalı
    st_rep = client.get("/api/game/state", headers=hdr).json()
    cloud_w = copy.deepcopy(st_rep["cloud_state"])
    cloud_w.setdefault("state", {}).setdefault("player", {})["read_report_sigs"] = ["spy:1:100:2:1"]
    cloud_w["state"]["player"]["deleted_report_sigs"] = ["battle:1:200:3:1"]
    r_rep_save = client.post("/api/game/save", headers=hdr, json=cloud_w)
    assert r_rep_save.status_code == 200, r_rep_save.text
    st_rep2 = client.get("/api/game/state", headers=hdr).json()["cloud_state"]
    profs = st_rep2.get("state", {}).get("world", {}).get("player_profiles", {})
    matched_prof = next((pv for pv in profs.values() if isinstance(pv, dict) and pv.get("read_report_sigs")), {})
    assert "spy:1:100:2:1" in (matched_prof.get("read_report_sigs") or []), matched_prof
    assert "battle:1:200:3:1" in (matched_prof.get("deleted_report_sigs") or []), matched_prof
    print("[PASS] Rapor read_report_sigs ve deleted_report_sigs sunucu merge ile korundu!")
    test_returning_apple_user_restoration(client)


def test_returning_apple_user_restoration(client):
    """Apple ile ilk kez giris + koy gelistirme + cikis + tekrar YALNIZCA Apple UID ile giris -> eski Lord & koy geri gelmeli."""
    import base64
    uid_raw = "001999.appleuserxyz.8842"
    first_email = "privaterelay@icloud.appleid.com"

    # 1. İlk girişte check_account -> exists=False
    r_chk1 = client.post("/api/auth/check_account", json={
        "provider": "apple", "email": first_email, "provider_uid": uid_raw
    })
    assert r_chk1.status_code == 200 and r_chk1.json().get("exists") is False, r_chk1.text

    # 2. Kullanıcı Lord adını seçip Diyara Adım At der
    r_reg = client.post("/api/auth/login", json={
        "provider": "apple", "display_name": "Lord Seljuk", "email": first_email, "provider_uid": uid_raw
    })
    assert r_reg.status_code == 200, r_reg.text
    jr = r_reg.json()
    tok = jr["token"]
    assert jr["display_name"] == "Lord Seljuk", jr
    assert jr["provider_uid"] == uid_raw, jr

    # Çakışan başka hesap aynı ismi alamamalı (409)
    r_dup = client.post("/api/auth/login", json={
        "provider": "apple", "display_name": "Lord Seljuk", "email": "other@icloud.com", "provider_uid": "009999.other"
    })
    assert r_dup.status_code == 409 and r_dup.json().get("error_code") == "NAME_TAKEN", r_dup.text

    # Köyünü kurup kaydeder (tutorial tamam, görevler alınmış, rapor okundu + silindi)
    now = int(time.time())
    w_state = make_player_world("Lord Seljuk", 130, 88, 92, now, tutorial_done=True)
    w_state["state"]["player"]["tutorial_step"] = 18
    w_state["state"]["player"]["tutorial_reward_claimed"] = True
    w_state["state"]["player"]["quests"] = {"claimed": ["t1", "q_wood_3"], "stats": {"raids_sent": 2}}
    w_state["state"]["player"]["read_report_sigs"] = [f"spy:130:{now}:10:130"]
    w_state["state"]["player"]["deleted_report_sigs"] = [f"battle:130:{now + 5}:11:130"]
    w_state["state"]["reports"] = [
        {"id": 901, "type": "spy", "unix": now, "village_id": 130, "unread": False, "data": {"type": "spy", "target_village_id": 10, "from_village_id": 130}},
        {"id": 902, "type": "battle", "unix": now + 5, "village_id": 130, "unread": True, "data": {"type": "battle", "target_village_id": 11, "from_village_id": 130}},
        {"id": 903, "type": "battle", "unix": now + 10, "village_id": 130, "unread": True, "data": {"type": "battle", "target_village_id": 12, "from_village_id": 130}},
    ]
    r_save = client.post("/api/game/save", headers={"Authorization": f"Bearer {tok}"}, json=w_state)
    assert r_save.status_code == 200, r_save.text

    # Bayat/sıfırlanmış istemci kaydı gelse bile tutorial, görevler ve silinen raporlar ASLA sıfırlanmamalı
    stale_reset = make_player_world("Lord Seljuk", 130, 88, 92, now + 15, tutorial_done=False)
    stale_reset["state"]["player"]["quests"] = {"claimed": [], "stats": {}}
    stale_reset["state"]["player"]["read_report_sigs"] = []
    stale_reset["state"]["player"]["deleted_report_sigs"] = []
    stale_reset["state"]["reports"] = [
        {"id": 901, "type": "spy", "unix": now, "village_id": 130, "unread": True, "data": {"type": "spy", "target_village_id": 10, "from_village_id": 130}},
        {"id": 902, "type": "battle", "unix": now + 5, "village_id": 130, "unread": True, "data": {"type": "battle", "target_village_id": 11, "from_village_id": 130}},
    ]
    r_stale = client.post("/api/game/save", headers={"Authorization": f"Bearer {tok}"}, json=stale_reset)
    assert r_stale.status_code == 200, r_stale.text

    # 3. Kullanıcı çıkış yapar ve iOS FaceID tekrar giriş yapar (Apple artık email vermez, sadece uid veya id_token verir!)
    r_chk2 = client.post("/api/auth/check_account", json={
        "provider": "apple", "email": "", "provider_uid": uid_raw
    })
    assert r_chk2.status_code == 200, r_chk2.text
    j2 = r_chk2.json()
    assert j2["exists"] is True, j2
    assert j2["display_name"] == "Lord Seljuk", j2
    assert j2["has_village"] is True, j2
    assert len(j2.get("token", "")) > 10, j2
    assert j2["email"] == first_email, j2
    cs_p = j2["cloud_state"]["state"]["player"]
    assert cs_p["tutorial_completed"] is True, f"Tutorial sıfırlanmamalıydı: {cs_p}"
    assert "q_wood_3" in cs_p["quests"]["claimed"] and "t1" in cs_p["quests"]["claimed"], cs_p["quests"]
    assert cs_p["quests"]["stats"].get("raids_sent", 0) >= 2, cs_p["quests"]
    assert f"spy:130:{now}:10:130" in (cs_p.get("read_report_sigs") or []), cs_p
    assert f"battle:130:{now + 5}:11:130" in (cs_p.get("deleted_report_sigs") or []), cs_p
    cs_reps = j2["cloud_state"]["state"].get("reports") or []
    assert not any(int(r.get("unix", 0)) == now + 5 for r in cs_reps), f"Silinen rapor geri gelmemeliydi: {cs_reps}"
    spy_r = [r for r in cs_reps if r.get("type") == "spy"]
    assert len(spy_r) == 1 and spy_r[0].get("unread") is False, f"Okunan rapor unread=False kalmalıydı: {spy_r}"

    # 4. JWT içindeki sub/email fallback doğrulaması
    hdr_b64 = base64.urlsafe_b64encode(b'{"alg":"RS256"}').decode().rstrip("=")
    pl_b64 = base64.urlsafe_b64encode(json.dumps({"sub": uid_raw, "email": first_email}).encode()).decode().rstrip("=")
    fake_jwt = f"{hdr_b64}.{pl_b64}.sig"
    r_chk3 = client.post("/api/auth/check_account", json={
        "provider": "apple", "email": "", "provider_uid": "", "identity_token": fake_jwt
    })
    assert r_chk3.status_code == 200 and r_chk3.json().get("exists") is True, r_chk3.text
    assert r_chk3.json().get("display_name") == "Lord Seljuk", r_chk3.text
    print("[PASS] Returning Apple kullanici restorasyonu (UID + JWT fallback + cikis/giris kaliciligi) dogrulandi!")


if __name__ == "__main__":
    main()

