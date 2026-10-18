# ASSUMPTIONS — Kural Motoru Varsayımları (Taht ve Kılıç)

> **Sahip:** A-MOTOR · **Kapsam:** `game/scripts/rules/RulesEngine.gd`, `game/scripts/model/VillageModel.gd`
> **Kural (docs/19 §2.5):** Bilinmeyen formüller **uydurulmaz**. Her bilinmeyen için **tek bir sabit**
> seçilir ve burada gerekçesiyle belgelenir. Referans alanlar `game/data/rules/*.json`
> içindeki `known: false` düğümleridir.
>
> Doğrulanmış (bilinen) formüller burada listelenmez; onlar `docs/15-MATEMATIK-VE-FORMULLER.md`
> ve `game/data/rules/README.md` içindedir.

---

## 1. Özet Tablo

| # | Fonksiyon | Bilinmeyen | Seçilen sabit / yöntem | Referans (`known:false`) |
|---|---|---|---|---|
| 1 | `build_seconds(key, level)` | İnşaatın **taban süresi** | `BASE_BUILD_SECONDS = 60.0` s + Kale (`main`) inşaat zaman faktörü serisi × seviye | `time-factors.json#unresolved.construction_time_formula`, `#unresolved.build_time_scaling` |
| 2 | `research_seconds(unit, lvl)` | Kışla **süre katsayısı** | `units.json` temel süre × Kışla zaman faktörü (`lvl`; `-1` → birimin min. Kışla seviyesi) | `time-factors.json#unresolved.research_time_formula`, `units.json#time_coefficient_known` |
| 3 | `training_seconds(unit, n, lvl)` | Kışla/Köşk **süre katsayısı** | `units.json` temel süre × adet × Kışla/Köşk zaman faktörü (`lvl`; `-1` → min. ilgili bina seviyesi) | `time-factors.json#unresolved.training_time_formula` |
| 4 | `is_researched` / `can_research` | Araştırma **durumu** | **ÇÖZÜLDÜ:** `village.researched[unit]` bayrağı (araştırma gerçek bir eylemdir; türetilmez) | — (docs/19 §4 güncellendi) |
| 5 | `unit_speed(unit)` / `unit_mobility(unit)` | Yolculuk hızı türü | `unit_speed` → **float** `speed.minutes_per_field` (alan/dk, kesin); `unit_mobility` → int `speed.mobility` (bilgi amaçlı) | `units.json` (resmî `Hareketlilik`) |
| 6 | `VillageModel.create(...)` | Yeni köyün başlangıç seviyeleri | Serbest başlangıç binaları = **1**, diğerleri **0**; `researched = {}`; `realm_of_power = points` (başlangıçta tam, tavan = points) | `player_points.txt` (Güç Alanı) |
| 7 | `production_per_hour` | Üretim bina başına mı, vatandaş başına mı | **Bina başına** (tablodaki tek değer aynen) | `production.json#unresolved.production_mode` |

---

## 2. Ayrıntılar

### #1 — `build_seconds(key, level)` (İnşaat süresi)
**Bilinmeyen:** Yardım sitesinde inşaat süresi = *zaman faktörü × taban süre* olduğu anlaşılıyor,
ancak **taban süre** hiçbir yerde verilmiyor (`time-factors.json#unresolved.construction_time_formula`,
`known:false`). Zaman faktörü **serileri** ise biliniyor (`known:true`).

**Seçilen yöntem (tek sabit + bilinen seri):**
```
build_seconds(key, level) = BASE_BUILD_SECONDS × level × (main_zaman_faktörü(level) / 100) / speed
BASE_BUILD_SECONDS = 60.0
```
- `main` serisi `applies_to = "construction"` olduğu için inşaat faktörü olarak kullanılır
  (seviye indeksi `level`; seri dışında en yakın uca kırpılır).
- **Tek sabit**: `BASE_BUILD_SECONDS = 60.0`. Seviye ile **doğrusal** büyüme varsayıldı
  (maliyet geometrik büyürken sürenin sabit kalmaması gerektiği için en yalın varsayım).
- `speed` böler (docs/19 §2.4).

> ⚠️ Sayı **kesin değildir**; yalnızca göreli/sıralı davranışı verir. Oyun istemcisinden
> doğrulanınca bu sabit değişecektir.

### #2 — `research_seconds(unit, building_level)` (Araştırma süresi)
Birim başına **temel süre** `rules/units.json → research.base_time_seconds` içinde **bilinir**
(ör. Muhafız 120 s). **Bilinmeyen**, bu süreye uygulanacak **Kışla katsayısıdır**

Seçilen yöntem:
```
research_seconds(unit, building_level) =
    base_time_seconds(unit) × (Kışla_zaman_faktörü(building_level) / 100) / speed
```
- `building_level` verilmezse (`-1`) birimin **ilk erişilebilir olduğu** Kışla seviyesi
  (`research_requirements_barracks`) kullanılır — geriye uyumlu, en nötr seçim.
- `snob` (Kont) araştırılmaz → `0.0`.

