# 07 — Casusluk (Espionage)

Kaynak: `units_espionage`, `units_battle`, `villages`(Hideout)

## 1. Amaç

Casuslar, **düşman yerleşimleri** hakkında **bina, kaynak ve birlik** bilgisi toplar →
saldırı planlamasını kolaylaştırır.

## 2. İki Casusluk Türü

| Tür | Nasıl başlatılır | Görünürlük | Hız | Rapor |
|---|---|---|---|---|
| **Normal casusluk** | Normal **saldırı komutu** ile | Rakip **hemen görür** | Normal | Savunan **rapor alır** (normal saldırıdaki gibi) |
| **Sinsi casusluk (creeping)** | Özel **casusluk butonu** ile | Rakip **hiçbir şey görmez** | Haritada **belirgin şekilde yavaş** | Savunan **asla rapor almaz** |

> **Sinsi casuslukta:** casus çok dikkatli hareket ettiği için **hareket hızı belirgin şekilde yavaştır.**

## 3. Hesaplama

1. Saldıran casuslar ile savunan casuslar arasındaki **oran** hesaplanır.
2. Bu orandan **hayatta kalan casus sayısı** bulunur.
3. **Savunan asla birim kaybetmez.**
4. Sonunda **tüm casuslar ana yerleşime döner.**

## 4. Elde Edilen Bilgi

Bilgi, **casusluk türüne** ve **hayatta kalan saldıran casus sayısına** bağlıdır.

| Bilgi | Normal casusluk | Sinsi casusluk |
|---|:--:|:--:|
| Düşman birlikleri **ve moral** | ✅ | ✅ |
| Düşman kaynakları | ✅ | ✅ |
| Binalar ve gelişim seviyeleri | ✅ | ✅ |
| **Yerleşim dışındaki birlikler** | ✅ | ❌ |

> Yani **sinsi casusluk** daha gizlidir ama **"yerleşim dışındaki birlikler"** bilgisini **vermez**.

## 5. Casusların Muharebedeki Rolü

- Saldıran orduda **casus** varsa, **normal muharebe başlamadan önce** casusluk hesaplanır
  (bkz. `06-SAVAS-SISTEMI.md` → Faz 2).
- Casusların savaş değerleri çok düşüktür (Saldırı 1, Savunma 10/5/7).

## 6. Gizli Depo (Hideout) Etkisi

- **Gizli Depo**, hammaddeleri **casusların gözlerinden** ve hırsızlardan korur.
  (Yardım: *"Bu gizli depolar, hırsızların elinden ve casusların gözünden uzak yerlerdir."*)
- **Kapasite birimi = TOPLAM hammadde** (`production.json` → `unit: "resource_total"`),
  kaynak başına **değil**: `kapasite = 150 × 1,19^(sv−1)` (sv 30 → 23.278).
  Yani kapasite, üç hammaddenin **toplamından** korunan miktardır.
- **Yağmada:** `korumalı = min(kapasite, toplam)` → `alınabilir = toplam − korumalı`;
  ganimet taşıma kapasitesine kadar **oransal** (en büyük kalan) dağıtılır.
- **Casuslukta:** aynı kural uygulanır → `görünür_toplam = max(0, toplam − korumalı)`,
  kaynak başına dağıtım **oransal (en büyük kalan)** — **yağma ile birebir aynı** algoritma.
  Toplam ≤ kapasite ise casus **hiç hammadde göremez**.
- Yani **Gizli Depo yükseldikçe casusluk da daha az bilgi verir** ve iki katman
  (yağma ↔ casusluk) **aynı semantiği** kullanır.
