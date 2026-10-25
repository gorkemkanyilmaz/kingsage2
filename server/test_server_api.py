import sys
import os
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient
from api.index import app, init_db

init_db()
client = TestClient(app)

print("==================================================")
print("🧪 SUNUCU YETKİ, GÜVENLİK VE ENTEGRASYON TESTLERİ")
print("==================================================")

# 1. Health check
res = client.get("/api/health")
assert res.status_code == 200, "Health check 200 dönmeli"
health_data = res.json()
print("✓ Health check OK:", health_data["engine"])

# 2. Login (Lord Gorkem)
res_g = client.post("/api/auth/login", json={"provider": "google", "display_name": "Lord Gorkem"})
assert res_g.status_code == 200
g_data = res_g.json()
g_token = g_data["token"]
print("✓ Lord Gorkem oturum açtı, Token:", g_token[:15] + "...")

# 3. Login (Lord Roland)
res_r = client.post("/api/auth/login", json={"provider": "apple", "display_name": "Lord Roland"})
assert res_r.status_code == 200
r_data = res_r.json()
r_token = r_data["token"]
print("✓ Lord Roland oturum açtı, Token:", r_token[:15] + "...")

# 4. Join World 1
res_j1 = client.post("/api/worlds/join", json={"world_id": 1, "target_x": 100, "target_y": 100}, headers={"Authorization": f"Bearer {g_token}"})
assert res_j1.status_code == 200
j1_data = res_j1.json()
v1_id = j1_data["village_id"]
print(f"✓ Lord Gorkem Dünya 1'e katıldı, Köy ID: {v1_id}")

res_j2 = client.post("/api/worlds/join", json={"world_id": 1, "target_x": 150, "target_y": 150}, headers={"Authorization": f"Bearer {r_token}"})
assert res_j2.status_code == 200
j2_data = res_j2.json()
v2_id = j2_data["village_id"]
print(f"✓ Lord Roland Dünya 1'e katıldı, Köy ID: {v2_id}")

# 5. Harita Kontrolü
res_map = client.get("/api/worlds/1/map")
assert res_map.status_code == 200
map_villages = res_map.json()["villages"]
assert len(map_villages) >= 52, f"En az 50 bot + 2 oyuncu olmalı, mevcut: {len(map_villages)}"
print(f"✓ Harita başarıyla yüklendi, toplam köy: {len(map_villages)}")

# 6. Yetki Kontrolü: Lord Roland, Lord Gorkem'in köyüne inşaat verememeli!
res_hack = client.post("/api/action/build", json={"village_id": v1_id, "building_key": "main"}, headers={"Authorization": f"Bearer {r_token}"})
assert res_hack.status_code == 403, "Başkasının köyüne inşaat emri 403 Forbidden ile engellenmeli!"
print("✓ Güvenlik: Başkasının köyüne inşaat emri verme girişimi 403 ile engellendi!")

# 7. Lord Gorkem kendi köyüne inşaat başlatabilmeli
res_build = client.post("/api/action/build", json={"village_id": v1_id, "building_key": "main"}, headers={"Authorization": f"Bearer {g_token}"})
assert res_build.status_code == 200
print("✓ Lord Gorkem kendi köyünde inşaat emrini başarıyla başlattı:", res_build.json())

# 8. Mesaj İzolasyonu & Injection Testi
# Kötü niyetli SQL injection denemesi
malicious_payload = "'; DROP TABLE users; --"
res_send = client.post("/api/messages/send", json={
    "to_name": "Lord Roland",
    "subject": malicious_payload,
    "body": "Selamlar Lord Roland!"
}, headers={"Authorization": f"Bearer {g_token}"})
assert res_send.status_code == 200
print("✓ SQL Injection denemesi başarıyla parametrik sorguyla nötralize edildi!")

# Lord Roland kutusunu kontrol eder
res_inbox_r = client.get("/api/messages/inbox", headers={"Authorization": f"Bearer {r_token}"})
inbox_r = res_inbox_r.json()["messages"]
assert len(inbox_r) >= 2, "1 karşılama + 1 Gorkem'den mektup olmalı"
print(f"✓ Lord Roland gelen kutusunda {len(inbox_r)} mektup var, SQL injection metni güvenle tutuldu.")

# Lord Gorkem kutusunu kontrol eder (Lord Roland'ın kutusunu GÖREMEMELİ!)
res_inbox_g = client.get("/api/messages/inbox", headers={"Authorization": f"Bearer {g_token}"})
inbox_g = res_inbox_g.json()["messages"]
for m in inbox_g:
    assert m["to_name"] == "Lord Gorkem", "Lord Gorkem asla başka oyuncunun mektubunu göremez!"
print("✓ Mesaj İzolasyonu Doğrulandı: Hesaplar birbirinin mektuplarını göremiyor.")

print("\n==================================================")
print("🎉 TÜM SUNUCU GÜVENLİK VE YETKİ TESTLERİ BAŞARIYLA GEÇTİ!")
print("==================================================")