### #3 — `training_seconds(unit, count, building_level)` (Eğitim süresi)
`rules/units.json → training.base_time_seconds` **bilinir**; katsayı **bilinmez**. Yöntem:
```
training_seconds(unit, count, building_level) =
    base_time_seconds(unit) × count × (ilgili_bina_zaman_faktörü(building_level) / 100) / speed
```
- İlgili bina: `training.building` (`barracks`, Kont için `snob`).
- `building_level` verilmezse (`-1`): araştırılabilir birimlerde gereken Kışla seviyesi; Kont'ta **1**
  (Köşk en az L1).
- `snob` serisi `count_training`, `barracks` serisi `research_and_training` için kullanılır.

### #4 — `is_researched` / `can_research` (ÇÖZÜLDÜ — docs/19 güncellendi)
Araştırma, KingsAge'de **gerçek bir eylemdir**: bedeli ödenir, süre geçer, **bir kez** yapılır.
Bu yüzden durum Kışla seviyesinden **türetilemez**; köy şemasına `researched: {}` eklendi
(docs/19 §3.1) ve imzalar köyü alacak şekilde değişti.
- `is_researched(village, unit)` → `village.researched[unit]` (varsayılan `false`).
- `can_research(village, unit)` → araştırılabilir birim **+** Kışla ≥ gereksinim **+** henüz
  araştırılmamış **+** hammadde araştırma maliyetini karşılıyor.

### #5 — `unit_speed(unit)` / `unit_mobility(unit)`
İki ayrı kavram ayrıldı:
- `unit_speed(unit) -> float` = `units.json → speed.minutes_per_field` (**alan/dakika**, kesin,
  yuvarlanmamış). Yolculuk süresi hesabı bunu kullanır; int kırpma **%11** hataya yol açıyordu (A-DUNYA).
- `unit_mobility(unit) -> int` = `units.json → speed.mobility` (resmî "Hareketlilik"), bilgi amaçlı.
Küçük değer hızlıdır (ör. Casus 2.25 alan/dk, hareketlilik 2; Şahmerdan 7.5, hareketlilik 8).

### #6 — `VillageModel.create(...)` başlangıç köyü
Yardım sitesi "yeni köy hangi binalarla/hangi seviyede başlar" belirtmiyor. `docs/19 §3.1`
örneğinde `"buildings": { "main": 1, "wood": 1, ... }` göründüğü için:
- **Serbest başlangıç binaları** (`main, stone, wood, iron, farm, storage`) → **seviye 1**,
- diğer tüm binalar → **seviye 0**,
- `researched` → **`{}`** (hiçbir birim araştırılmamış),
- `bonus_type` → `""` (bonus köyü değil),
- **Güç Alanı**: başlangıçta **tam** (`realm_of_power = points`), **tavan = points**
  (`player_points.txt`: "güç alanı 0 ile köyün puanı arasında değişir"). Saatte `+%1` artış
  A-EKONOMI döngüsünün işidir; `refresh_realm` yalnızca tavanı uygular (`[0, points]`'e kırpar).
- `points` → türetilmiş (`Σ bina puanı`); `refresh_points(village) -> int` ile tazelenir.

> ⚠️ Başlangıç **bina seviyeleri** doğrulanmamıştır (kaynak yok). A-EKONOMI farklı bir başlangıç
> isterse tek satır değişiklikle uyarlanır. Rapor: **AÇIK SORU**.

### #7 — Üretim modu
`production.json#unresolved.production_mode` (`known:false`) gereği üretim **bina başına**
kabul edildi; `production_per_hour` tablodaki saatlik değeri aynen döndürür (vatandaş bölmesi yok).

---

## 3. Kapsam Dışı Bırakılan Bilinmeyenler (bu modülde ele alınmaz)

Aşağıdakiler `RulesEngine`/`VillageModel` API'sinde **yok**; ilgili ajanlar (A-SAVAS, A-KESIF,
A-EKONOMI) ele alır:

| Konu | Referans |
|---|---|
| Moral eğrisi | `battle.json#morale.known:false` |
| Casus sağkalım / gizli casusluk çarpanı | `battle.json#spy` |
| Şahmerdan / Mancınık hasarı | `battle.json#siege` |
| Kayıp dağıtım eğrisi | `battle.json#loss_distribution` |
| Katır taşıma kapasitesi & yolculuk süresi | `production.json#unresolved.donkey_carry_capacity`, `#unresolved.donkey_travel_time` |
| Simyager teknik listesi & Altın Zırh çarpanı | `time-factors.json#time_factor_column.garage.known:false` |
| Simyager (garage) zaman faktörü serisi (kaynakta tümü %0) | aynı |

---

## 4. Doğrulanmış (varsayım gerektirmeyen) kısımlar

- **Bina maliyeti** `cost()` → büyüme faktörleri + `round_half_up`; **15 bina × tüm seviyeler**
  (`data/buildings.json`) ile **bit-bit eşit** (test: hata 0).
- **Kapasite/nüfus/katır/sur** değerleri `production.json` **kesin tablolarından** (`values`) aynen.
- **Köy puanı** `building-points.json`; tam gelişmiş köy = **10.000**.
- **Gereksinim zinciri** `requirements.json` DAG'ından (topolojik).
