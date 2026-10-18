# ASSUMPTIONS — Dünya / Harita (A-DUNYA)

> **Bu dosya, `game/scripts/world/**` içinde kullanılan sabitlerin ve bilinmeyen formüllerin
> tek listesidir.** Kural: kaynakta (`docs/`, `research/text-tr/`) olmayan hiçbir değer *uydurulmaz*;
> yağ için **tek bir sabit** seçilir, gerekçesi yazılır ve **`AÇIK SORU`** olarak raporlanır
> (`docs/19` §2.5).
>
> İlgili dosyalar: `WorldModel.gd` (`docs/19` §6 sözleşmesi), `WorldGenerator.gd` (deterministik üretim),
> `Travel.gd` (yolculuk + hareket yardımcıları), `game/tests/test_world.gd`.

---

## 0. Kaynak ve kapsam

| Konu | Kaynak | Durum |
|---|---|---|
| Dünya boyutu **200×200**, ~100 bot köyü | `docs/19` §6 (karar) | ✅ bilinen |
| Kıta = 100×100 alan, koordinat `X\|Y` | `docs/10` §1, `docs/19` §6 | ✅ bilinen |
| Kıta formülü: `floor(Y/100)*10 + floor(X/100)`, etiket `"K" + floor(Y/100) + floor(X/100)` | `docs/19` §6 (onay), `docs/10` §1 örneği | ✅ bilinen |
| Birim hızı = **alan başına dakika** (küçük = hızlı), kesin değerler | `docs/05` §2, `data/units.json`, `RulesEngine.unit_speed()` | ✅ bilinen |
| `GameConfig.unit_speed` yolculuk sürelerini **böler** | `docs/19` §2.4 | ✅ bilinen |
| İptal süreleri (saldırı 30 dk / katır 15 dk) | `docs/09` §6 | ✅ bilinen |
| Köy şekli (**17 alan**) | `docs/19` §3.1 | ✅ bilinen |
| Bonus köy: **tek** tip + sahibi **'Usta'**, 6 tip ve etkileri | `research/text-tr/villages.txt`, `docs/19` §3.1 | ✅ bilinen |
| Terkedilmiş köy: soyguncular **bina inşa eder** ve **askerî birim üretir** | `research/text-tr/villages.txt` | ✅ bilinen |
| Güç Alanı `0` ile **köy puanı** arasında; başlangıçta tavan = puan | `docs/10` §3, `docs/19` §3.1 | ✅ bilinen |
| Üretimin deterministik olması (`RandomNumberGenerator`, global `randi()` yasak) | `docs/19` §2.3 | ✅ bilinen |

---

## 1. Yolculuk süresi — formül

```
saniye = Öklid_mesafe(alan) × en_yavaş_birim(alan/dakika) × 60 / GameConfig.unit_speed
```

* **`en_yavaş_birim`** = ordudaki **en yavaş** birimin değeri (`docs/05`: hız *alan başına dakika*,
  düşük = hızlı; yavaşlığı **en yavaş birim** belirler). Kaynak sırası:
  1. `data/rules/units.json` → `units[].speed.minutes_per_field` (**kanonik**; `RulesEngine.unit_speed()`
     bu değeri `float` döner — `docs/19` §4.5),
  2. `data/units.json` → `speed` metni (`"4.5 Alan başına dakika"` → 4.5),
  3. `Travel.UNIT_MINUTES_PER_FIELD_FALLBACK` (aynı değerlerin gömülü kopyası — veri katmanı
     yüklenmemişse; test bu tablonun `rules/units.json` ile birebir olduğunu doğrular).
* Boş ordu veya 0 hız → **0 saniye** (yolculuk yok). Bilinmeyen birim anahtarları yok sayılır.
* ⚠️ **Yuvarlama yok:** süre `float` saniye olarak döner (`docs/19` §2.1–2.2). Unix damgasına
  çevrilirken `round_half_up` uygulanır (`Travel.arrive_unix`).

