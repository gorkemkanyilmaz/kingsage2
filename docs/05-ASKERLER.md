# 05 — Askerler (Birimler)

> **Her birim için tam sayfa:** [`reference/units/`](reference/units/)
> **Yapısal veri:** [`../data/units.json`](../data/units.json)

## 1. Genel Kurallar

- Birimler **araştırılır (research)** ve **eğitilir (train)**; her ikisi de **kaynak + nüfus** ister.
- **Araştırma** Kışla'da yapılır ve ön koşulları (Kışla seviyesi) vardır.
- **Eğitim** araştırma tamamlandıktan sonra Kışla'da yapılır.
- **Araştırma ve eğitim süresi, Kışla seviyesi arttıkça azalır.**
- **Bakım maliyeti yoktur**; ancak birim sayısı **mevcut nüfusla** sınırlıdır.
- Birimler **sırayla** eğitilir; karışık tipler tek listeye konabilir.
- **Kont istisnadır:** araştırılmaz, **Köşk'ta** eğitilir ve **Altın Zırh** gerektirir;
  eğitim süresi **Köşk** seviyesine bağlıdır.

### Askerden çıkarma (Dismiss)
Eğitilmiş birimler Kışla'daki "Dismiss" ile **dağıtılabilir**:
- **Kaynak iadesi YOK**,
- **bağlı nüfus serbest kalır**.

### Saldırı için minimum birim sayısı
> **World settings:** `Minimum units needed for attacking = 3 × Barracks level`
> Yani bir saldırı başlatmak için en az **3 × Kışla seviyesi** kadar birim gerekir.

---

## 2. Birim Tablosu — Eğitim Maliyeti, Hız ve Muharebe Değerleri

| Birim | Anahtar | Odun | Taş | Demir | Vatandaş | Hız (dk/alan) | Taşıma | Saldırı | Sav. Piyade | Sav. Süvari | Sav. Okçu | Araştırma için |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|---|
| Köy Koruyucusu | `farmer` | 10 | 3 | 7 | 1 | 5.0 | 5 | 20 | 40 | 30 | 5 | Kışla Lv1 |
| Silahtar | `spear` | 20 | 10 | 30 | 1 | 4.5 | 25 | 50 | 100 | 200 | 300 | Kışla Lv1 |
| Muhafız | `sword` | 10 | 30 | 80 | 1 | 5.5 | 15 | 100 | 300 | 100 | 200 | Kışla Lv1 |
| Baltacı | `axe` | 50 | 40 | 50 | 1 | 4.5 | 10 | 350 | 70 | 50 | 50 | Kışla Lv2 |
| Okçu | `bow` | 160 | 80 | 80 | 1 | 4.5 | 10 | 150 | 400 | 150 | 100 | Kışla Lv5 |
| Casus | `spy` | 60 | 40 | 60 | 2 | 2.25 | 0 | 1 | 10 | 5 | 7 | Kışla Lv4 |
| Akıncı | `light` | 100 | 100 | 300 | 4 | 2.5 | 80 | 900 | 200 | 300 | 300 | Kışla Lv7 |
| Kara Şövalye | `heavy` | 300 | 100 | 500 | 6 | 2.75 | 50 | 600 | 1500 | 1000 | 1000 | Kışla Lv16 |
| Şahmerdan | `ram` | 500 | 100 | 200 | 5 | 7.5 | 0 | 100 | 100 | 200 | 20 | Kışla Lv20 |
| Mancınık | `kata` | 600 | 200 | 200 | 8 | 7.5 | 0 | 500 | 400 | 100 | 200 | Kışla Lv25 |
| Kont | `snob` | 120000 | 100000 | 80000 | 100 | 8.75 | 0 | 100 | 300 | 100 | 200 | Köşk + Altın Zırh |

**Sütun açıklamaları**
- **Taşıma (Carry booty):** birimin yağmada taşıyabileceği kaynak miktarı.
- **Hız:** **alan başına dakika** (düşük = hızlı). Genel tablodaki yuvarlanmış "Mobility" yerine
  **detay sayfasındaki kesin değer** kullanılmalıdır.
- **Savunma** üç ayrı türe karşı ayrı değerlendirilir: **piyade / süvari / okçu**.

### Birim sınıfları (proje içi gruplama — resmî değil)
| Sınıf | Birimler |
|---|---|
| Piyade | Köy Koruyucusu, Silahtar, Muhafız, Baltacı |
| Okçu sınıfı | Okçu |
| Süvari | Akıncı, Kara Şövalye |
| Kuşatma | Şahmerdan, Mancınık |
| Özel | Casus, Kont |

---

## 3. Araştırma (Research) Tablosu

| Birim | Wood | Stone | Iron | Süre (Kışla etkisi hariç) |
|---|--:|--:|--:|---|
| Köy Koruyucusu | 10 | 10 | 10 | 0:00:10 |
| Silahtar | 20 | 20 | 30 | 0:01:00 |
| Muhafız | 40 | 40 | 60 | 0:02:00 |
| Baltacı | 500 | 720 | 630 | 1:18:40 |
| Okçu | 570 | 480 | 630 | 2:21:36 |
| Casus | 630 | 570 | 610 | 1:25:30 |
| Akıncı | 1.800 | 2.100 | 2.400 | 2:33:54 |
| Kara Şövalye | 3.600 | 3.500 | 3.700 | 4:37:01 |
| Şahmerdan | 1.400 | 1.800 | 1.200 | 1:48:20 |
| Mancınık | 2.500 | 3.000 | 1.600 | 3:36:40 |

> **Kont araştırılmaz.** Süreler **Kışla seviyesiyle azalır** (katsayı yardım sitesinde yok).

---

## 4. Eğitim Süreleri

| Birim | Süre (Kışla etkisi hariç) |
|---|---|
| Köy Koruyucusu | 0:00:14 |
| Silahtar | 0:00:53 |
| Muhafız | 0:01:08 |
| Baltacı | 0:01:00 |
| Okçu | 0:01:15 |
| Casus | 0:02:15 |
| Akıncı | 0:05:15 |
| Kara Şövalye | 0:07:30 |
| Şahmerdan | 0:17:30 |
| Mancınık | 0:25:00 |
| **Kont** | **2:30:00** (Köşk seviyesine bağlı) |

---

## 5. Birim Rolleri (özet)

| Birim | Rol |
|---|---|
| Köy Koruyucusu | Ucuz, zayıf; erken oyun ve dolgu |
| Silahtar | Ucuz, dengeli savunma; **okçu savunması güçlü** (300) |
| Muhafız | **Piyade savunması güçlü** (300); dengeli |
| Baltacı | **Yüksek saldırı** (350), zayıf savunma; saldırı birimi |
| Okçu | **Savunmada çok yönlü** (400/150/100); saldırıda orta |
| Casus | Casusluk; savaşma yeteneği yok denecek kadar az |
| Akıncı | **Hızlı + güçlü saldırı** (900), iyi ganimet kapasitesi (80) |
| Kara Şövalye | **En güçlü savunma** (1500/1000/1000) + güçlü saldırı (600) |
| Şahmerdan | Muharebe öncesi **duvar hasarı**; savaş gücü düşük |
| Mancınık | Muharebe sonrası **bina hasarı**; savaş gücü orta |
| Kont | **Fetih**; yerleşimin "realm of power"ını düşürür |
