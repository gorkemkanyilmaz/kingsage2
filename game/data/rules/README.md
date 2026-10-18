# `game/data/rules/` — Kural Seti Şema Sözleşmesi

> **Sahip:** `A-KURAL` · **Görev:** `TASKS-CODE.md` FAZ 3 (T-3.1 … T-3.8)
> **Durum:** ✅ Sürüm **1.0.0** · **Doğrulayıcı:** `python tools/validate_rules.py`
>
> Bu klasör **makine-okunur tek doğruluk kaynağıdır (single source of truth)**.
> Oyun kodu (A-EKONOMI, A-ORDU, A-SAVAS, A-KESIF, A-HALKA) kural sayılarını
> **buradan** okur; `.gd` dosyalarına sabit sayı **gömülmez**.

---

## 0. Hızlı Özet

| Dosya | İçerik | Ana tüketici |
|---|---|---|
| `requirements.json` | Bina **gereksinim DAG'ı** (önkoşul zinciri) | A-EKONOMI (T-5.4), A-ARAYUZ |
| `costs.json` | Maliyet büyüme faktörleri + seviye-1 temel maliyetler | A-EKONOMI (T-5.1) |
| `production.json` | Üretim / kapasite / vatandaş / katır / sur eğrileri ve tabloları | A-EKONOMI, A-KESIF |
| `time-factors.json` | Zaman faktörü serileri + inşaat kuyruğu ek maliyeti | A-EKONOMI (T-5.3) |
| `battle.json` | Savaş sabitleri + 5 faz tanımı + sunucu varsayılanları | A-SAVAS, A-HALKA (`GameConfig.gd`) |
| `units.json` | Birim araştırma/eğitim gereksinimleri (Kışla seviyeleri) + maliyet/istatistik | A-ORDU, A-SAVAS |

**Kaynak veri:** `data/buildings.json` (bina seviye tabloları) ve `game/data/units.json` (birimler).
Bu iki dosyanın **kopyası** `game/data/` altındadır ve bayt-bayt aynıdır.
Doğrulayıcı, kural dosyalarını bu kaynaklarla karşılaştırır.

---

## 1. Sözleşme Kuralları (konvansiyon)

1. **Alan adları `snake_case`** ve kararlıdır — **yeniden adlandırılmaz** (kırması).
2. Dosyalar **UTF-8, BOM'suz** yazılır (Godot `JSON` sınıfı ile uyum için).
3. Kaynak sırası her yerde **`wood`, `stone`, `iron`** (Türkçe: Odun, Taş, Demir).
4. Bina anahtarları: `main, stone, wood, iron, storage, hide, farm, barracks, wall,
   market, stable, garage, snob, smith, statue` (Türkçe adlar `docs/TERIMLER.md`).
5. Yüzdeler **`*_percent`** alanlarında **tam sayı** turur (ör. `105` = %105).
   Çarpan gerektiğinde `değer / 100`.
6. "Bilinmeyen" bir formül **uydurulmaz**. Her bilinmeyen alan:
   ```json
   { "known": false, "assumption": "…", "open_question": true }
   ```
   Doğrulayıcı, `known:false` olan her düğümde `assumption` alanının **dolu** olmasını şart koşar.
7. Bütün kural dosyaları ortak alanlara sahiptir:
   `schema_version`, `generated_by`, `source`, `description`.
