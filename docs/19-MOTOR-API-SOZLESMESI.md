# 19 — Motor API Sözleşmesi (Taht ve Kılıç)

> 🔴 **Bu dosya kod ajanları için BAĞLAYICI sözleşmedir.** Bir ajan buradaki imzayı
> değiştirmek isterse **önce A-ŞEF'e (ana ajan) sorar**; keyfî değişiklik yasak.
> Kaynak kural verisi: `game/data/rules/*.json` (bkz. `game/data/rules/README.md`).

---

## 1. Modül sınırları ve dosya sahipliği

| Modül | Yol | Sahip | Durum |
|---|---|---|---|
| Autoload servisleri | `game/autoload/**` | A-HALKA | ✅ var |
| Kural motoru (sorgu) | `game/scripts/rules/**` | A-MOTOR | ⏳ |
| Köy modeli (veri şekli) | `game/scripts/model/**` | A-MOTOR | ⏳ |
| Ekonomi/bina simülasyonu | `game/scripts/sim/economy/**` | A-EKONOMI | ⏳ |
| Ordu araştırma/eğitim | `game/scripts/sim/army/**` | A-ORDU | ⏳ |
| Savaş simülatörü | `game/scripts/sim/battle/**` | A-SAVAS | ⏳ |
| Casusluk/destek/talan/fetih | `game/scripts/sim/actions/**` | A-KESIF | ⏳ |
| Dünya/harita | `game/scripts/world/**` | A-DUNYA | ⏳ |
| Arayüz | `game/scripts/ui/**`, `game/scenes/**` | A-ARAYUZ | ⏳ |
| Bot/AI | `game/scripts/ai/**` | A-BOT | ⏳ |
| Testler | `game/tests/**` | A-QA | ⏳ |

**Kural:** her ajan **yalnızca kendi klasörüne** yazar. `game/autoload/**` yalnızca A-HALKA'ya aittir.

---

## 2. Determinizm ve zaman modeli (ZORUNLU)

1. **Tamsayı matematiği:** Maliyet/puan/nüfus/asker sayıları **int**. Oranlar (1.165) **float**.
   Yuvarlama: `round_half_up` (0.5 yukarı). Godot'ta `int(floor(x + 0.5))`.
2. **Zaman:** tüm süreler **saniye (float)**. Kayıtlarda **unix zaman damgası (int)**.
3. **Deterministik savaş:** her savaş hareketi `battle_seed` (int) taşır; simülatör
   `RandomNumberGenerator` kullanır ve `seed = battle_seed` yapar. **Global `randi()` YASAK.**
4. **Sunucu hızı:** `GameConfig.speed` üretimi çarpar, süreleri böler.
   `GameConfig.unit_speed` yolculuk sürelerini böler. **Varsayılan 1**
   (not: gerçek KingsAge sunucuları **4**; `GameConfig.apply_profile()` ile değişir).
5. **Bilinmeyen formüller uydurulmaz.** `known:false` alanlar için tek bir sabit kullanılır ve
   `game/scripts/rules/ASSUMPTIONS.md` içinde gerekçesiyle listelenir.

---

## 3. Veri şekilleri (Dictionary — serileştirilebilir)

> Köyler/kuyruklar/hareketler **düz Dictionary**'dir; böylece `GameState.to_dict()/from_dict()`
> olduğu gibi çalışır. Yardımcı fonksiyonlar `game/scripts/model/` içindedir.

### 3.1 Köy (`GameState.villages[]` elemanı)
```gdscript
{
  "id": 1,                          # int, tekil
  "name": "Başkent",
  "x": 100, "y": 100,               # dünya koordinatı (int)
  "owner": "Oyuncu",                # String
  "is_bot": false,
  "is_barbarian": false,            # terk edilmiş/soyguncu köyü
  "buildings": { "main": 1, "wood": 1, ... },   # 15 anahtar → seviye (int)
  "resources": { "wood": 1000, "stone": 1000, "iron": 1000 },  # int
  "units": { "spear": 0, "sword": 0, ... },     # köyde duran ordu (int)
  "researched": { "spear": true, "sword": false },   # ARAŞTIRMA DURUMU (ödenen birimler)
  "realm_of_power": 1000,           # Güç Alanı (int) — başlangıç = köy puanı, tavan = köy puanı
  "points": 20,                     # Köy Puanı (türetilebilir)
  "protection_until": 0,            # unix (yeni oyuncu koruması)
  "conquest_protection_until": 0,   # unix
  "bonus_type": "",                 # "" | "wood" | "stone" | "iron" | "citizen" | "training" | "production"
  "has_statue": false               # Anıt yapıldıysa true (türetilebilir)
}
```

