# ASSUMPTIONS — Savaş Simülatörü (A-SAVAS)

> Bu dosya, **yardım sitesinde bulunmayan** (`game/data/rules/battle.json` içinde
> `"known": false`) savaş formülleri için seçilen **tek bir sabit/formülü** ve
> gerekçesini belgeler (docs/19 §2.5 zorunluluğu).
>
> **Kural:** Bilinmeyen formüller **uydurulmaz**; her biri için tek ve açıkça
> belgelenmiş bir model seçilir, kodda sabit olarak tutulur ve tümü
> `AÇIK SORU:` olarak işaretlenir. Bu değerler oyun istemcisinden doğrulanınca
> yalnızca ilgili sabit değiştirilerek güncellenir.

İlgili bilinmeyen alanlar (battle.json):
`morale.known=false`, `loss_distribution.known=false`, `spy.survivor_formula.known=false`,
`siege.ram_wall_damage.known=false`, `siege.kata_building_damage.known=false`,
`_phase_formula_status.unknown_phases = [wall_damage, spy_attack, normal_battle, building_damage]`.

---

## 1. Şahmerdan sur hasarı — `siege.ram_wall_damage` (`known:false`)

**Seçilen formül** (`BattleSimulator.RAM_WALL_DAMAGE_FACTOR = 2.0`):

```
hasar% = min(100, 100 × ram / (ram + sur_sv × 2))
etkin_sur = round_half_up(sur_sv × (1 − hasar% / 100))     # 0..20'ye kırpılır
```

**Gerekçe:** Doküman yalnızca "duvar, taşınan koçbaşı sayısına göre düşer" der
(docs/06 §Faz 1). Azalan verim + kalın surda daha az hasar davranışı gerçekçi ve
**monoton**tur: ram sayısı artınca hasar artar, sur seviyesi artınca azalır;
ram = 0 → hasar yok; sur = 0 → %100. Tek parametre ile ayarlanabilir.

`AÇIK SORU:` Şahmerdan başına sur hasarının gerçek eğrisi (ram/sur oranı → düşen
seviye) bilinmiyor.

## 2. Mancınık bina hasarı — `siege.kata_building_damage` (`known:false`)

**Seçilen formül** (`KATA_LEVELS_PER_KATA = 1.0`):

```
yıkılan_seviye = round_half_up(kata_hayatta × 1.0 × savunan_kayıp_oranı)
```