### Seçilen (bilinmeyen) sabitler

| Sabit | Seçilen değer | Gerekçe / durum |
|---|---|---|
| Mesafe türü | **Öklid, tam (yuvarlanmamış)** | `docs/10`/`docs/05` mesafe formülü **vermez**; KingsAge/TW ailesi Öklid kullanır. → `AÇIK SORU #1` |
| `GameConfig.speed` yolculuğa | **uygulanmaz** | `docs/10` §5 "Hız" ve "Birim hızı" **ayrı ayarlardır**; hareketi yalnızca *Birim hızı* etkiler. → `AÇIK SORU #2` |
| Gidiş-dönüş | `2 × gidiş` | Kaynakta ayrı bir dönüş katsayısı yok ("yağma yavaşlatmaz" kararı onaylandı). → `AÇIK SORU #3` |

---

## 2. Kıta düzeni (onaylandı)

```gdscript
continent_id(x, y)    = floor(y / 100) * 10 + floor(x / 100)  # docs/19 §6
continent_label(x, y) = "K%d%d" % [floor(y / 100), floor(x / 100)]
# docs/19 §6 + docs/10 §1 örneği: 499|506 → K54 ✓
```

* Kıta kenarı **100 alan** kaldı (resmî kaynak: *"100x100'lük bölüm bir kıtayı temsil eder"*).
* **Sonuç (200×200 dünya):** dünya **4 kıtaya** ayrılır → `K00, K01, K10, K11`.
* `docs/10` §1'deki hatalı formül metni düzeltildi; `continent_of()` geriye dönük ad olarak
  `continent_label()`'a devreder.

---

## 3. Yerleşim (kümeleme) modeli

Köyler düzgün rastgele serpilmez; **yerleşim kümeleri** hâlinde yerleşir (KingsAge'de yerleşimler
kıtalar içinde toplanır; miniharitada yoğunluk ancak böyle anlamlı olur).

| Sabit | Değer | Gerekçe |
|---|---|---|
| `CLUSTER_SIZE` | 25 alan | 200/25 = 8×8 = **64 küme**; her kümede ~3 köy |
| `CLUSTER_SPREAD` | ±9 alan | Küme hücresi (25 alan) içinde kalır |
| `CLUSTER_JITTER` | ±3 alan | Düzenli ızgara görünümünü kırar |
| `MAX_PLACEMENT_ATTEMPTS` | 40 | Küme içinde boş alan aranırken |
| `MIN_VILLAGE_DISTANCE` | **1** (yalnızca aynı alan yasak) | Kaynakta minimum mesafe **yok**; onaylanan tek şart "aynı alana iki köy konamaz". → `AÇIK SORU #4` |

Küme dolarsa dünyanın herhangi bir yerinde deterministik olarak boş alan aranır (`find_free_spot`);
`SIZE² = 40.000 ≫ 210 köy` olduğundan bu yol pratikte hiç kullanılmaz.

---

## 4. Terkedilmiş (soyguncu) ve bonus köyler

### 4.1 Bonus köyler — **resmî 6 tip** (`research/text-tr/villages.txt`)

Her bonus köyün **tek** bonusu olur ve başında **'Usta'** vardır (`owner = "Usta"`).

| `bonus_type` | Etki | Kodda |
|---|---|---|
| `wood` | Odun üretimi **+%10** | `bonus_production_multipliers().wood = 1.10` |
| `stone` | Taş üretimi **+%10** | `bonus_production_multipliers().stone = 1.10` |
| `iron` | Demir üretimi **+%10** | `bonus_production_multipliers().iron = 1.10` |
| `citizen` | Vatandaş **+%10** | `bonus_citizen_multiplier() = 1.10` |
| `training` | Birim eğitimi **+%10 daha hızlı** | `bonus_training_speed_multiplier() = 1.10` (süre bölünür) |
| `production` | **Tüm** hammaddeler **+%3** | `bonus_production_multipliers()` → hepsi 1.03 |

