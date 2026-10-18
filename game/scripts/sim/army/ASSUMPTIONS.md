# ASSUMPTIONS — Ordu: Araştırma / Eğitim / Altın Zırh (A-ORDU)

> **Sahip:** A-ORDU · **Kapsam:** `game/scripts/sim/army/**`
> **Kural (docs/19 §2.5):** Bilinmeyen formüller **uydurulmaz**. Her bilinmeyen için
> **tek bir sabit** seçilir, kodda sabit olarak tutulur ve burada gerekçesiyle
> belgelenir. Doğrulanınca **yalnızca ilgili sabit** değiştirilir.
>
> Süre formüllerinin **bilinen** kısmı `RulesEngine`'dedir (bkz.
> `game/scripts/rules/ASSUMPTIONS.md` #2, #3); bu dosya yalnızca **A-ORDU'ya özgü**
> bilinmeyenleri ve seçilen modeli belgeler.

İlgili `known:false` / belirsiz kaynaklar:
`time-factors.json#unresolved.research_time_formula`,
`time-factors.json#unresolved.training_time_formula`,
`time-factors.json#time_factor_column.garage.known:false` (Altın Zırh çarpanı),
`docs/00 §5` (Altın zırh maliyet artışı), `docs/04 §Goldsmith`.

---

## 1. Araştırma süresi — Kışla katsayısı (`research_time_formula`)

