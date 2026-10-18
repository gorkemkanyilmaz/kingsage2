# 15 — Matematik ve Formüller

> Bu doküman, yardım sitesindeki **ham tablolardan türetilmiş** eğrileri ve bilinen formülleri içerir.
> Tüm değerler `data/buildings.json`, `data/units.json`, `data/building-points.json` dosyalarından
> **doğrulanmıştır**. Kesin tablolar: [`reference/`](reference/).
>
> Terimler için: [`TERIMLER.md`](TERIMLER.md)

---

## 1. Bina Maliyet Büyümesi (geometrik)

Bina maliyetleri seviye başına **sabit bir çarpanla** artar:

```
maliyet(sv) = round( maliyet(sv=1) × faktör^(sv − 1) )
```

| Bina grubu | Odun | Taş | Demir |
|---|---:|---:|---:|
| **Standart** (Kale, Taş ocağı, Oduncu Kampı, Maden ocağı, Depo, Gizli Depo, Değirmen, Sur, Market, Katır çiftliği, Simyager) | **1,165** | **1,170** | **1,160** |
| **Kışla** | **1,21** | **1,23** | **1,22** |
| **Köşk** | **1,30** | **1,30** | **1,30** |
| **Kuyumcu** | **1,40** | **1,40** | **1,40** |
| **Anıt** | (tek seviye) | | |

> Simyager (garage) standart oranlara uyar (ölçülen: 1,1649 / 1,1702 / 1,1599).

### Başlangıç (Seviye 1) maliyetleri

| Bina | Odun | Taş | Demir | Vatandaş (sv / toplam) |
|---|---:|---:|---:|---:|
| Kale (`main`) | 70 | 85 | 65 | 2 / 2 |
| Taş ocağı (`stone`) | 30 | 40 | 55 | 5 / 5 |
| Oduncu Kampı (`wood`) | 30 | 55 | 40 | 5 / 5 |
| Maden ocağı (`iron`) | 40 | 55 | 30 | 5 / 5 |
| Depo (`storage`) | 40 | 43 | 35 | 0 / 0 |
| Gizli Depo (`hide`) | 40 | 50 | 40 | 1 / 1 |
| Değirmen (`farm`) | 50 | 65 | 50 | 0 / 0 |
| Kışla (`barracks`) | 180 | 180 | 120 | 6 / 6 |
| Sur (`wall`) | 40 | 60 | 30 | 4 / 4 |
| Market (`market`) | 80 | 100 | 70 | 10 / 10 |
| Katır çiftliği (`stable`) | 200 | 240 | 220 | 10 / 10 |
| Simyager (`garage`) | 600 | 400 | 500 | 50 / 50 |
| Köşk (`snob`) | 25.000 | 30.000 | 25.000 | 100 / 100 |
| Kuyumcu (`smith`) | 3.000 | 4.000 | 2.500 | 25 / 25 |
| Anıt (`statue`) | 400.000 | 400.000 | 400.000 | 0 / 0 |

---

## 2. Üretim Eğrileri

### 2.1 Hammadde üretimi (Oduncu Kampı / Taş ocağı / Maden ocağı)

Her üç bina **aynı eğriyi** kullanır:

```
üretim(sv) ≈ 120 × 1,115^(sv − 1)        [hammadde / saat]
```

| Sv | Üretim/saat | | Sv | Üretim/saat |
|---:|---:|---|---:|---:|
| 1 | 120 | | 30 | 2.815 |
| 2 | 134 | | 40 | 8.355 |
| 3 | 149 | | 45 | 14.395 |
| 5 | 185 | | 49 | 22.243 |
| 10 | 319 | | **50** | **24.800** |
| 20 | 948 | | | |

> **Not:** Yardım sitesi üretimin *vatandaş başına* mı yoksa *bina başına* mı olduğunu belirtmez;
> tabloda tek bir "Saatlik üretim" değeri vardır. (Açık soru — §7)

### 2.2 Depo (Warehouse) kapasitesi

```
kapasite(sv) ≈ 1.000 × 1,150^(sv − 1)
```

