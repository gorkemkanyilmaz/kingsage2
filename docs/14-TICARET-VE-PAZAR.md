# 14 — Ticaret ve Market

Kaynak: `player_trade`, `buildings_details_market`, `buildings_details_stable` (EN + TR)

> Terimler: **Market**, **Katır çiftliği**, **Katır**, **Hammaddeler**. Bkz. [`TERIMLER.md`](TERIMLER.md)

---

## 1. Genel Kural

- Oyuncular **birbirleriyle hammadde takas edebilir**.
- **Market** binası **zorunludur**.
- **Katır çiftliği** zorunlu **değildir**; ancak **çok ticaret yapan** oyuncular için **çok önemlidir**
  (ticaretin *büyüklüğünü* belirler).

---

## 2. Katırlar

- Ticaret için oyuncunun **katıra** ihtiyacı vardır.
- **Her katırın taşıyabileceği belirli bir hammadde kapasitesi** vardır.
- **Katır hedefe ulaştığında geri dönmez** → **yeniden üretilmesi** gerekir.
- Katır köyden **ayrıldığı an** yenisinin üretimi **başlar**.
- **Katır çiftliği seviyesi ↑ → katır sayısı üretimi ↑** (çiftlik maksimum seviyeye ulaşana kadar).
- **Market seviyesi → tutulabilecek maksimum katır sayısını (kapasite)** belirler.

```
üretim    → Katır çiftliği seviyesi ("Saatlik üretim")
kapasite  → Market seviyesi ("Katır miktarı")
```

---

## 3. Market (`market`)

- **Maksimum seviye:** 30
- **Gerekli:** Depo (`storage`) **Seviye 5**
- **Son sütun:** *Katır miktarı* (tutulabilecek maksimum katır)

| Sv | Taş | Odun | Demir | Vatandaş (sv/toplam) | Katır miktarı |
|---:|---:|---:|---:|---:|---:|
| 1 | 100 | 80 | 70 | 10 / 10 | 1 |
| 2 | 117 | 93 | 81 | 2 / 12 | 2 |
| 3 | 137 | 109 | 94 | 2 / 14 | 3 |
| 4 | 160 | 126 | 109 | 2 / 16 | 4 |
| 5 | 187 | 147 | 127 | 3 / 19 | 5 |
| 6 | 219 | 172 | 147 | 3 / 22 | 6 |
| 7 | 257 | 200 | 171 | 4 / 26 | 7 |
| 8 | 300 | 233 | 198 | 4 / 30 | 8 |
| 9 | 351 | 271 | 229 | 5 / 35 | 9 |
| 10 | 411 | 316 | 266 | 6 / 41 | 10 |
| 11 | 481 | 368 | 309 | 7 / 48 | 12 |
| 12 | 562 | 429 | 358 | 8 / 56 | 15 |
| 13 | 658 | 500 | 416 | 10 / 66 | 18 |
| 14 | 770 | 583 | 482 | 11 / 77 | 23 |
| 15 | 901 | 679 | 559 | 13 / 90 | 28 |
| 16 | 1.054 | 791 | 649 | 15 / 105 | 34 |
| 17 | 1.233 | 921 | 752 | 18 / 123 | 42 |
| 18 | 1.443 | 1.073 | 873 | 21 / 144 | 51 |
| 19 | 1.688 | 1.250 | 1.012 | 25 / 169 | 63 |
| 20 | 1.975 | 1.456 | 1.174 | 28 / 197 | 77 |
| 21 | 2.311 | 1.697 | 1.362 | 34 / 231 | 95 |
| 22 | 2.703 | 1.977 | 1.580 | 39 / 270 | 117 |
| 23 | 3.163 | 2.303 | 1.833 | 46 / 316 | 143 |
| 24 | 3.701 | 2.683 | 2.126 | 54 / 370 | 176 |
| 25 | 4.330 | 3.125 | 2.467 | 63 / 433 | 216 |
| 26 | 5.066 | 3.641 | 2.861 | 74 / 507 | 265 |
| 27 | 5.927 | 4.242 | 3.319 | 86 / 593 | 325 |
| 28 | 6.935 | 4.942 | 3.850 | 100 / 693 | 398 |
| 29 | 8.113 | 5.757 | 4.466 | 118 / 811 | 489 |
| 30 | 9.493 | 6.707 | 5.181 | 138 / 949 | **600** |

