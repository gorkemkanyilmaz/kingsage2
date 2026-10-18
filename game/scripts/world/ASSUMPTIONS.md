# ASSUMPTIONS — Dünya / Harita (A-DUNYA)

> **Bu dosya, `game/scripts/world/**` içinde kullanılan sabitlerin ve bilinmeyen formüllerin
> tek listesidir.** Kural: yardım sitesinde (`docs/`) olmayan hiçbir değer *uydurulmaz*;
> yağ için **tek bir sabit** seçilir, gerekçesi yazılır ve **`AÇIK SORU`** olarak raporlanır
> (`docs/19` §2.5).
>
> İlgili dosyalar: `WorldModel.gd` (`docs/19` §6 sözleşmesi), `WorldGenerator.gd` (deterministik üretim),
> `Travel.gd` (yolculuk + hareket yardımcıları), `game/tests/test_world.gd`.

---

## 0. Kaynak ve kapsam

| Konu | Kaynak | Durum |
|---|---|---|
| Dünya boyutu **200×200**, ~100 bot köyü | Kullanıcı kararı (`TASKS-CODE.md` S-8), `docs/19` §6 | ✅ bilinen |
| Kıta = 100×100 alan, koordinat `X\|Y` | `docs/10` §1 | ✅ bilinen |
| Birim hızı = **alan başına dakika** (küçük = hızlı), kesin değerler | `docs/05` §2, `data/units.json` | ✅ bilinen |
| `GameConfig.unit_speed` yolculuk sürelerini **böler** | `docs/19` §2.4 | ✅ bilinen |
| İptal süreleri (saldırı 30 dk / katır 15 dk) | `docs/09` §6 | ✅ bilinen |
| Köy şekli (16 alan) | `docs/19` §3.1 | ✅ bilinen |
| Üretimin deterministik olması (`RandomNumberGenerator`, global `randi()` yasak) | `docs/19` §2.3 | ✅ bilinen |

---

## 1. Yolculuk süresi — formül

```
saniye = Öklid_mesafe(alan) × en_yavaş_birim(alan/dakika) × 60 / GameConfig.unit_speed
```

* **`en_yavaş_birim`** = ordudaki **en yavaş** birimin değeri (`docs/05`: hız *alan başına dakika*,
  düşük = hızlı; yavaşlığı **en yavaş birim** belirler). Kaynak sırası:
  1. `data/rules/units.json` → `units[].speed.minutes_per_field` (**kanonik**),
  2. `data/units.json` → `speed` metni (`"4.5 Alan başına dakika"` → 4.5),
  3. `Travel.UNIT_MINUTES_PER_FIELD_FALLBACK` (aynı değerlerin gömülü kopyası — veri katmanı
     yüklenmemişse; test bu tablonun `rules/units.json` ile birebir olduğunu doğrular).
* Boş ordu veya 0 hız → **0 saniye** (yolculuk yok). Bilinmeyen birim anahtarları yok sayılır.
* ⚠️ **Yuvarlama yok:** süre `float` saniye olarak döner (`docs/19` §2.1–2.2). Unix damgasına
  çevrilirken `round_half_up` uygulanır (`Travel.arrive_unix`).

### Seçilen (bilinmeyen) sabitler

| Sabit | Seçilen değer | Gerekçe / durum |
|---|---|---|
| Mesafe türü | **Öklid, tam (yuvarlanmamış)** | `docs/10`/`docs/05` mesafe formülü **vermez**; KingsAge/TW ailesi Öklid kullanır. Kullanıcı görevi "Öklid" istedi. → `AÇIK SORU #1` (istemcide 0,5 yukarı yuvarlama olabilir) |
| `GameConfig.speed` yolculuğa | **uygulanmaz** | `docs/10` §5 "Hız" ve "Birim hızı" **ayrı ayarlardır**; hareketi yalnızca *Birim hızı* etkiler. `docs/19` §2.4 hızın üretimi çarptığını söyler. → `AÇIK SORU #2` |
| Gidiş-dönüş | `2 × gidiş` | `description`/kaynakta ayrı bir dönüş katsayısı yok. Yağma yükü süreyi değiştiriyorsa istemciden doğrulanmalı → `AÇIK SORU #3` |

---

## 2. Kıta düzeni