> **Bonus köy (kaynak `villages.txt`):** her bonus köyün **tek** bonusu olur ve başında **'Usta'** vardır.
> Etkiler: `wood|stone|iron` → **+%10** ilgili hammadde · `citizen` → **+%10** vatandaş ·
> `training` → **+%10 hızlı** birim eğitimi · `production` → **+%3** tüm hammaddeler.
> `bonus_type` **dolu** ise `owner` alanı resmî terim olan **"Usta"** olur.
>
> **Terkedilmiş köy (kaynak `villages.txt`):** soyguncular **bina inşa eder** ve **askerî birim üretir**.
> Bu yüzden `units` alanı **normal 11 birim anahtarıyla** doldurulur (özel "soyguncu" anahtarı **yoktur**);
> `is_barbarian = true`, `owner = "Soyguncular"`, koruması yoktur (`protection_until = 0`).
```

### 3.2 Kuyruk öğesi (`GameState.queues[]`)
```gdscript
{
  "id": 10, "village_id": 1,
  "type": "build",            # "build" | "research" | "train"
  "key": "wood",              # bina anahtarı veya birim anahtarı
  "target_level": 5,          # yalnız "build"
  "count": 0,                 # yalnız "train"
  "start_unix": 0, "finish_unix": 0,
  "cost_paid": { "wood": 100, "stone": 100, "iron": 100 }
}
```

### 3.3 Hareket (`GameState.movements[]`)
```gdscript
{
  "id": 20, "village_id": 1,
  "type": "attack",     # "attack"|"raid"|"support"|"trade"|"spy"|"return"
  "from_village_id": 1, "to_village_id": 5, "to_x": 0, "to_y": 0,
  "units": { "spear": 10 }, "carry": { "wood": 0, "stone": 0, "iron": 0 },
  "depart_unix": 0, "arrive_unix": 0, "return_unix": 0,
  "state": "outgoing",   # "outgoing"|"arriving"|"returning"|"done"
  "battle_seed": 12345,  # determinizm
  "target_points": 0     # gönderim anındaki hedef puanı (moral için)
}
```

### 3.4 Rapor (`GameState.reports[]`)
```gdscript
{ "id": 30, "type": "battle", "unix": 0, "village_id": 1, "unread": true, "data": { ... } }
```

---

## 4. `RulesEngine` — kural sorgu API'si (`game/scripts/rules/RulesEngine.gd`)

> **Durumsuz** çalışır (`class_name RulesEngine` + `static func`); veriyi `GameData`'dan alır.
> A-ŞEF **imzaları** tanımlar; A-MOTOR **uygular**.

### 4.1 Maliyet ve gereksinim
```gdscript
static func cost(key: String, level: int) -> Dictionary                     # {"wood","stone","iron"}
static func cost_sum(key: String, from_level: int, to_level: int) -> Dictionary
static func is_free_start(key: String) -> bool
static func requirements(key: String, target_level: int) -> Array            # [{building,level}]
static func missing_requirements(buildings: Dictionary, key: String, target_level: int) -> Array
static func can_build(buildings: Dictionary, key: String, target_level: int) -> bool
static func can_upgrade_now(buildings: Dictionary, key: String) -> bool
# ↑ SIRALI İLERLEME kapısı: hedef = mevcut+1 olmalı, mevcut < max_level olmalı ve önkoşullar sağlanmalı.
#   (A-EKONOMI inşa başlatmadan ÖNCE bunu çağırır.)
static func requirement_chain(buildings: Dictionary, key: String, target_level: int) -> Array
# ↑ zincirin TAMAMI: ör. [{"key":"farm","level":3,"current":1}, {"key":"barracks","level":1,"current":0}, ...]
#   (UI "şu binayı önce şu seviyeye getir" akışını bununla kurar) — SIRALI, topolojik
```
> **Semantik:** `missing_requirements` **doğrudan** (immediate) engelleri döndürür; tam plan için
> `requirement_chain` kullanılır. `cost_sum(from, to)` → `from` **hariç**, `to` **dahil**.
```

### 4.2 Süre (bilinmeyen taban → `ASSUMPTIONS.md`)
```gdscript
static func build_seconds(key: String, level: int) -> float
static func queue_extra_cost_percent(queue_index: int) -> int                # [0,0,0,25,56,...]
static func queue_slots_free() -> int                                        # 3
```

### 4.3 Üretim / kapasite / nüfus
```gdscript
static func production_per_hour(key: String, level: int) -> float            # speed ile çarpılır
static func storage_capacity(level: int) -> int
static func hideout_capacity(level: int) -> int
static func max_population(farm_level: int) -> int
static func donkey_production_per_hour(stable_level: int) -> float
static func donkey_capacity(market_level: int) -> int
static func wall_bonus_percent(wall_level: int) -> int
```

### 4.4 Puan
```gdscript
static func points_for(key: String, level: int) -> int
static func village_points(buildings: Dictionary) -> int                     # Σ bina puanları
static func total_points(villages: Array) -> int                             # + 2500 × (köy−1)
```