* Bonus olmayan köylerde `bonus_type = ""`.
* Etkiler `WorldModel.village_*()` sarmalayıcılarıyla köy bazında sorgulanır; tüketim
  **A-EKONOMI / A-ORDU** işidir (bu modül yalnızca **çarpan** yayınlar, üretimi hesaplamaz).
* Tip dağılımı: **round-robin** (`BONUS_TYPES[i % 6]`) → bonus sayısı ≥ 6 ise **6 tipin tamamı**
  dünyada bulunur. Gerçek sıklıklar kaynakta yok → `AÇIK SORU #5`.

### 4.2 Terkedilmiş köyler — soyguncular

Kaynak: *"Soyguncular köyün gelişimini devam ettirirler, **bina inşa ederler** ve **askerî
birimler oluştururlar**."*

* `owner = "Soyguncular"`, `is_barbarian = true`, `protection_until = 0`.
* **Binalar gelişmiştir**: her köye deterministik bir **gelişim kademesi** `tier ∈ [1, 10]` verilir;
  çekirdek binalar (`main, stone, wood, iron, farm, storage`) + `barracks` + `wall` + `hide`
  bu kademeye yükseltilir; Market/Katır/Simyager/Köşk/Kuyumcu/Anıt **0** kalır.
* **Ordu**: `units` **normal 11 birim anahtarıyla** doldurulur (özel "soyguncu" anahtarı **yoktur**).
  Yalnızca **Kışla seviyesinin izin verdiği** birimler üretilir (`BARRACKS_REQUIREMENT`), miktar
  kademeyle ölçeklenir. Garnizon asla boş kalmaz.
* `researched`: garnizonda bulunan birimler `true` (soyguncular ürettikleri birimi "araştırmış" sayılır).

| Sabit | Değer | Durum |
|---|---|---|
| `BARBARIAN_RATIO` | **1.0** (bot başına 1 terkedilmiş köy) | ❌ bilinmiyor — oran sunucuya göre değişir → `AÇIK SORU #6` |
| `BONUS_RATIO` | **0.1** (100 botta 10 bonus köy) | ❌ bilinmiyor → `AÇIK SORU #6` |
| `BARBARIAN_MAX_TIER` | **10** | ❌ bilinmiyor (gelişim tavanı) → `AÇIK SORU #7` |
| Kademe dağılımı | `tier = 1 + floor(randf()^1.5 × 10)` (küçük köyler sık) | ❌ bilinmiyor → `AÇIK SORU #7` |
| `BARBARIAN_UNIT_WEIGHTS` | farmer 4 · spear 4 · sword 3 · axe 2 · bow 3 · light 1 · heavy 1; spy/ram/kata/snob **0** | ❌ bilinmiyor (savunma odaklı garnizon seçildi) → `AÇIK SORU #7` |
| `BARBARIAN_UNIT_CHANCE` | **0.6** (bir türün garnizonda bulunma olasılığı) | ❌ bilinmiyor → `AÇIK SORU #7` |
| Birim miktarı | `weight × tier × randf(0.5–1.5)` (en az 1) | ❌ bilinmiyor → `AÇIK SORU #7` |
| Bonus köy sahibi | **`"Usta"`** | ✅ resmî TR terim (`research/text-tr/villages.txt`) |
| Terkedilmiş köy sahibi | **`"Soyguncular"`** | ✅ resmî terim |

> Not: Soyguncu garnizonunda **casus / kuşatma / Kont** tutulmaz (bunlar savunma birimi değildir;
> `snob` ayrıca `not_researched_units` içindedir).

---

## 5. Dünya sözlüğü ve `tiles` biçimi

`generate_world()` dönüşü `docs/19` §6'daki üç anahtarı **aynen** içerir, üzerine **yalnızca ek**
anahtarlar koyar (mevcut anahtarların anlamı değişmez):