```gdscript
continent_id(x, y) = floor(y / 100) * 10 + floor(x / 100)   # docs/10 §1 örneği: 499|506 → K54
continent_of(x, y) = "K%02d" % continent_id(x, y)           # → "K54"
```

* ⚠️ `docs/10` §1 **metni ile örneği çelişiyor**: metin `K + (floor(X/100)+1) + (floor(Y/100)+1−1)`
  der (499|506 için **K55**), ama aynı paragrafın örneği **K54**'tür. Doğrulanabilir tek veri örnek
  olduğu için **örneği üreten** biçim (0 tabanlı `floor`) seçildi.
* **Sonuç (200×200 dünya):** kıta kenarı 100 alan olduğu için dünya **4 kıtaya** ayrılır:
  `K00, K01, K10, K11` (`docs/10`'un 1000×1000'inde 100 kıta olurdu).
  Kıta adlarının 0 ile başlaması bu seçimin doğal sonucudur. → `AÇIK SORU #4`
  (*"200×200'de kıta boyutu da ölçeklenip 10×10=100 kıta mı olmalı?"*)

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
| `MIN_VILLAGE_DISTANCE` | **1** (yalnızca aynı alan yasak) | Kaynakta minimum mesafe **yok**; görev gereği tek şart "aynı konuma iki köy gelmemeli". → `AÇIK SORU #5` |

Küme dolarsa dünyanın herhangi bir yerinde deterministik olarak boş alan aranır (`find_free_spot`);
`SIZE² = 40.000 ≫ 210 köy` olduğundan bu yol pratikte hiç kullanılmaz.

---

## 4. Terkedilmiş (soyguncu) ve bonus köyler

| Sabit | Değer | Durum |
|---|---|---|
| `BARBARIAN_RATIO` | **1.0** (bot başına 1 terkedilmiş köy) | ❌ bilinmiyor — KingsAge'de oran sunucuya göre değişir → `AÇIK SORU #6` |
| `BONUS_RATIO` | **0.1** (bot başına 0.1 bonus köy → 100 botta 10) | ❌ bilinmiyor → `AÇIK SORU #6` |
| `BONUS_MULTIPLIER` | **1.25** (tek kaynak) | ❌ bilinmiyor: bonus köyün verdiği çarpan yardım sitesinde yok → `AÇIK SORU #7` |
| Terkedilmiş köy sahibi | `""` (boş) | `docs/10` §2 / `TERIMLER.md` §4: soyguncuların oyuncusu yok |
| Bonus köy sahibi | **`"Usta"`** | Resmî TR terim (`docs/TERIMLER.md` §4 — *Master of a bonus village*) |
| **Soyguncuların askerî gücü** | **yok** (`units` hepsi 0) | `docs/19` §3.1 `units` şekli yalnızca 11 oyuncu birimini kapsar; "soyguncu" bir birim anahtarı **yok** → `AÇIK SORU #8` |

Bonus köy, `bonus` sözlüğünde **tek** kaynağı 1.25 yapar (diğerleri 1.0); böylece tür ayrımı
`is_barbarian` / `bonus` / `is_bot` bayraklarından **türetilebilir** (ek alan gerekmez).

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
  değişirdi. → `AÇIK SORU #9` (*"NPC köyleri de korumalı mı başlamalı?"*)
* Determinizm kanıtı: `test_world.gd` aynı tohum için hash eşitliğini **ve** süreçten bağımsız
  (iki ayrı çalıştırmada aynı) hash'i doğrular.

---

## 7. ⚠️ `docs/19` §6 imzasından **bilinçli** sapma: `slowest_unit_speed: int → float`

Sözleşme `travel_seconds(from_x, from_y, to_x, to_y, slowest_unit_speed: int) -> float` yazar.

* Birim hızları **ondalıklıdır** (`docs/05` §2): Silahtar 4.5, Casus 2.25, Kara Şövalye 2.75, Akıncı 2.5.
* Godot'ta `int` tipli parametreye `4.5` geçmek değeri **sessizce kırpar** (4.5 → 4, ölçülmüştür):
  süreler ~%11 sapar, yani "kurallara %100 bağlılık" bozulur.
