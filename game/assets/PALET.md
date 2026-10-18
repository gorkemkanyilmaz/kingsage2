# PALET — "Taht ve Kılıç" Renk Sistemi

> **Stil hedefi: PASTEL & CANLI (storybook pastel).**
> Yumuşak, biraz desatüre ama asla soluk değil; doygunluk orta, açıklık yüksek,
> gölgeler **saf siyah değil** (ton kaydırılmış koyu). Böylece mobil ekranda
> okunaklı kalır ve "içine çeken" bir Orta Çağ hikâye kitabı havası verir.
>
> Bu palet, `game/assets/sprites/**` altındaki gerçek Kenney (CC0) varlıklarının
> **ölçülmüş baskın tonlarına** göre hizalandı (bkz. §9). Sprite'ları bu rampalarla
> **tint / modulate** ederek tek bir görsel dil elde edebilirsin.

---

## 1. Tasarım İlkeleri

| Kural | Değer | Neden |
|---|---|---|
| Doygunluk (HSL **S**) | **%30 – %65** | Pastel ama "ölü" değil |
| Açıklık (HSL **L**) | **%55 – %88** | Mobil/parlak ekranda okunur |
| Gölge rengi | Ana tonun **hue+15°**, L−%25 | Saf `#000` kullanılmaz → doku korunur |
| Highlight | Ana tonun **hue−8°**, L+%18 | Sıcak ışık hissi |
| Eşzamanlı vurgu rengi | Sahne başına **en fazla 1** | Canlılık dağınık olmasın |
| Kontrast (metin) | WCAG AA ≥ 4.5:1 | Panel üstü yazı okunurluğu |
| Renk körlüğü | Durum **renk + ikon/şekil** ile birlikte | Kırmızı–yeşil ayrımı tek başına yetmez |

---

## 2. Çekirdek Palet (Notr & Zemin)

| Ad | HEX | Kullanım |
|---|---|---|
| `parsomen` | `#FDF6E3` | Ana UI zemini, kaydırma alanı |
| `parsomen-koyu` | `#F2E4C8` | Panel iç gölgesi, satır zebrası |
| `bulut` | `#FBFBF7` | Kart yüzeyi, yüksek kontrast metin zemini |
| `sis` | `#D9E0EA` | Pasif/disabled, ayraç |
| `duman` | `#B9BFCC` | İkincil metin zemini, gölge kutusu |
| `gece-cam` | `#23222B` | Modal perdesi (`Color(0.137,0.133,0.169,0.62)`) |
| `murekkep` | `#3B3630` | Ana metin (koyu) |
| `murekkep-soluk` | `#7C7368` | İkincil metin, etiket |
| `tebesir` | `#FFFDF7` | Metin (koyu zemin üstü) |

---

## 3. Malzeme Rampaları (3 kademe: açık / ana / gölge)

Godot'da bir sprite'ı `modulate` ile bu üçlüye çekebilir veya kendi çiziminde
**tek ışık yönü** kuralına uyarak bu üçünü kullanabilirsin.

### 3.1 Çim / Arazi
| Kademe | HEX |
|---|---|
| Çim Işık | `#D8F0A6` |
| **Çim** | `#A9DC72` |
| Çim Gölge | `#77B54A` |
| Derin Yeşil | `#4C8A38` |

### 3.2 Su
| Kademe | HEX |
|---|---|
| Sığ Su | `#B6EFE9` |
| **Su** | `#7DD3E0` |
| Su Gölge | `#4EA6C6` |
| Derin Su | `#2C7A9C` |

### 3.3 Kum & Toprak / Yol
| Kademe | HEX |
|---|---|
| Kum Işık | `#F8E7B8` |
| **Kum** | `#EDCE8F` |
| Toprak | `#D6A469` |
| Koyu Toprak | `#A87542` |
| **Yol (patika)** | `#E3C79A` |

### 3.4 Taş & Sur
| Kademe | HEX |
|---|---|
| Sur Işık | `#F1EADC` |
| **Sur / Taş** | `#D7CCB8` |
| Taş Gölge | `#B0A18A` |
| Taş Derin | `#877A66` |
| Mermer (Kale) | `#F7F3E8` |

### 3.5 Ahşap
| Kademe | HEX |
|---|---|
| Ahşap Işık | `#EBC79C` |
| **Ahşap** | `#C98F5B` |
| Ahşap Gölge | `#9A6437` |
| Ahşap Koyu | `#6B432A` |