8. Yuvarlama: **`round_half_up`** = `floor(x + 0.5)` (Godot'ta `floori(x + 0.5)`).

---

## 2. Gereksinim Zinciri (özet)

```
SERBEST BAŞLANGIÇ :  main · stone · wood · iron · farm · storage

  hide      ← farm Lv3
  barracks  ← storage Lv3  VE  farm Lv3
  wall      ← barracks Lv1
  market    ← storage Lv5
  stable    ← market Lv1
  garage    ← barracks Lv5
  snob      ← garage Lv5
  smith     ← snob Lv1
  statue    ← TÜM binalar maksimum seviyede
```

**Birim araştırma (Kışla seviyesi):** `farmer,spear,sword`=1 · `axe`=2 · `spy`=4 ·
`bow`=5 · `light`=7 · `heavy`=16 · `ram`=20 · `kata`=25 · **`snob` araştırılmaz**
(Köşk'te Altın Zırh ile eğitilir).

---

## 3. `requirements.json`

```jsonc
{
  "schema_version": "1.0.0",
  "source": "data/buildings.json",
  "key_order": ["main", "stone", …],          // kararlı görüntüleme sırası
  "free_start_buildings": ["main","stone","wood","iron","farm","storage"],
  "requires_operator_default": "all",
  "special_rules": { "all_buildings_at_max_level": "…" },
  "buildings": [
    {
      "key": "barracks",
      "name_tr": "Kışla",
      "max_level": 30,
      "requires": [ {"building": "storage", "level": 3},
                    {"building": "farm",    "level": 3} ],
      "requires_operator": "all",             // hepsi sağlanmalı
      "requires_special": null,               // veya "all_buildings_at_max_level"
      "unlock_note": "…"                       // insan-okunur açıklama
    }
  ],
  "unit_research": {                          // units.json ile AYNI olmalı (validator kontrol eder)
    "source_of_truth": "game/data/rules/units.json#research_requirements_barracks",
    "barracks_levels": { "farmer": 1, …, "kata": 25 },
    "not_researched": ["snob"],
    "barracks_key": "barracks"
  }
}
```

**Anlambilim:** Bir binayı `level` seviyesine çıkarmak için `requires` listesindeki **tüm**
`(building, level)` çiftleri sağlanmalıdır. `statue` için `requires` listesi kendisi hariç
**14 binayı kendi `max_level` değerinde** ister ve bu, `requires_special:
"all_buildings_at_max_level"` ile simgeleştirilir.

**DAG tüketicisi için:** Kenarlar `(building → requires[].building)` yönündedir;
graf **asikliktir** (doğrulayıcı kanıtlar + topolojik sıra yazdırır).

---

## 4. `costs.json`

```jsonc
{
  "rounding": "round_half_up",
  "formula": "cost(building, level, resource) = round_half_up(base_level1_cost[…] * growth_factor_groups[building_group[…]][…] ** (level - 1))",
  "resources": ["wood", "stone", "iron"],
  "growth_factor_groups": {
    "standard":  { "wood": 1.165, "stone": 1.170, "iron": 1.160 },
    "core":      { "wood": 1.165, "stone": 1.170, "iron": 1.165 },
    "barracks":  { "wood": 1.21,  "stone": 1.23,  "iron": 1.22  },
    "residence": { "wood": 1.30,  "stone": 1.30,  "iron": 1.30  },   // snob
    "goldsmith": { "wood": 1.40,  "stone": 1.40,  "iron": 1.40  },   // smith
    "monument":  { "wood": 1.0,   "stone": 1.0,   "iron": 1.0   }    // statue (tek seviye)
  },
  "building_group": { "main": "core", "farm": "standard", "barracks": "barracks", … },
  "base_level1_cost": { "main": {"wood":70,"stone":85,"iron":65}, … },
  "validation": { "abs_tolerance": 2, "rel_tolerance": 0.005 }
}
```

> ⚠️ **Önemli bulgu (validator ile kanıtlandı):** Standart binalarda demir faktörü **tek
> değildir**. Kaynak/depo çekirdeği (`main, stone, wood, iron, storage, hide`) **1.165**,
> diğer standart binalar (`farm, wall, market, stable, garage`) **1.160** kullanır. Bu ayrım
> olmadan tablolar **%19'a varan** sapma verir; ayrımla **hatasız** üretilir. Bu yüzden iki
> grup vardır (`core` ve `standard`).
>
> Formül tüketicisi: `for level in 1..max_level: cost = round_half_up(base * factor ** (level-1))`.

---

## 5. `production.json`

### 5.1 `curves.*` — eğriler

Her eğri şu alanlara sahiptir: `applies_to`, `unit`, `formula`, `level_min`, `level_max`,
`base`, `growth_factor`, `source_building`, `source_column`, `tolerance_rel`, `known`,
`is_approximation`, `values` (**kesin tablo**, `level_min..level_max`).

| Anahtar | Bina | Formül | `values` uzunluğu |
|---|---|---|---|
| `raw_material_production` | wood/stone/iron | `round(120 × 1.115^(sv-1))` | 50 |
| `warehouse_capacity` | storage | `round(1000 × 1.15^(sv-1))` | 50 |
| `hideout_capacity` | hide | `round(150 × 1.19^(sv-1))` | 30 |
| `mill_max_citizens` | farm | `round(250 × 1.115^(sv-1))` | 50 |
| `donkey_production` | stable | `round(16 × 1.18^(sv-1))` | 30 |

> **Önemli:** `values` dizisi **kaynaktaki kesin tablodur** ve oyun **onu** kullanmalıdır.
> `formula` yalnızca **kestirim/yeniden üretim** içindir; `tolerance_rel` içinde kalır
> (production %0.32, warehouse %0.81, mill %3.62, donkey %2.80 — validator raporlar).
> Yeni seviye eklemek gerekirse formül kullanılır, `values` elle değiştirilmez.

### 5.2 `tables.*` — kesin tablolar (formül yok)

* `wall_defence_bonus_percent.values_percent` → **21 eleman**, indeks = sur seviyesi,
  `[0]=100` (sur yok), `[1]=105 … [20]=220`. Çarpan = `değer / 100`.
* `market_donkey_capacity.values` → **30 eleman**, `values[i]` = (i+1). market seviyesinin
  maksimum katır sayısı (`1 … 600`).

### 5.3 `unresolved.*`
`production_mode` (üretim bina başına mı vatandaş başına mı — **bilinmiyor**), katır taşıma
kapasitesi ve katır yolculuk süresi.

---

## 6. `time-factors.json`

```jsonc
{
  "time_factor_column": {
    "main":     { "applies_to": "construction",          "values_percent": [100, 96, …], "known": true },
    "barracks": { "applies_to": "research_and_training", "values_percent": [80, 74, …],  "known": true },
    "garage":   { "applies_to": "alchemist_research",    "values_percent": [0,0,0,0,0],
                  "known": false, "anomaly": true, "assumption": "…" },   // kaynakta tümü %0 → veri hatası şüphesi
    "snob":     { "applies_to": "count_training",        "values_percent": [80, 72, …],  "known": true }
  },
  "build_queue_extra_cost": {
    "free_jobs": 3,
    "values_percent": [0, 0, 0, 25, 56, 95, 144, 205, 281, 376],
    "index_note": "values_percent[i] → kuyruktaki (i+1). iş; çarpan = 1 + değer/100"
  },
  "unresolved": { "construction_time_formula": {…}, "research_time_formula": {…}, "training_time_formula": {…} }
}
```

Her seri **çarpan**tır (`values_percent[i] / 100`), `[0]` = seviye 1.
**Zaman faktörünün çarpıldığı taban süre yardım sitesinde YOK** → `unresolved` altında
`known:false` olarak işaretli. Taban süreler tahmin edilmez.

---

## 7. `battle.json`

| Grup | Alanlar (özet) |
|---|---|
| `morale` | `min` 0.30, `max` 1.00 — **eğri `known:false`** |
| `luck` | `min` −0.25, `max` +0.25 |
| `wall_bonus` | `production.json#tables.wall_defence_bonus_percent`'e referans |
| `night_bonus` | `multiplier: 2.0`, `window_local`, `enabled_by_default {en:false, tr:true}` |
| `memorial` | `fortification_bonus: 0.50` |
| `min_attack_units` | `barracks_factor: 3` → **3 × Kışla seviyesi** |
| `attack_protection` | 5 gün yeni oyuncu, 7 gün fetih, oran `10.0`, kanun kaçağı 60 gün, highscore 200 |
| `cancellation` | `attack_cancel_minutes: 30`, `donkey_cancel_minutes: 15` |
| `realm_of_power` | artış %1/saat; yabancı Kont düşüşü `2250–2750` (Anıt: `1750–2250`); saldırı başına 1 Kont etkili |
| `count` | `researched:false`, `training_building:"snob"`, `requires_gold_armor:true`, `max_distance_fields {en:100, tr:80}` |
| `loot` | `hidden_floor_formula` (kalan ≥ gizli depo kapasitesi) |
| `loss_distribution`, `spy`, `siege` | **`known:false`** — formüller bilinmiyor |
| `config_defaults` | A-HALKA `GameConfig.gd` için sunucu varsayılanları (EN/TR) |
| `phases` | **5 faz**, `order` 1..5 |

`phases[].key` sırası: `wall_damage` → `spy_attack` → `normal_battle` → `building_damage`
→ `conquest_and_pillage`. Türkçe adlar `docs/TERIMLER.md`'den birebir alınmıştır.

---

## 8. `units.json`

```jsonc
{
  "canonical_for": "birim araştırma gereksinimleri (Kışla seviyeleri)",
  "research_building": "barracks",
  "research_requirements_barracks": { "farmer": 1, "axe": 2, "spy": 4, …, "kata": 25 },
  "not_researched_units": ["snob"],
  "classes": { "infantry": [...], "archer": ["bow"], "cavalry": [...], "siege": [...], "special": [...] },
  "units": [
    {
      "key": "farmer",
      "name_tr": "Köy Koruyucusu",
      "unit_class": "infantry",
      "cost": { "wood": 10, "stone": 3, "iron": 7 },
      "settlers": 1,
      "speed": { "minutes_per_field": 5.0, "mobility": 5, "source_raw": "5 Alan başına dakika" },
      "carry_capacity": 5,
      "combat": { "attack": 20, "defence_infantry": 40, "defence_cavalry": 30, "defence_archer": 5 },
      "research": { "required": true, "building": "barracks", "level": 1,
                    "cost": {"wood":10,"stone":10,"iron":10}, "base_time_seconds": 10 },
      "training": { "building": "barracks", "cost": {…}, "settlers": 1,
                    "base_time_seconds": 14, "requires_gold_armor": false },
      "notes": null
    }
  ]
}
```

* `speed.minutes_per_field` = **alan başına dakika** (küçük = hızlı).
* `base_time_seconds` = Kışla/Köşk zaman faktörü **uygulanmadan önceki** temel süre;
  katsayı `time_coefficient_known: false`.
* `snob` için: `research.required=false`, `research.cost=null`, `training.building="snob"`,
  `training.requires_gold_armor=true`.
* `class_*` alanları **resmî değildir** (`class_is_official: false`), proje-içi gruplamadır.

---

## 9. Tüketim örneği (Godot, A-HALKA `GameData.gd`)

```gdscript
var req   := _load("res://data/rules/requirements.json")
var costs := _load("res://data/rules/costs.json")
var prod  := _load("res://data/rules/production.json")
# bina maliyeti:
func building_cost(key: String, level: int) -> Dictionary:
    var base: Dictionary = costs["base_level1_cost"][key]
    var f: Dictionary = costs["growth_factor_groups"][costs["building_group"][key]]
    var out := {}
    for r in ["wood", "stone", "iron"]:
        out[r] = int(floor(base[r] * pow(f[r], level - 1) + 0.5))  # round_half_up
    return out
# gereksinim kontrolü:
func can_build(key: String, levels: Dictionary) -> bool:
    for b in _requirements_by_key[key]["requires"]:
        if int(levels.get(b["building"], 0)) < int(b["level"]):
            return false
    return true
```

---

## 10. Doğrulama

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
python tools/validate_rules.py
```

`tools/validate_rules.py` şunları **kanıtlar** (117 kontrol):
DAG asikliği ve erişilebilirliği · referans/seviye geçerliliği · serbest başlangıç ·
görev tanımındaki zincir · Anıt özel kuralı · maliyet faktörlerinin tabloları toleransla
üretmesi · tabloların kaynakla birebirliği · monotonluk · kuyruk tablosu · savaş sabitleri ·
faz yapısı · birim gereksinim/istatistik/süreleri · çapraz dosya tutarlılığı ·
`known:false ⇒ assumption` kuralı.

**Başarıda exit code 0, aksi halde 1** (CI için).

---

## 11. Açık Sorular (`AÇIK SORU:`)

| # | Konu | Durum |
|---|---|---|
| 1 | İnşaat/araştırma/eğitim **süre formülü** (zaman faktörünün çarpıldığı taban) | ❔ `time-factors.json#unresolved` |
| 2 | **Simyager** zaman faktörü (kaynakta tümü %0) | ❔ `time_factors.garage.known=false` |
| 3 | **Moral eğrisi** (puan oranı → moral) | ❔ `battle.json#morale.known=false` |
| 4 | **Casus sağkalım** formülü + gizli casusluk hız çarpanı | ❔ `battle.json#spy` |
| 5 | **Şahmerdan / Mancınık** hasar formülleri | ❔ `battle.json#siege` |
| 6 | **Kayıp dağıtım** eğrisi | ❔ `battle.json#loss_distribution` |
| 7 | Katır **taşıma kapasitesi** ve **yolculuk süresi** | ❔ `production.json#unresolved` |
| 8 | Üretim **bina başına mı vatandaş başına mı** | ❔ `production.json#curves…unresolved` |
| 9 | Simyager teknik listesi + **Altın Zırh** maliyet artış çarpanı | ❔ kapsam dışı (parametrik) |
| 10 | `garage` zaman faktörünün gerçek serisi | ❔ yukarıdaki #2 ile aynı |

> Bu maddeler **uydurulmadı**; oyun istemcisinden doğrulanana kadar parametrik/`known:false`
> bırakıldı.
