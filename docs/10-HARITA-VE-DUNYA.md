# 10 — Harita, Dünya ve World Ayarları

Kaynak: `map`, `worldinfo`, `villages`

## 1. Dünya Yapısı

- Dünya **kalıcıdır (persistent)**: oyuncu oynamasa bile yaptığı değişiklikler dünyada kalır.
- Her dünya (sunucu) **aynı yapıda** kurulur; içeriği değişir.

| Özellik | Değer |
|---|---|
| Dünya boyutu | **1.000 × 1.000 alan (tile)** |
| Kıta (continent) | **100 × 100 alan** |
| Kıta sayısı | **10 × 10 = 100 kıta** |
| Koordinat biçimi | `X\|Y` (ör. `499|506` → kıta `K54`) |

> Kıta numarası koordinattan türetilir: **`K` + `floor(Y/100)` + `floor(X/100)`** (satır önce, sütun sonra),
> yani sayısal kimlik `floor(Y/100) × 10 + floor(X/100)` (örnek: `499|506` → `floor(506/100)=5`, `floor(499/100)=4` → **K54** ✅).
> ⚠️ **Bizim ölçeğimiz:** dünya 200×200 seçildi (kullanıcı kararı); kıta boyutu **kaynakla birebir 100×100** kalır
> → bizde **4 kıta** (K00, K01, K10, K11). KingsAge'in 1000×1000'inde 100 kıta vardır; yapı aynı, ölçek farklı.

## 2. Harita Görünümü

| Öğe | Anlam |
|---|---|
| Farklı yerleşim grafikleri | Yerleşimin **yaklaşık gelişim seviyesini** gösterir |
| **Gri** yerleşim | **Tatil/uyku modunda (vacation/SM)** |
| **Altın parıltı** | **Bonus yerleşim** |
| Renkli vurgular | Haritanın alt kenarındaki **açıklama (legend)** ile eşleşir |
| İttifak üyeleri | Vurgulanır (**yeşil**) |
| Ally (müttefik ittifak) | **Sarı** |
| NAP (saldırmazlık) | **Turuncu** |
| Enemy (düşman) | **Kırmızı** (teknik etkisi yok) |

- **Premium hesap** sahipleri haritayı **kendileri vurgulayabilir** (hedef/dost/düşman işaretleme).

### 2.1 Bonus köyler (kaynak: `villages.txt`)

> Bazı yerleşimler **bonus köy**'dür. Başlarında özel yetenekli **'Usta'** vardır ve köye **belirli bir bonus** verir.
> **Her köy yalnızca BİR bonusa sahip olabilir.** Bonus köyler haritada **altın parıltılı** görünür.

| # | Bonus | Etki |
|---|---|---|
| 1 | Odun | **+%10** odun üretimi |
| 2 | Taş | **+%10** taş üretimi |
| 3 | Demir | **+%10** demir üretimi |
| 4 | Vatandaş | **+%10** vatandaş |
| 5 | Eğitim | **+%10 daha hızlı** birlik eğitimi |
| 6 | Hammadde üretimi | **+%3** (tüm hammaddeler) |

> ⚠️ Dikkat: 1–3 numaralı bonuslar **+%10**, 6 numaralı bonus **+%3**'tür (ikisi birden değil — köy **tek** bonus alır).

### 2.2 Terkedilmiş köyler (kaynak: `villages.txt`)

- Sahibi **inaktiflik** nedeniyle silinmiş hesaplardan kalan köylerdir; **soyguncular** ele geçirmiştir.
- Soyguncular köyü **geliştirmeye devam eder**: **bina inşa eder**, **askerî birim üretir** → köyün **puanı artar**.
- Yani terkedilmiş köyler **normal köy gibi** davranır (hammadde, bina, ordu) — yalnızca sahibi oyuncu değildir.
- **Koruma yoktur** (bkz. `11-OYUNCU-PUAN-KORUMA.md` §10.5).

## 3. Minimap

- Haritadan **daha büyük bir bölümü** gösterir; yerleşimler **renklerle** ayırt edilir.
- **Varsayılan:** 2 minimap boyutu.
- **Premium:** **9 boyut** (iki çok büyük genel bakış dahil).

## 4. Simyager Teknikleri ve Harita

- **Simyager'da** kaynak harcanarak **teknik** araştırılır → **kalıcı bonus**.
- Tekniklerin **çoğu harita görünümünü etkiler**.
- Bir teknik **bir kez** araştırıldığında **tüm yerleşimlerde global** olur, tekrar araştırılmaz.
- **Bazı teknikler harita ayarlarından ayrıca aktive edilmelidir.**

---

## 5. World (Sunucu) Ayarları — World 59

Kaynak: `help.php?m=worldinfo`

| Ayar (resmî TR) | İngilizce (kaynak) | EN Dünya 59 | TR dünya |
|---|---|---|---|
| **Hız** | Speed | 4 | 4 |
| **Birim hızı** | Unit run time | 4 | 4 |
| **Binayı yık** | Tear down building | aktif | aktif |
| **Bağımsız gelişen terkedilmiş köyler** | Independent. growing abandoned settlements | aktif | aktif |
| **Saldırı için gereken en az birim** | Min. units for attacking | 3 × Kışla seviyesi | 3 × Kışla seviyesi |
| **Yeni oyuncular için saldırı koruması** | Attack protection | 5 gün | 5 gün |
| **Fetih Koruması** | Conquest protection | 7 gün | 7 gün |
| **maks. oran saldıran : savunan** | Max. ratio attacker : defender | 10 : 1 (ihlalde **2 ay** koruma kaybı) | 10 : 1 |
| **Tatil bakıcısı** | Holiday replacement | aktif | aktif |
| **Savunanlar için gece bonusu** | Night bonus for defenders | **kapalı** | **aktif (00:00–06:00)** |
| **Saldırı iptal zamanı** | Attack cancellation time | 30 dakika | 30 dakika |
| **Katır - iptal zamanı** | Donkey cancellation time | 15 dakika | 15 dakika |
| **Yön seçimi** | Orientation choice | aktif | aktif |
| **Kontun maksimum yolculuk mesafesi** | Max. Count travel distance | **100 alan** | **80 alan** |
| **Yabancı Kont yüzünden güç alanı kaybı** | Loss of realm of power | 2.250–2.750; Anıt: 1.750–2.250 | aynı |
| **Saat başına güç alanı artışı** | Realm of power increase/hour | Köy Puanının **%1'i** | aynı |
| **Sürüm** | Version | 7.1.1-r1 | 7.1.1-r1 |
| **Başlama tarihi** | Start date | 09.09.2026 | 09.05.2025 |

> ⚠️ **İki dünya farklı!** (gece bonusu, Kont mesafesi). Oyunumuzda bu ayarlar **yapılandırılabilir (config)**
> olmalıdır — özellikle `hız`, `birim hızı`, `gece bonusu`, `saldırı koruması`, `maks. oran`, `Kont mesafesi`.

---

## 6. Yerleşim Sayfaları ve Favoriler

- **Favoriler:** Sık kullanılan yerleşim/oyuncular kaydedilir; **gruplar** halinde düzenlenebilir.
- Yerleşim detaylarında **"favorilere ekle"** ile koordinat saklanır.
- Koordinat girilebilen her yerde **favori seçilebilir**.
- Yerleşim adı **değiştirilebilir**.

Kaynak: `villages`, `villages_favorites`