```gdscript
{
  "size": 200,                       # §6: dünya kenarı
  "villages": [ ... ],               # §6: docs/19 §3.1 köy sözlükleri (id'ye göre artan)
  "tiles": { "x,y": <village_id> },  # §6: dolu alanlar — String anahtar ("178,185") → int köy id
  "seed": 4242,                      # ek: üretim tohumu (kayıt/tekrar üretim için)
  "player_start": {"x":100,"y":100}, # ek: oyuncunun kurulacağı en yakın boş alan
  "counts": {"bot":100,"barbarian":100,"bonus":10,"total":210}   # ek: tür sayımı
}
```

* `tiles` **String** anahtar (`"x,y"`) kullanır → JSON'a (`GameState.to_dict()`) doğrudan yazılabilir
  ve `Vector2i`'nin serileştirme belirsizliğinden kaçınır. Yalnızca **dolu** alanlar saklanır
  (40.000 boş alan kaydedilmez).
* `Vector2i` yalnızca `find_free_spot()` dönüşünde kullanılır (§6 imzası böyle ister).
* Koordinatlar **1..200** (1 tabanlı), sınırlar dahil.

---

## 6. Determinizm kuralları

* Tek rastgelelik kaynağı `RandomNumberGenerator` + `rng.seed = seed`. **Global `randi()` ve
  `Array.shuffle()` kullanılmaz** (ikincisi global RNG'yi kullanır → `WorldGenerator._shuffle` yazıldı).
* Üretimde **sistem saati okunmaz**. Bu yüzden üretilen köylerde:
  * `protection_until = 0`
  * `conquest_protection_until = 0`

  Koruma süreleri (`docs/10` §5: 5 gün / 7 gün) **oyun zamanı** ile `GameConfig` üzerinden
  oyun katmanında (`Boot` / yeni köy kurulumu) yazılmalıdır. Aksi hâlde `world_hash()` çağrılar arası
  değişirdi. → `AÇIK SORU #8` (*"NPC köyleri de korumalı mı başlamalı?"*)
* Determinizm kanıtı: `test_world.gd` aynı tohum için hash eşitliğini **ve** süreçten bağımsız
  (iki ayrı çalıştırmada aynı) hash'i doğrular.

---

## 7. `travel_seconds` imzası: `slowest_unit_speed: float` (onaylandı)

Sözleşme başta `int` yazıyordu; **`docs/19` §6 artık `float`** olarak güncellendi.

* Birim hızları **ondalıklıdır** (`docs/05` §2): Silahtar 4.5, Casus 2.25, Kara Şövalye 2.75, Akıncı 2.5.
* Godot'ta `int` tipli parametreye `4.5` geçmek değeri **sessizce kırpar** (4.5 → 4, ölçülmüştür):
  süreler ~%11 sapar. Bu nedenle parametre **`float`**.
* `RulesEngine.unit_speed(unit_key) -> float` = **alan başına dakika** (kesin değer);
  `RulesEngine.unit_mobility(unit_key) -> int` = yuvarlanmış "Mobility" — yolculukta **kullanılmaz**.

---

## 8. Üretilen köylerin başlangıç durumu

* **Bot ve bonus** köyler `docs/19` §3.1'deki **başlangıç** durumunda üretilir:
  `main, stone, wood, iron, farm, storage = 1`, diğer 11 bina 0; kaynaklar 1000/1000/1000;
  `units` = 11 anahtar hepsi 0; `researched = {}`; `has_statue = false`.
  **Terkedilmiş** köyler bundan farklıdır (bkz. §4.2: gelişmiş binalar + dolu `units`).
* **Köy Puanı = `Σ taban_puan × seviye`** (`docs/15` §5.1, `data/building-points.json` doğrusal).
  Sabit tablo kodda tutulur (determinizm); test tabloyu **`GameData.points_for()` ile bina×seviye
  çaprazında** doğrular. Başlangıç köyü = **110**; tam gelişmiş köy = **10.000**.
* **Güç Alanı = köy puanı** ile başlar (tavan = puan) — **hem oyuncu hem NPC** köyleri için
  (`docs/10` §3 / `docs/19` §3.1). `validate_world()` `0 ≤ realm_of_power ≤ points` değişmezini
  denetler.
* **Bot köyleri geliştirilmez** (hepsi sv1). Gelişmiş bir dünya isteniyorsa geliştirme
  **A-BOT** (FAZ 11) veya QA denge simülasyonu tarafından yapılmalıdır — bu modülün kapsamı
  "yeni dünya üretimi"dir.
* **Bot başına 1 köy** (100 bot = 100 köy) — onaylandı.
* ✅ **A-MOTOR uyumu doğrulandı:** `VillageModel.create()` artık `researched = {}`,
  `realm_of_power = points` ve `bonus_type = ""` döndürüyor → `docs/19` §3.1/§5 ile birebir.

---

## 9. Testte kullanılan sabitler

| Sabit | Değer | Nerede |
|---|---|---|
| Test tohumu | `4242` | `test_world.gd` |
| Farklı tohum | `9999` | `test_world.gd` |
| Bot sayısı | `100` | `test_world.gd` |
| Beklenen toplam köy | `210` (100 + 100 + 10) | `test_world.gd` |
| Miniharita hücresi | 10 alan → 20×20 ızgara | `WorldModel.DEFAULT_MINIMAP_CELL` |
| Komşuluk yarıçapı | 10 alan | `WorldModel.DEFAULT_NEIGHBOR_RADIUS` |

---

## 10. `AÇIK SORU` listesi (A-ŞEF'e)

1. **Mesafe yuvarlaması:** KingsAge yolculuk mesafesini 0,5'e yuvarlıyor mu? Şu an **tam Öklid** (onaylandı, kayıt için).
2. **`GameConfig.speed` yolculuğu etkiliyor mu?** Onaylandı: **hayır**, yalnızca `unit_speed`.
3. **Dönüş süresi:** onaylandı **gidiş = dönüş** (yağma yavaşlatmaz).
4. **Minimum köy mesafesi:** kaynakta yok; onaylandı **yalnızca aynı alan yasak**.
5. **Bonus tip sıklıkları:** resmî kaynakta tip başına frekans yok; şu an **round-robin** (≥6 bonus
   köyde 6 tipin tamamı). Gerçek oranlar istemciden doğrulanmalı.
6. **Terkedilmiş/bonus köy oranları:** onaylandı **1.0** ve **0.1** (varsayım olarak kalıyor).
7. **Soyguncu gelişim modeli:** kademe tavanı (10), dağılımı (`randf()^1.5`), birim ağırlıkları ve
   miktar formülü **uydurulmuş varsayımlardır**; `research/text-tr/villages.txt` yalnızca
   "bina inşa ederler, askerî birim oluştururlar" der. Gerçek seviye/birim aralığı istemciden
   doğrulanmalı.
8. **NPC koruma süreleri:** üretici sistem saatini okumaz; `protection_until = 0`. NPC'lere koruma verilecek mi?
9. ✅ **ÇÖZÜLDÜ — `VillageModel.create()` uyumsuzluğu:** A-MOTOR güncelledi (`realm_of_power = points`,
   `researched = {}`, `bonus_type = ""`); `docs/19` §3.1/§5 ile birebir.
10. **`bonus_type` tüketicileri:** `village_production_multipliers()` / `village_citizen_multiplier()` /
    `village_training_speed_multiplier()` sarmalayıcıları **A-EKONOMI/A-ORDU** tarafından kullanılmalı;
    isim/yerleşim onayı bekleniyor (sözleşmede köy bazlı bonus sorgusu tanımlı değil).
