# 00 — Proje Özeti, Kapsam ve Kararlar

## 1. Amaç

King's Age (Gameforge) tarayıcı/strateji oyununun **oyun mantığını bütünüyle** çıkarmak ve bu
mantığı kullanan **mobil (Godot) bir oyunun üretim planını** oluşturmak.

**Bu fazın çıktıları:**
1. Oyunun tüm sistemlerinin kural bazında dokümantasyonu (bu depo).
2. Her bina/birim için tam seviye tabloları ve yapısal JSON verisi.
3. Türetilmiş matematik (maliyet, üretim, puan, savaş, fetih formülleri).
4. Godot tabanlı mobil oyun için teknik plan ve görev listesi (task breakdown).

**Bu fazın kapsam dışı:** Gerçek kod yazımı, sanat üretimi, backend/sunucu kurulumu.

---

## 2. Nihai Ürün Tanımı (hedef)

- **Tür:** Gerçek zamanlı olmayan (tick/sipariş tabanlı) tarayıcı-stratejisi → mobil.
- **Platform:** iOS + Android, tek kod tabanı (Godot).
- **Görsel:** 2.5D izometrik köy görünümü; sprite + parçacık/ışık/parallax/animasyon efektleri.
- **Oynanış modu:**
  - **Faz A (MVP):** Tek oyunculu — bot (AI) rakipler, yerel simülasyon, çevrimdışı ilerleme.
  - **Faz B:** Gerçek çok oyunculu (sunucu, veritabanı, oturum, senkronizasyon).
- **İçerik dili:** Oyun metinleri başlangıçta Türkçe (isteğe göre yerelleştirilebilir altyapı).

---

## 3. Birebir Alınacak vs Özgün Olacak

| Öğe | Karar |
|---|---|
| Oyun mekanikleri / kurallar | **Birebir** |
| Sayısal denge (maliyet, üretim, savaş değerleri) | **Birebir** |
| Bina / birim / kaynak isimleri | **Özgün** |
| Görseller, ikonlar, sesler | **Özgün** |
| Arayüz metinleri | **Özgün** |
| "KingsAge" marka adı, logosu | **Kullanılmayacak** |

> Mekanik ve sayılar kopyalanırken, **marka kimliği (isim/görsel/ses/metin)** tamamen yeniden üretilecektir.
> Bu dokümanlarda geçen "Castle, Barracks, Squire, Berserker" gibi isimler **yalnızca teknik referans**
> amaçlıdır; üründe özgün karşılıkları kullanılacaktır.

---

## 4. Fazlar

| Faz | Ad | Çıktı | Durum |
|---|---|---|---|
| **1** | **Oyun analizi & dokümantasyon** | Bu depodaki tüm dokümanlar, JSON veriler | ✅ Tamamlandı |
| **2** | **Godot iskeleti + dikey dilim** | Tek yerleşim, kaynak üretimi, inşaat, asker eğitimi, 1 bot savaşı | ⏳ Planlandı |
| **3** | **Tek oyunculu tam oyun** | Harita, çoklu yerleşim, fetih, casusluk, ittifak(AI), pazar | ⏳ Planlandı |
| **4** | **2.5D görsel yükseltme** | Animasyonlu izometrik köy, efektler, UI cilası | ⏳ Planlandı |
| **5** | **Online altyapı** | Sunucu, hesap, gerçek zamanlı dünya, PvP | ⏳ Planlandı |
| **6** | **Yayın** | Mağaza hazırlığı, performans, yerelleştirme | ⏳ Planlandı |

---

## 5. Kaynak ve Sürüm

- 🇬🇧 EN kaynak: `https://s59-en.kingsage.gameforge.com/help.php` (World 59, English) — 54 sayfa
- 🇹🇷 **TR kaynak (resmî terimler):** `https://s59-tr.kingsage.gameforge.com/help.php` — 52 sayfa
- Oyun sürümü (help footer): **7.1.1 / 7.1.1-r1**
- EN Dünya 59 başlangıcı: **09.09.2026** · TR dünya başlangıcı: **09.05.2025**
- Kullanıcı talimatıyla **help içeriği** ve **help içindeki tüm içerik linkleri** ziyaret edildi.
- **Kapsam dışı:** Forum (ve ittifak forumu), Logout, Rules, Legal, T&Cs, Privacy Policy, Change-logs.

---

## 6. Açık Sorular / Doğrulanacak Noktalar

> Tam ve güncel liste: [`15-MATEMATIK-VE-FORMULLER.md`](15-MATEMATIK-VE-FORMULLER.md) §7.

Aşağıdakiler yardım sitesinden **birebir çıkarılamadı**; oyun istemcisi/deneyimle doğrulanmalı:

1. **"Zaman faktörü" sütununun kesin formülü.** Her binada seviyeye göre azalan bir yüzde (örn. Kışla:
   Lv1 %80 → Lv30 %10). İnşaat süresinin tam hesabı (saniye) yardım sitesinde yok.
   → *Hipotez:* inşaat süresi = taban_süre × zaman faktörü; taban_süre kaynak maliyetine ve
   **Kale** seviyesine bağlı. **Doğrulanacak.**
2. **Temel inşaat/eğitim süreleri** (saniye/dakika). Eğitim süreleri tablolarda **Kışla seviyesine**
   bağlı gösteriliyor ama katsayı yok.
3. **Kaynak üretimi ile Değirmen/vatandaş ilişkisi:** üretim saatlik veriliyor; "vatandaş başına" mı,
   bina başına mı belirsiz. (Bkz. `15-MATEMATIK-VE-FORMULLER.md`.)
4. **Simyager (Alchemist) teknik listesi:** hangi teknikler var, maliyetleri/süreleri neler? Yardım
   sadece "teknik araştırılır, kalıcı bonus verir, bazıları haritada görünürlük verir" diyor.
5. **Altın zırh maliyet artışı:** Kuyumcu'da her üretimde maliyet artar ama çarpan belirtilmemiş.
   (Üretilen Kont sayısına göre artış.)
6. **Market/katır kapasitesi ve ticaret oranı** (katır başına taşıma kapasitesi) anlatılmamış.
   (Bkz. `14-TICARET-VE-PAZAR.md`.)
7. **Moral formülü** net değil: "100% ile 30% arasında" ve "puan oranına bağlı" deniyor, eğri yok.
8. **Şans (luck)** ±%25, **gece bonusu** ×2, **duvar bonusu** %105→%220 — bunlar net.
9. **Casusluk hesabı:** "saldıran/tutan casus oranı" → hayatta kalan sayısı; kesin formül yok.
10. **Şahmerdan (ram) ile duvar hasarı** ve **Mancınık (trebuchet) ile bina hasarı** formülleri
    niteliksel anlatılmış.
11. **Fetih sonrası** yeni sahibin güç alanı %30'a yükseliyor — net.
12. **Puan tablosunda Sur Lv1 = 20** (doğrusal varsayımla 20) — tutarlı; kesin doğrulama yapıldı.

---

## 7. Terim Sözlüğü

`02-OYUN-DONGUSU-VE-TERIMLER.md` dosyasına bakınız.