### 3.6 Çatı (Kiremit) — pastel canlı
| Kademe | HEX |
|---|---|
| Kiremit Işık | `#FFC2AC` |
| **Kiremit** | `#F58A6E` |
| Kiremit Gölge | `#CF5F49` |

### 3.7 Çatı Varyantları (oyuncu/ittifak kimliği)
| Varyant | Işık | Ana | Gölge |
|---|---|---|---|
| Safir Çatı (mavi) | `#BCD5FA` | `#6E9BE8` | `#4A72BE` |
| Leylak Çatı (mor) | `#D6C6F5` | `#9B7BE0` | `#7156B3` |
| Fıstık Çatı (yeşil) | `#CBEBA8` | `#8FCB63` | `#63973F` |
| Hardal Çatı (sarı) | `#FFE9A8` | `#F2C13C` | `#BE8F1C` |

### 3.8 Metal / Demir & Çelik
| Kademe | HEX |
|---|---|
| Çelik Parlak | `#E6ECF5` |
| **Demir** | `#9AA4B4` |
| Demir Gölge | `#6A7385` |
| Pas / Bakır | `#B87B4A` |

### 3.9 Altın & Vurgu (ödül, kron, premium)
| Kademe | HEX |
|---|---|
| Altın Işık | `#FFEFB0` |
| **Altın** | `#F7C948` |
| Altın Gölge | `#C4951B` |
| Bronz | `#C98F3B` |

---

## 4. Kaynak İkonları (oyun içi 6 kaynak + özel)

| Kaynak | HEX | Not |
|---|---|---|
| **Odun** | `#C98F5B` | Ahşap ana ton |
| **Taş** | `#B0A18A` | Taş gölge tonu |
| **Demir** | `#9AA4B4` | Demir ana ton |
| **Tahıl / Buğday** | `#F7C948` | Altın ile aynı aile → tonda ayrıştır (`#E0B23A`) |
| **Altın / Kron** | `#FFD24A` | Parlak + hafif glow |
| **Yiyecek / Nüfus** | `#FF9E9E` | Pastel kırmızı-pembe |
| **İnşaat / İşçi** | `#8FD4E6` | Pastel camgöbeği |
| **Araştırma / Bilgi** | `#B9A3F0` | Pastel mor |

> İkon zemini her zaman `parsomen` üzerine **koyu mürekkep silüeti** veya
> renkli rozet (`#FFFFFF` %20 çerçeve) ile çizilir; satürasyon kaynağa göre.

---

## 5. UI Paleti

| Öğe | HEX | Kullanım |
|---|---|---|
| Panel Zemini | `#FFFDF7` | Ana panel dolgusu |
| Panel Zemini (alt) | `#F2E4C8` | Başlık/altbilgi şeridi |
| Panel Kenar (ahşap) | `#9A6437` | Birincil çerçeve |
| Panel Kenar (taş) | `#B0A18A` | İkincil çerçeve |
| Panel Gölge | `#6B432A` | 2 px alt-çerçeve |
| Buton — Birincil | `#7ED957` | Onay / üret / inşa |
| Buton — Birincil Hover | `#9BE873` | |
| Buton — İkincil | `#6E9BE8` | Bilgi / yükselt |
| Buton — Uyarı | `#F7C948` | Dikkat / süre doluyor |
| Buton — Tehlike | `#F2705D` | Saldırı / yık / iptal |
| Buton — Pasif | `#D9E0EA` | Kullanılamaz + `#7C7368` metin |
| Yazı Alanı Kenarı | `#B0A18A` | Input |
| Kaydırıcı / Progress | `#7DD3E0` zemin `#E3E8F0` | |
| Sekme Aktif | `#FFFDF7` + alt çizgi `#F7C948` | |
| Rozet / Bildirim | `#F2705D` metin `#FFFDF7` | |
| Yıldız / Puan | `#FFD24A` | |

**Dokunma hedefi (mobil):** min **48×48 dp**; birincil eylem butonu min **56 dp**
yükseklik, ekranın alt %25'inde.

---

## 6. Durum, Taraf ve Harita İşaretleri

| Durum | HEX | Not |
|---|---|---|
| Dost / İttifak | `#6EC1E4` | Mavi-pastel; **kalkan ikonu** ile birlikte |
| Kendi | `#7ED957` | Yeşil; **taç ikonu** |
| Nötr | `#C9C2B6` | |
| Düşman | `#F2705D` | Kırmızı; **kılıç ikonu** |
| Saldırı Uyarısı | `#FF8F6B` | Nabız animasyonu |
| Destek | `#8FD4E6` | |
| Seçili / Vurgu | `#FFD24A` | Kalın 3 px dış çizgi |
| Başarı | `#7ED957` | |
| Bilgi | `#7DD3E0` | |
| Uyarı | `#F7C948` | |
| Hata | `#F2705D` | |
| Kilitli | `#B9BFCC` + kilit ikonu | |