| Sv | 1 | 5 | 10 | 20 | 30 | 50 |
|---:|---:|---:|---:|---:|---:|---:|
| Kapasite | 1.000 | 1.750 | 3.523 | 14.277 | 57.853 | **950.000** |

### 2.3 Gizli Depo (Hideout) kapasitesi

```
kapasite(sv) ≈ 150 × 1,19^(sv − 1)        (maks. sv 30)
```

| Sv | 1 | 5 | 10 | 20 | 30 |
|---:|---:|---:|---:|---:|---:|
| Kapasite | 150 | 301 | 718 | 4.088 | **23.278** |

### 2.4 Değirmen — Maksimum vatandaş

```
maksVatandaş(sv) ≈ 250 × 1,115^(sv − 1)
```

| Sv | 1 | 5 | 10 | 20 | 30 | 50 |
|---:|---:|---:|---:|---:|---:|---:|
| Maks. vatandaş | 250 | 385 | 662 | 1.951 | 5.751 | **50.000** |

---

## 3. Sur Bonusu (Savunma Takviyesi)

Sur'un son sütunu **"Savunma üniteleri için takviye"** (duvar bonusu). Savunma değeri bu yüzdeyle çarpılır.

| Sv | 1 | 2 | 3 | 5 | 10 | 20 |
|---:|---:|---:|---:|---:|---:|---:|
| Bonus | 105% | 109% | 114% | 123% | 149% | **220%** |

> EN ve TR kaynakları **aynı** değerleri verir (sv1 = 105%).

---

## 4. Zaman Faktörü ve İnşaat Süreleri ⚠️

Bazı binaların son sütunu **"Zaman faktörü"**'dür (Kale, Kışla, Simyager, Köşk).
Bu değer seviye arttıkça **düşer** — büyük olasılıkla **o seviyenin inşaat süresinin bir katsayısı**.

### Kale (`main`) zaman faktörü (sv1→50)
`100% 96% 93% 89% 86% 82% 79% 76% 73% 71% 68% 65% 63% 60% 58% 56% 54% 52% 50% 48%
46% 44% 43% 41% 39% 38% 37% 35% 34% 33% 31% 30% 29% 28% 27% 26% 25% 24% 23% 22%
21% 20% 20% 19% 18% 18% 17% 16% 16% 15%`

### Kışla (`barracks`) zaman faktörü (sv1→30)
`80% 74% 69% 65% 60% 56% 52% 48% 45% 42% 39% 36% 34% 31% 29% 27% 25% 24% 22% 20%
19% 18% 17% 15% 14% 13% 12% 12% 11% 10%`

> ⚠️ **AÇIK SORU:** Bu katsayının **neyle çarpıldığı** (temel süre) yardım sitesinde **yok**.
> İnşaat süresi formülü **oyun istemcisinden** doğrulanmalıdır. (Bkz. §7)
> Aynı sorun **araştırma/eğitim süresi** ve **Market/katır** için de geçerlidir.

### İnşaat kuyruğu ek maliyeti (bilgi amaçlı)
Aynı anda 3 iş ücretsizdir; sonrasında **hammadde ek maliyeti** uygulanır:

| Sıradaki iş | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Ek maliyet | 0 | 0 | 0 | +25% | +56% | +95% | +144% | +205% | +281% | +376% |

---

## 5. Puanlar ve Güç Alanı

### 5.1 Köy Puanı
- **Kümülatif:** `puan(sv) = bina_temel_puanı × sv` biçiminde doğrusal artar.
  (Örn. Kale: sv1 = 20, sv2 = 40, sv3 = 60 … sv50 = 1.000)
- **Köy Puanı = tüm binaların o seviyedeki kümülatif puanları toplamı.**
- **Tam gelişmiş köy = 10.000 puan.**