Yıkım sırası **deterministik**: en yüksek seviyeli bina önce, eşitlikte anahtar
adı (A→Z); **Sur hariç** (Faz 1'de ele alınır). Yalnızca **saldıran kazanırsa**
uygulanır.

**Gerekçe:** Doküman "savunanın kayıpları **+** saldıranın mancınık sayısına
bağlıdır" der (docs/06 §Faz 4). Model bu iki etkeni çarpan olarak birleştirir:
savunan ezilmedikçe (kayıp oranı küçük) bina hasarı da küçük kalır; mancınık
arttıkça yıkım artar. `AÇIK SORU:` Mancınık başına yıkılan seviye/puan.

## 3. Moral eğrisi — `morale` (`known:false`)

**Seçilen formül** (`MORALE_CURVE_SLOPE = 0.1`, sınırlar %30–%100):

```
if saldıran_puan ≤ savunan_puan: morale = 1.0
else: morale = clamp(1.0 − 0.1 × (saldıran_puan / savunan_puan − 1), 0.3, 1.0)
```

**Gerekçe:** Doküman yalnızca aralığı (%30–%100) ve yönü ("saldıran daha
güçlüyse morali düşer") verir (docs/06 §2). Doğrusal eğri en basit ve monoton
seçimdir; oran 8'de taban %30'a oturur (aşırı güçlü oyuncunun ezmesini engelleme
amacına uygun). `AÇIK SORU:` puan oranı → moral yüzdesi gerçek eğrisi.

## 4. Kayıp dağıtım eğrisi — `loss_distribution` (`known:false`)

**Seçilen formül** (KingsAge kuralları: kaybeden tarafın muharip birlikleri tamamen yok olur):

```
saldırı_değeri = Σ(saldırı × adet) × moral × (1 + şans)
savunma_değeri = Σ(ağırlıklı_savunma × adet) × sur_bonusu × anıt_bonusu × gece_bonusu
if saldırı_değeri > savunma_değeri:
    saldıran_kayıp_oranı = clamp((savunma_değeri / saldırı_değeri) ** 1.5, 0, 1)
    savunan_kayıp_oranı  = 1.0
else:
    saldıran_kayıp_oranı = 1.0
    savunan_kayıp_oranı  = clamp((saldırı_değeri / savunma_değeri) ** 1.5, 0, 1)
kayıp(birim) = round_half_up(adet × oran)        # int, 0..adet
```

**Savunma ağırlıklandırması:** Saldıranın sınıf bazlı saldırı payı (`infantry` /
`cavalry` / `archer`) kullanılır; her savunan birimin üç savunma değeri bu
paylarla ağırlıklı toplanır (piyade + kuşatma + özel → piyade savunması).
Böylece "1000 Akıncı vs 10 Silahtar" gibi süvari saldırıları savunanın **süvari
savunmasına** çarpar.

**Gerekçe:** battle.json saldırı/savunma **toplam formüllerini** verir ama
bunlardan kayıp dağıtım eğrisini vermez. "Toplam güçteki pay" dağıtımı simetrik,
monoton ve kilit özellikleri sağlar: (a) güçlü ordu kazanır, (b) sur/gece/gece/Anıt
artışı savunan kaybını azaltır, (c) oranlar 0–1 arasında kalır.
`AÇIK SORU:` Gerçek kayıp dağıtım eğrisi (muhtemelen doğrusal değil).

## 5. Casus sağkalımı — `spy.survivor_formula` (`known:false`)

**Seçilen formül:**

```
hayatta_kalan = round_half_up(saldıran_casus × saldıran_casus / (saldıran_casus + savunan_casus))
```

**Gerekçe:** Doküman "saldıran/kavunan casus oranından hayatta kalan casus
sayısı bulunur" der (docs/07 §3) ve **savunan casus kaybetmez**. Oran-temelli
sağkalım bu tanımı birebir yansıtır; savunan casus yoksa hepsi döner.
Casuslar Faz 2'den sonra normal asker savaşına katılmaz (işini yapıp döner).
`AÇIK SORU:` Gerçek "hayatta kalan casus" formülü.

---

## 6. Doğrulanmış (bilinen) değerler

Bunlar formül değil, `known:true` verilerdir ve dosyalardan okunur:

- **Sur bonusu:** `production.json#tables.wall_defence_bonus_percent` (sv0 %100 → sv20 %220).
- **Şans:** ±%25, her muharebede `RandomNumberGenerator` ile (`luck.min/max`).
- **Gece bonusu:** savunma ×2 (`night_bonus.multiplier`), `options.night` ile açılır.
- **Anıt:** tahkimat +%50 (`memorial.fortification_bonus`); ayrıca Kont düşüşü
  2250–2750 → **1750–2250** (`realm_of_power.loss_foreign_count[_memorial]`).
- **Gizli Depo kapasitesi:** `production.json#tables.hideout_capacity`.
- **Fetih kapağı:** saldırı başına en fazla `max_village_points / 2` = 5000;
  fetih sonrası Güç Alanı maksimumun %30'u.
- **Min. saldırı birimi:** 3 × Kışla seviyesi (`min_attack_units`).
- **Kont ölüm koşulu:** başka birlik kalmamışsa (ve muharebe olduysa) **veya**
  saldıran birimlerinin %50'si öldüyse.

---

## 7. Determinizm ve tamsayı kuralları (docs/19 §2)

- Tüm rastgelelik **yalnızca** `options.seed` ile tohumlanan `RandomNumberGenerator`'dan
  gelir. **Global `randi()` kullanılmaz.** Aynı girdi + aynı seed → **aynı sonuç**.
- Kayıplar, ganimet, hasar ve Güç Alanı düşüşü **int**; oranlar/moral/şans/sur hasarı **float**.
- Yuvarlama `round_half_up` (`int(floor(x + 0.5))`).
- Sözlük döngüleri deterministik olması için **sıralı anahtar** üzerinden yapılır.

## 8. Tüm AÇIK SORULAR (özet)

1. `AÇIK SORU:` Şahmerdan duvar hasarı eğrisi (ram/sur oranı → düşen seviye).
2. `AÇIK SORU:` Mancınık bina hasarı formülü (kayıp + mancınık → yıkılan seviye/puan).
3. `AÇIK SORU:` Moral eğrisi (puan oranı → moral yüzdesi).
4. `AÇIK SORU:` Kayıp dağıtım eğrisi (saldırı/savunma oranı → iki taraf kaybı).
5. `AÇIK SORU:` Casus sağkalım formülü.
6. `AÇIK SORU:` Savunanın hangi savunma türünün (piyade/süvari/okçu) ne zaman
   kullanıldığı — ağırlıklı sınıf modeli seçildi.