### Harita katmanları
| Katman | HEX | Not |
|---|---|---|
| Ova | `#A9DC72` | Çim ana |
| Orman | `#4C8A38` | Derin yeşil + ağaç sprite'ı |
| Dağ | `#877A66` | Taş derin + `#F1EADC` kar |
| Su | `#7DD3E0` | |
| Yol | `#E3C79A` | |
| Vadi/Bataklık | `#77B54A` | Çim gölge |
| Keşfedilmemiş (sis) | `#B9BFCC` %70 alpha | |
| Izgara (grid) | `#FFFFFF` %12 alpha | İzometrik çizgiler |

---

## 7. Gündüz–Gece Işık Katmanı

Tam ekran bir `CanvasModulate` / `ColorRect` (blend `multiply`) ile:

| Saat dilimi | HEX | Alpha | Blend |
|---|---|---|---|
| Şafak | `#FFD9A0` | 0.25 | multiply |
| Sabah | `#FFF6E0` | 0.10 | multiply |
| Gündüz | — | 0.00 | — |
| Altın Saat | `#FFB37A` | 0.18 | multiply |
| Akşam | `#C79ACB` | 0.26 | multiply |
| Gece | `#2B3A67` | 0.38 | multiply |
| Ay Işığı (gece vurgu) | `#A9C7F5` | 0.15 | screen |

> Gece bonusu/uyku modu gibi mekanikler bu katmanın alfasıyla görsel olarak
> eşleştirilirse oyuncu zamanı sezgisel olarak okur (bkz. `docs/06`, `docs/11`).

---

## 8. Sprite Tint Rehberi (mevcut CC0 varlıklar için)

Kenney varlıkları sıcak toprak tonlarındadır. Pastel-canlı hedefe çekmek için
`CanvasItem.modulate` / `Sprite2D.modulate` ile:

| Amaç | Modulate | Sonuç |
|---|---|---|
| Nötrleştir + aydınlat | `#FFF4E2` | Ahşap/taş pastelleşir |
| Gece soğuğu | `#BFD0F0` | Ay ışığı hissi |
| Seçili / hover | `#FFF2C4` | Altın vurgu |
| Pasif / disabled | `#D9E0EA` | Sis tonu |
| Düşman vurgusu | `#FFE0DA` | Kırmızıya çeker |
| İnşaat iskeleti (hayalet) | `#FFFFFF` @ alpha 0.45 | Yerleştirme önizleme |
| Hasarlı bina | `#E8D2C0` + duman sprite'ı | |

**Kural:** aynı anda en fazla **1 modüle + 1 ışık overlay**; üst üste tint
kontrastı bozar.

---

## 9. Mevcut Varlıklardan Ölçülen Baskın Tonlar (referans)

`game/assets/sprites/**` içindeki 4000+ PNG üzerinden ölçülen en sık renkler
(pastel paletin "hizalandığı" gerçek değerler):

| Sıra | HEX | Pay | Küme |
|---|---|---|---|
| 1 | `#D0D0B0` | ~%6.8 | kum/parşömen (kum tonuyla eşleşir) |
| 2 | `#C0B0A0` | ~%5.0 | taş/kum |
| 3 | `#909080` | ~%5.0 | taş gölge |
| 4 | `#A07050` | ~%4.7 | ahşap |
| 5 | `#806030` | ~%4.3 | ahşap koyu |
| 6 | `#606060` | ~%3.3 | taş derin |
| 7 | `#C0A070` | ~%1.8 | ahşap ışık |
| 8 | `#E0C080` | — | parşömen (cartography textures) |
| 9 | `#90A0A0` | ~%1.1 | su/taş (isometric-blocks voxel) |
| 10 | `#40A070` | — | çim (isometric-blocks abstract) |

> **Not:** Varlıkların doğal aralığı `#606060`–`#F0E0B0` (nötr/sıcak). Bu palet
> bilinçli olarak **yeşil, mavi ve mor ailelerini** ekler; aksi hâlde oyun
> "kahverengi yığını" gibi görünür. Çim/su/çatı rampaları bu yüzden şart.

---

## 10. Godot Kullanım Notları