### 4.5 Birim
```gdscript
static func unit_cost(unit_key: String, count: int) -> Dictionary
static func unit_settlers(unit_key: String) -> int
static func unit_speed(unit_key: String) -> float                            # yavaşlık: alan/dakika (FLOAT! int kırpma %11 hata verir)
static func unit_mobility(unit_key: String) -> int                           # resmî "Hareketlilik" (int) — bilgi amaçlı
static func unit_carry(unit_key: String) -> int
static func unit_combat(unit_key: String) -> Dictionary                      # {"attack","def_inf","def_cav","def_arch"}
static func research_requirement(unit_key: String) -> int                    # gereken Kışla seviyesi (0 = araştırılmaz, ör. Kont)
static func is_researched(village: Dictionary, unit_key: String) -> bool     # ← village.researched sözlüğüne bakar
static func can_research(village: Dictionary, unit_key: String) -> bool      # Kışla seviyesi + henüz araştırılmamış + maliyet
static func research_cost(unit_key: String) -> Dictionary
static func research_seconds(unit_key: String, building_level: int = -1) -> float   # -1 → birimin min. Kışla seviyesi
static func training_seconds(unit_key: String, count: int, building_level: int = -1) -> float
static func min_attack_units(barracks_level: int) -> int                     # 3 × Kışla
```
> ⚠️ **Araştırma gerçek bir eylemdir:** bedeli ödenir ve **bir kez** yapılır → `village.researched[unit_key] = true`.
> `is_researched` **Kışla seviyesinden türetilemez**; mutlaka `researched` sözlüğüne bakar.
```

---

## 5. `Village` model yardımcıları (`game/scripts/model/VillageModel.gd`)

```gdscript
static func create(id: int, name: String, x: int, y: int, owner: String, is_bot: bool) -> Dictionary
#   → başlangıç: serbest binalar (`main, stone, wood, iron, farm, storage`) = 1, diğerleri 0
#   → `researched = {}`, `units` tüm anahtarlar 0, hammadde 1000/1000/1000
#   → `points` hesaplanır; `realm_of_power = points` (başlangıçta tam), tavan = `points`
static func building_level(village: Dictionary, key: String) -> int
static func set_building_level(village: Dictionary, key: String, level: int) -> void
static func refresh_points(village: Dictionary) -> int       # bina seviyelerinden Köy Puanı
static func refresh_realm(village: Dictionary) -> void       # realm tavanı = points
static func population_used(village: Dictionary) -> int      # Σ bina vatandaşları
static func population_free(village: Dictionary) -> int
static func has_statue(village: Dictionary) -> bool
static func is_developed(village: Dictionary) -> bool        # tüm binalar maks.
```

---

## 6. `WorldModel` (`game/scripts/world/WorldModel.gd`) — A-DUNYA

```gdscript
const SIZE := 200                     # karar: ~200×200
const CONTINENT_SIZE := 100           # kaynakla birebir (100×100) → bizde 4 kıta
static func distance(a_x: int, a_y: int, b_x: int, b_y: int) -> float          # tam Öklid (yuvarlama YOK)
static func travel_seconds(from_x, from_y, to_x, to_y, slowest_unit_speed: float) -> float   # ← FLOAT!
static func continent_id(x: int, y: int) -> int                                # floor(y/100)*10 + floor(x/100)
static func continent_label(x: int, y: int) -> String                          # "K" + floor(y/100) + floor(x/100)
static func generate_world(seed: int, bot_count: int) -> Dictionary            # deterministik
static func find_free_spot(world: Dictionary, x: int, y: int) -> Vector2i
```
> **Kararlar:** dönüş süresi = gidiş süresi (yağma yavaşlatmaz) · yolculuk yalnızca `unit_speed`'den etkilenir
> (`speed` değil) · aynı alana iki köy konamaz · NPC köyleri de üretimde `protection_until = 0` alır
> (koruma **oyun katmanında** yazılır) · bot başına 1 köy; terkedilmiş oranı 1.0, bonus oranı 0.1 (varsayım).

---

## 7. `BattleSimulator` (`game/scripts/sim/battle/BattleSimulator.gd`) — A-SAVAS

> **Saf fonksiyon**: girdi → sonuç. `GameState`'e dokunmaz (böylece test edilebilir).

```gdscript
# attacker/defender: {"units":{...}, "wall_level":int, "buildings":{...},
#                     "bonus":{...}, "has_statue":bool, "points":int}
# options: {"seed":int, "night":bool, "speed":float, "raider_points":int, "is_raid":bool}
static func simulate(attacker: Dictionary, defender: Dictionary, options: Dictionary) -> Dictionary
# dönüş: {"phases":[...], "attacker_losses":{...}, "defender_losses":{...},
#          "wall_damage_pct":float, "loot":{...}, "conquered":bool, "morale":float, "luck":float}
```

---

## 8. Test kuralları (A-QA için)

- Kural testleri: `RulesEngine` maliyetleri `data/buildings.json` ile **birebir** olmalı.
- Gereksinim testleri: `missing_requirements` görev zincirini doğru raporlamalı.
- Savaş testleri: aynı `seed` → aynı sonuç (determinizm).
- Ekonomi testi: 30 günlük ilerleme simülasyonu (offline hızlı-ileri ile) çökmemeli.
- Testler `godot --headless --path game --script res://tests/<dosya>.gd` ile çalışabilmeli.