| Bina | Maks. sv | O seviyedeki puan |
|---|---:|---:|
| Kale, Taş ocağı, Oduncu Kampı, Maden ocağı, Depo | 50 | 1.000 (her biri) |
| Köşk | 10 | 1.000 |
| Anıt | 1 | 1.000 |
| Kışla, Market | 30 | 600 |
| Değirmen | 50 | 500 |
| Sur | 20 | 400 |
| Gizli Depo, Katır çiftliği | 30 | 300 |
| Kuyumcu | 5 | 200 |
| Simyager | 5 | 100 |
| **TOPLAM** | | **10.000** |

> Tam tablo: [`reference/puan-tablosu.md`](reference/puan-tablosu.md)

### 5.2 Toplam Puan
```
Toplam Puan = Σ(köy puanları) + 2.500 × (köy sayısı − 1)
```

### 5.3 Güç Alanı (Realm of Power)
- Her köyün güç alanı **0 … köy puanı** arasındadır.
- **Saatte** köy puanının **%1'i** kadar artar (0'dan köy puanına doğru).
- Saldırı sonucu **düşer** (fetih saldırıları).
- **Yabancı Kont** ile düşüş: **2.250 – 2.750** (Anıt varsa **1.750 – 2.250**).
- **0'a ulaşınca köy fethedilir.**

---

## 6. Savaş Değişkenleri

### 6.1 Moral (Morale)
- Güç oranına göre uygulanır; **%30 … %100** aralığında.
- Puanı düşük saldıran → moral **100%'e yakın**; çok güçlü saldıran → **düşer**.
- Etki: saldıranın **saldırı değerine** çarpan olarak uygulanır.
- ⚠️ **Eğri kesin değil** — açık soru (§7).

### 6.2 Şans (Luck)
- Her savaşta **rastgele −%25 … +%25**.

### 6.3 Sur Bonusu
- Savunmanın **%105 … %220** ile çarpımı (bkz. §3).

### 6.4 Gece Bonusu
- **Sunucu ayarı.** Aktifse gece saatlerinde **tüm birliklerin savunma gücü ×2**.
- EN Dünya 59: **kapalı**. TR dünya: **aktif (00:00 – 06:00)**.

### 6.5 Saldırı → savunma karşılaştırması
```
toplam_saldırı  = Σ(birim.saldırı × adet) × moral × şans × gece_yok
toplam_savunma  = Σ(birim.savunma_türü × adet) × sur_bonusu × gece_bonusu
```
Kayıplar bu iki değerin **oranına** göre iki tarafa dağıtılır.

---

## 7. ⚠️ Açık Sorular (yardım sitesinde yok → istemciden/deneyden doğrulanacak)

| # | Konu | Durum |
|---|---|---|
| 1 | **İnşaat süresi** formülü (zaman faktörünün çarpıldığı temel süre) | ❔ |
| 2 | **Araştırma süresi** formülü (Kışla seviyesi katsayısı) | ❔ |
| 3 | **Eğitim süresi** formülü | ❔ |
| 4 | **Market / katır** üretim & kapasite eğrisi | ❔ |
| 5 | **Simyager teknik listesi** (ad, maliyet, süre, etki) | ❔ |
| 6 | **Altın zırh** maliyet artış çarpanı | ❔ |
| 7 | **Moral eğrisi** (puan oranı → moral yüzdesi) | ❔ |
| 8 | **Casusluk "hayatta kalan casus"** formülü | ❔ |
| 9 | **Şahmerdan / Mancınık hasar** formülleri | ❔ |
| 10 | Üretimin **vatandaş başına** mı **bina başına** mı olduğu | ❔ |
| 11 | **Fetih düşüşü** kesin formülü (güç alanı – Kont sayısı) | kısmen |
| 12 | **Kanun Kaçağı** sınırının kesin hesabı | kısmen |

---

## 8. Doğrulama Notları

- Tüm eğriler **15 bina × tam seviye tablosu** ile karşılaştırılarak türetildi.
- Yuvarlama hataları nedeniyle düşük seviyelerde oranlar ±0,01 sapabilir;
  **yüksek seviyelerde** (sv ≥ 20) eğriler çok kararlıdır.
- **Kesin değerler için her zaman `reference/` tabloları esas alınmalıdır**;
  formüller yalnızca modelleme/kestirim içindir.