### 10.1 Paleti kaynak dosyaya bağla
```gdscript
# game/autoload (KOD EKIBI DOSYASI DEGIL - ornek amacli)
# assets/PALET.md'deki hex'ler resources/palette.tres icinde Color olarak tutulabilir.
const C = {
    "cim":          Color("#A9DC72"),
    "cim_isik":     Color("#D8F0A6"),
    "cim_golge":    Color("#77B54A"),
    "su":           Color("#7DD3E0"),
    "tas":          Color("#D7CCB8"),
    "ahsap":        Color("#C98F5B"),
    "kiremit":      Color("#F58A6E"),
    "altin":        Color("#F7C948"),
    "parsomen":     Color("#FDF6E3"),
    "murekkep":     Color("#3B3630"),
    "birincil":     Color("#7ED957"),
    "tehlike":      Color("#F2705D"),
    "dost":         Color("#6EC1E4"),
    "dusman":       Color("#F2705D"),
}
```

### 10.2 Tema üretimi
- `Control` düğümlerinde `Theme` → `PanelContainer/StyleBoxFlat`:
  - `bg_color = #FFFDF7`, `border_color = #9A6437`, `border_width_* = 3`,
    `corner_radius_* = 6`, `shadow_color = #6B432A`, `shadow_size = 2`.
- `Button` → üç `StyleBoxFlat` (normal/hover/pressed) = `#7ED957` / `#9BE873` / `#63B843`.
- Yazı tipi eşlemesi (bkz. `ASSET-MANIFEST.md` §Fontlar):
  - **Başlık:** `Cinzel-Bold` / `Metamorphous-Regular`
  - **Gövde:** `Nunito-Regular` (yuvarlak, dostane) veya `Rubik-Regular`
  - **Uzun metin / yardım:** `EBGaramond-Regular`
  - **Vurgu / dekor:** `Almendra-Regular`, `MedievalSharp.ttf`, `Marcellus-Regular`

### 10.3 İzometrik tile zemini
- Ova zemini tek bir `#A9DC72` tile yerine **iki tonlu** döşe:
  satranç deseninde `#A9DC72` / `#9FD167` → göz yorulmaz, derinlik artar.
- Gölge: her binanın altına %22 alpha `#3B3630` **elips**; saf siyah yok.

---

## 11. Hızlı HEX Listesi (kopyala-yapıştır)

```
#FDF6E3 #F2E4C8 #FBFBF7 #D9E0EA #B9BFCC #23222B #3B3630 #7C7368 #FFFDF7
#D8F0A6 #A9DC72 #77B54A #4C8A38
#B6EFE9 #7DD3E0 #4EA6C6 #2C7A9C
#F8E7B8 #EDCE8F #D6A469 #A87542 #E3C79A
#F1EADC #D7CCB8 #B0A18A #877A66 #F7F3E8
#EBC79C #C98F5B #9A6437 #6B432A
#FFC2AC #F58A6E #CF5F49
#BCD5FA #6E9BE8 #4A72BE
#D6C6F5 #9B7BE0 #7156B3
#CBEBA8 #8FCB63 #63973F
#FFE9A8 #F2C13C #BE8F1C
#E6ECF5 #9AA4B4 #6A7385 #B87B4A
#FFEFB0 #F7C948 #C4951B #C98F3B
#FFD24A #FF9E9E #8FD4E6 #B9A3F0
#7ED957 #9BE873 #63B843 #F2705D #FF8F6B #6EC1E4 #C9C2B6
#FFD9A0 #FFF6E0 #FFB37A #C79ACB #2B3A67 #A9C7F5
```

---

## 12. AÇIK SORULAR

- `AÇIK SORU:` Oyunun **birincil marka rengi** ne olacak (çatı varyantlarından
  hangisi "oyuncu" kimliği)? Öneri: **Safir Çatı `#6E9BE8`** — pastel paletle en
  uyumlu ve yeşil arazi üzerinde en okunur.
- `AÇIK SORU:` Gece modunda binalar **karartılacak mı**, yoksa sadece pencere
  ışıkları mı yanacak? (Performans: mobilde tam ekran multiply katmanı ucuzdur.)
- `AÇIK SORU:` Kaynak ikonlarında **renk körlüğü** için şekil ayrımı yeterli mi,
  yoksa her kaynağa farklı **çerçeve şekli** mi verilsin?
- `AÇIK SORU:` `#FFD24A` (altın) hem "kron/premium" hem "puan" için kullanılıyor;
  ikisinin ayrışması gerekiyorsa premium için **`#C98F3B` bronz** ayrılabilir.