> Market ayrıca **depolama alanı** sağlar ("daha fazla eşya depolayabilirsin").

---

## 4. Katır çiftliği (`stable`)

- **Maksimum seviye:** 30
- **Gerekli:** Market (`market`) **Seviye 1**
- **Son sütun:** *Saatlik üretim* = **katır üretimi / saat**

| Sv | Taş | Odun | Demir | Vatandaş (sv/toplam) | Katır/saat |
|---:|---:|---:|---:|---:|---:|
| 1 | 240 | 200 | 220 | 10 / 10 | 16 |
| 2 | 281 | 233 | 255 | 1 / 11 | 19 |
| 3 | 329 | 271 | 296 | 1 / 12 | 22 |
| 4 | 384 | 316 | 343 | 1 / 13 | 26 |
| 5 | 450 | 368 | 398 | 2 / 15 | 31 |
| 6 | 526 | 429 | 462 | 1 / 16 | 37 |
| 7 | 616 | 500 | 536 | 2 / 18 | 43 |
| 8 | 720 | 583 | 622 | 1 / 19 | 51 |
| 9 | 843 | 679 | 721 | 2 / 21 | 61 |
| 10 | 986 | 791 | 837 | 3 / 24 | 72 |
| 11 | 1.154 | 921 | 971 | 2 / 26 | 85 |
| 12 | 1.350 | 1.073 | 1.126 | 3 / 29 | 100 |
| 13 | 1.579 | 1.250 | 1.306 | 2 / 31 | 118 |
| 14 | 1.848 | 1.456 | 1.515 | 4 / 35 | 139 |
| 15 | 2.162 | 1.697 | 1.757 | 3 / 38 | 165 |
| 16 | 2.529 | 1.977 | 2.038 | 4 / 42 | 194 |
| 17 | 2.959 | 2.303 | 2.365 | 4 / 46 | 230 |
| 18 | 3.462 | 2.683 | 2.743 | 5 / 51 | 271 |
| 19 | 4.051 | 3.125 | 3.182 | 5 / 56 | 320 |
| 20 | 4.740 | 3.641 | 3.691 | 5 / 61 | 378 |
| 21 | 5.545 | 4.242 | 4.281 | 6 / 67 | 447 |
| 22 | 6.488 | 4.942 | 4.966 | 7 / 74 | 528 |
| 23 | 7.591 | 5.757 | 5.761 | 7 / 81 | 624 |
| 24 | 8.881 | 6.707 | 6.683 | 9 / 90 | 737 |
| 25 | 10.391 | 7.814 | 7.752 | 8 / 98 | 870 |
| 26 | 12.158 | 9.103 | 8.992 | 10 / 108 | 1.028 |
| 27 | 14.225 | 10.605 | 10.431 | 11 / 119 | 1.214 |
| 28 | 16.643 | 12.355 | 12.100 | 12 / 131 | 1.434 |
| 29 | 19.472 | 14.393 | 14.036 | 13 / 144 | 1.693 |
| 30 | 22.782 | 16.768 | 16.282 | 15 / 159 | **2.000** |

**Türetilen katır üretim eğrisi:** `katırSaat(sv) ≈ 16 × 1,18^(sv − 1)`

---

## 5. Ticaret Akışı (özet)

1. Market'e git → **hammadde takası** ekranı.
2. Hangi hammaddeyi vereceğini / alacağını ve miktarı seç.
3. **Katır** yüklenir (boş katır gerekir).
4. Katır **hedefe yola çıkar** (yolculuk süresi mesafeye bağlı).
5. Hedefe varınca **hammadde teslim edilir**, katır **kaybolur**.
6. Katır köyden ayrıldığı an **yeni katır üretimi başlar** (çiftlik üretim hızında).

---

## 6. ⚠️ Açık Sorular

| # | Konu | Durum |
|---|---|---|
| 1 | **Katır başına taşıma kapasitesi** (birim hammadde) | ❔ yardım sitesinde yok |
| 2 | Ticaret **kur oranı** / komisyon var mı | ❔ |
| 3 | Katır **yolculuk süresi** formülü | ❔ (birim hızına benzer olması beklenir) |
| 4 | **Pazar yeri (market stall)** kapasitesi tam sayısal karşılığı | ❔ |

> Kesin veriler `data/buildings.json` içindedir (market & stable).