* Bu nedenle parametre **`float`** alındı. **İsim, sıra ve dönüş tipi sözleşmeye birebir uyar.**
  Tam sayı (ör. "Mobility" / `RulesEngine.unit_speed()` çıktısı) geçmek de çalışır.
* `docs/19` §4.5'teki `RulesEngine.unit_speed(unit_key) -> int  # yavaşlık faktörü` ile uyum:
  o değer yuvarlanmış "Mobility"dir (data: `speed.mobility`), **kesin** değer
  `Travel.unit_minutes_per_field()` ile alınır (`docs/05` §2 açıkça "detay sayfasındaki kesin değer"
  der). → `AÇIK SORU #10`

---

## 8. Üretilen köylerin başlangıç durumu

* **Tüm** köyler (bot + terkedilmiş + bonus) `docs/19` §3.1'deki **başlangıç** durumunda üretilir:
  `main, stone, wood, iron, farm, storage = 1`, diğer 11 bina 0; kaynaklar 1000/1000/1000;
  `units` = 11 anahtar, hepsi 0; `has_statue = false`.
* **Köy Puanı = 110** (`data/building-points.json` sv1: 20+20+20+20+20+10). Sabit kodda tutulur
  (determinizm), test **`GameData.points_for()` ile eşitliğini** doğrular.
* **Güç Alanı (`realm_of_power`) = 110** → NPC köyleri "tam güç alanıyla" başlar. Gerekçe: NPC'ler
  gelişmiş kabul edilir; `docs/19` §3.1 örneğinde de (`realm_of_power` 1000 > `points` 20) NPC
  değerleri köy puanından bağımsız verilmiştir. Oyuncu köyü ise `0` ile başlar
  (`docs/15` §5.3: güç alanı 0'dan büyür). → `AÇIK SORU #11`
* **Bot köyleri geliştirilmez** (hepsi sv1). Gelişmiş bir dünya isteniyorsa geliştirme
  **A-BOT** (FAZ 11) veya QA denge simülasyonu tarafından yapılmalıdır — bu modülün kapsamı
  "yeni dünya üretimi"dir.
* **Bot başına 1 köy** (100 bot = 100 köy). Çok köylü botlar (fetih sonrası) oyun akışıyla oluşur.
  → `AÇIK SORU #12`

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

1. **Mesafe yuvarlaması:** KingsAge yolculuk mesafesini 0,5'e yuvarlıyor mu (kesirli alan → süre)?
   Şu an **tam Öklid** kullanılıyor.
2. **`GameConfig.speed` yolculuğu etkiliyor mu?** Şu an **yalnızca `unit_speed`** bölüyor.
3. **Dönüş süresi:** gidiş ile aynı mı (yağma yükü hızı düşürür mü)? Şu an **2 × gidiş**.
4. **Kıta ölçeği:** 200×200 dünyada kıta 100×100 (4 kıta) mı, yoksa 10×10=100 kıta kalacak şekilde
   20×20 mi olmalı? `docs/10` §1 metni ile örneği de çelişiyor (K54 vs K55) — örnek esas alındı.
5. **Minimum köy mesafesi:** Kaynakta yok. Şu an yalnızca **aynı alan** yasak (1).
6. **Terkedilmiş/bonus köy oranları:** Şu an **1.0** ve **0.1**.
7. **Bonus köy çarpanı:** Şu an **1.25** (tek kaynak). Gerçek değer istemciden doğrulanmalı.
8. **Soyguncuların savunması:** `docs/19` §3.1'de soyguncu birimi olmadığı için `units` boş
   bırakıldı. Soyguncular nasıl temsil edilmeli (ayrı anahtar mı, sentetik `farmer` mı)?
9. **NPC koruma süreleri:** Üretici sistem saatini okumaz; `protection_until` = 0. NPC'ler için
   koruma isteniyor mu?
10. **`RulesEngine.unit_speed()` çıktısı** yuvarlanmış "Mobility" (int) mi, kesin alan/dakika (float) mı
    olacak? `docs/19` §6'daki `int` tipi ve §4.5 buna bağlı. Şu an kesin **float** değer kullanılıyor.
11. **`realm_of_power` başlangıç değeri:** NPC = köy puanı (110), oyuncu = 0. Doğru mu?
12. **Bot başına köy sayısı:** Şu an 1.