**Çözüm (A-MOTOR'a devredildi, burada tekrar uydurulmaz):**

```
research_seconds(village, unit) =
    RulesEngine.research_seconds(unit, mevcut_Kışla_seviyesi)
  = base_time_seconds(unit) × (Kışla_zaman_faktörü(Kışla_lv) / 100) / speed
```

Birim başına **temel süre** `rules/units.json → research.base_time_seconds` içinde
**bilinir**; yalnızca **Kışla katsayısı** bilinmiyordu → `RulesEngine` #2 varsayımı
kullanılır. `AÇIK SORU:` Araştırma süresinin Kışla seviyesiyle kesin birleşimi.

## 2. Eğitim süresi — Kışla/Köşk katsayısı (`training_time_formula`)

```
training_seconds(village, unit, count) =
    RulesEngine.training_seconds(unit, count, ilgili_bina_seviyesi)
  = base_time_seconds(unit) × count × (bina_zaman_faktörü(lv) / 100) / speed
```

- İlgili bina: `training.building` (`barracks`; Kont için `snob` → **Köşk**).
- `RulesEngine` #3 varsayımı kullanılır. `AÇIK SORU:` Eğitim süresinin bina
  seviyesiyle ve adetle kesin birleşimi.

## 3. Altın Zırh (Kuyumcu) maliyeti ve artışı (`known:false`)

Kaynaklar yalnızca **"her yeni Altın Zırh setinde maliyet artar"** der
(`docs/04 §Goldsmith`, `docs/08 §3`, `docs/00 §5`); **temel maliyet** ve **artış
çarpanı** hiçbir yerde **yoktur**.

**Seçilen tek sabitler** (`GoldArmour.gd`):

```gdscript
const COST        := {"wood": 12000, "stone": 10000, "iron": 8000}  # ≈ Kont maliyetinin %10'u
const COST_GROWTH := 1.0                                            # artış bilinmiyor → nötr (artış yok)
const PRODUCTION_SECONDS := 0                                       # üretim süresi bilinmiyor → anlık
```

- `COST`, Kont eğitim maliyetinin (120.000/100.000/80.000) **%10'u** olarak
  seçildi: ölçek olarak makul ve **tek sabit**tir; doğrulanınca değiştirilir.
- `COST_GROWTH = 1.0` → "artış var" bilgisi **sayısal olarak bilinmediğinden**
  modellenmez; kod `pow(COST_GROWTH, üretilen_set)` biçiminde yazıldı, böylece
  çarpan doğrulanınca **tek sabit** değişir.
- `AÇIK SORU:` Altın Zırh temel maliyeti, set başına artış çarpanı ve üretim süresi.

## 4. Altın Zırh ve Kont eğitimi ilişkisi

- Kont **araştırılmaz** (`RulesEngine.research_requirement("snob") == 0`).
- Kont **Köşk**'te (`snob` ≥ 1) eğitilir ve **her Kont için 1 Altın Zırh seti**
  tüketilir; set **eğitim başlarken** düşülür, **iptalde iade edilir**.
- `AÇIK SORU:` Kont başına gereken set sayısı (1 kabul edildi) ve Altın Zırh'ın
  Kont üretimine etkisinin kesin biçimi.

## 5. Araştırma/eğitim eşzamanlılığı

- **Kışla'da aynı anda tek araştırma** yapılabilir (`Research.has_pending`);
  yeni araştırma başlamadan önce bekleyen araştırma kontrol edilir.
- **Eğitim** ayrı ve **sıralı** bir kuyruktur; araştırmayı **bloklamaz**.
- `AÇIK SORU:` KingsAge'de araştırma ve eğitimin aynı kuyruğu paylaşıp paylaşmadığı
  ve aynı anda yapılıp yapılamadığı doğrulanmadı.

## 6. Vatandaş muhasebesi — ordu + rezerve (`settlers_reserved`)

`VillageModel.population_used` yalnızca **bina** vatandaşını sayar
(`workersTotal`). Ordu vatandaşı ve henüz tamamlanmamış eğitimin **rezerve**
ettiği vatandaş ayrıca düşülmelidir:

```
boş = max_population(Değirmen) − population_used(bina) − army_settlers(birimler) − settlers_reserved
```

- Eğitim **başlarken** `count × settlers` kadar vatandaş `village.settlers_reserved`
  alanına **rezerve** edilir (yetersizse eğitim **reddedilir**).
- Eğitim **tamamlanınca** rezerv çözülür ve birimler eklenir (net vatandaş sabit).
- **İptalde** rezerv çözülür → vatandaş **geri gelir** (docs/05 §1).
- `village.settlers_reserved` **türetilmiş** bir alandır (docs/19 §3.1'e ek); köy
  sözlüğü serbest şema olduğu için `GameState.to_dict()/from_dict()` etkilenmez.
- `AÇIK SORU:` Vatandaşın eğitim başında mı yoksa bitişinde mi bağlandığı — burada
  **başında rezerve** edilir (iptal iadesi bunu gerektirir).

## 7. `army_capacity` tanımı

`ArmyAPI.army_capacity(village)` = **ordunun kullanabileceği kalan boş vatandaş**
(§6 formülü, ≥ 0'a kırpılır). KingsAge arayüzünde ayrı bir "ordu kapasitesi"
göstergesi tanımlı olmadığından bu anlam seçildi. `AÇIK SORU:` Terimin oyundaki
kesin karşılığı.

## 8. İptal (cancel) davranışı

- Devam eden **eğitim** iptalinde: **vatandaş** ve **Altın Zırh** iade edilir;
  **hammadde iade EDİLMEZ** (`Training.cancel`).
- Devam eden **araştırma** iptalinde: yalnızca kuyruk öğesi kaldırılır (bedel iadesi yok).
- Bu, `docs/05 §1`'deki **dismiss** kuralıyla ("kaynak iadesi YOK") tutarlıdır.
- `AÇIK SORU:` İptalde hammadde iadesinin olup olmadığı.

## 9. Bonus köy eğitim hızlandırması

- `village.bonus_type == "training"` → eğitim süresi **%10 kısalır** → **×0.90**
  (`Training.TRAINING_BONUS_FACTOR`; docs/19 §3.1). Yalnızca **eğitimi** etkiler,
  araştırmayı etkilemez. Economicsiz çalışsın diye doğrudan **köy sözlüğünden** okunur.

## 10. Kuyruk zamanlaması

- Kuyruk öğesi `finish_unix = now_unix + ceil(süre)` (en az 1 sn) ile yazılır.
- `ArmySimulator.process_tick` öğeyi `now_unix ≥ finish_unix` olunca tamamlar.
- Determinizm: tüm sayaçlar **int**; kuyruk kimlikleri `max(id)+1` (deterministik);
  global `randi()` **yok**.

---

## Tüm AÇIK SORULAR (özet)

1. `AÇIK SORU:` Araştırma süresinin Kışla seviyesiyle kesin birleşimi (§1).
2. `AÇIK SORU:` Eğitim süresinin bina seviyesi + adetle kesin birleşimi (§2).
3. `AÇIK SORU:` **Altın Zırh** temel maliyeti, set başına **artış çarpanı** ve
   **üretim süresi** (§3) — üçü de bilinmiyor; tek sabit + nötr artış seçildi.
4. `AÇIK SORU:` Kont başına Altın Zırh seti sayısı ve etkisinin biçimi (§4).
5. `AÇIK SORU:` Araştırma ve eğitimin aynı kuyruğu paylaşıp paylaşmadığı (§5).
6. `AÇIK SORU:` Vatandaşın eğitim başında/bitişinde bağlanması (§6).
7. `AÇIK SORU:` "Ordu kapasitesi" kavramının oyundaki kesin karşılığı (§7).
8. `AÇIK SORU:` İptalde hammadde iadesinin olup olmadığı (§8).
