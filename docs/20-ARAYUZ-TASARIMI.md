# 20 — Arayüz Tasarımı (2.5D, Dikey, Pastel) — Taht ve Kılıç

> 🔴 **A-ARAYUZ ajanı için bağlayıcı tasarım sözleşmesi.**
> Kararlar: **Dikey (1080×1920)**, **2.5D (2D + efekt)**, **pastel & canlı**, **Türkçe** (resmî terimler),
> ana marka rengi **Safir `#6E9BE8`**. Palet: `game/assets/PALET.md`. Terimler: `docs/TERIMLER.md`.

---

## 1. Ekran akışı (navigasyon)

```
Boot (yükleme)
  └─> Ana Menü
        ├─ "Yeni Oyun"  ──> Yön/Köy Seçimi ──> Köy Ekranı
        ├─ "Devam Et"   ──> Köy Ekranı (kayıttan)
        └─ "Ayarlar"    (dünya profili: TR/EN · hız · ses · müzik kapalı)

Köy Ekranı  ←→  Dünya Haritası  ←→  Raporlar / Mesajlar
   └─ paneller: bina detay · kuyruk · kışla · market · köşk · ayarlar
```

**Yön/Köy Seçimi:** oyuncu başlangıç köyünün **yönünü** seçer (kaynak: `worldinfo` "Yön seçimi aktif").
Dünya üretimi: `WorldGenerator.generate_world(seed, 100)`.

---

## 2. Köy Ekranı (ana ekran) — 2.5D

- **İzometrik zemin** (`TileSet`, Y-sort) + **bina sprite'ları** üstte.
- Binalar **gelişim seviyesine göre görsel değişir** (kaynak: `map.txt` → "farklı yerleşim grafikleri gelişimi gösterir").
- **Dokunma:** binaya dokun → **bina detay paneli** (yükseltme, maliyet, süre, gereksinim).
- Üstte **kaynak çubuğu**: Odun / Taş / Demir + **Depo doluluk** göstergesi + **Vatandaş** (boş/toplam) + **Köy Puanı**.
- Altta **navigasyon**: Köy · Harita · Raporlar · Mesajlar · Menü.
- **Her zaman canlı:** üretim akışı, inşaat süresi geri sayımı, hareket animasyonu (ok/yol).

### 2.1 Gereksinim zinciri görünümü ⭐ (kullanıcının özel vurgusu)
Bina paneline girildiğinde **her zaman** şu üç durumdan biri net görünür:

| Durum | Görünüm |
|---|---|
| Yükseltilebilir | Yeşil **"Yükselt"** butonu + maliyet + süre |
| Önkoşul eksik | **"Önce şunlar gerekli:"** listesi — her satır `Bina → gereken seviye (şu an X)` + **kısayol butonu** |
| Kaynak yetersiz | Maliyet kırmızı, eksik miktar yazılı |

- Liste `RulesEngine.requirement_chain(buildings, key, level)` çıktısından üretilir → **sıralı (topolojik)**.
- Kullanıcı bir önkoşula dokunursa **o binanın paneline geçer** → zinciri adım adım yürüyebilir.
- Zincir tamamlandığında ana panel otomatik yeşile döner (canlı güncelleme `EventBus`).

### 2.2 Bina → sprite eşlemesi (ücretsiz varlıklar)
| Bina | Kaynak paketi | Not |
|---|---|---|
| Kale (`main`) | `isometric-tiles-city` + `miniature-dungeon` (kale kulesi) | en görkemli |
| Oduncu Kampı (`wood`) | `miniature-farm` (`woodWall*`, `roof`) | kit-bash |
| Taş ocağı (`stone`) | `miniature-dungeon` (taş duvar/kaya) | |
| Maden ocağı (`iron`) | `miniature-dungeon` (varil/sandık + taş) | |
| Depo (`storage`) | `isometric-tiles-buildings` (ambar) | |
| Gizli Depo (`hide`) | `miniature-dungeon` (sandık, gizli) | küçük |
| Değirmen (`farm`) | `miniature-farm` (`hayBales`) + `cartography/mill` | |
| Kışla (`barracks`) | `isometric-tiles-buildings` (kışla) | |
| Sur (`wall`) | `miniature-dungeon` (duvar/kapı) | seviyeye göre |
| Market (`market`) | `miniature-farm` (pazar tezgâhı) | |
| Katır çiftliği (`stable`) | `miniature-farm` (`fenceHigh`) | |
| Simyager (`garage`) | `miniature-library` (`bookcase*`) | |
| Köşk (`snob`) | `isometric-tiles-city` (konak) | |
| Kuyumcu (`smith`) | `board-game-icons/resource_*` + `isometric-blocks` | |
| Anıt (`statue`) | `isometric-tiles-city` (anıt) | tek seviye |

**Birim sprite'ları:** kullanıcı kararı → **özgün üretim** (11 birim). O gelene kadar
`cartography-pack`/`board-game-icons` **ikon** olarak kullanılır (UI'de ve haritada rozet).
> Ton/gölge: **Pastel rampalar** (`PALET.md` ışık/ana/gölge üçlüsü) — saf siyah gölge yok.

### 2.3 2.5D efekt katmanı
- Bina yerleşirken **toz bulutu** + hafif **zıplama**; tamamlanınca **parıltı**.
- Bina yükseltilirken **iskele** görseli.
- **Gündüz-gece** döngüsü (palet: şafak/altın saat/akşam/gece) + gece **pencere ışıkları**.
- Yağmur/kar (opsiyonel, sonra). Parçacıklar: `GPUParticles2D`.

---

## 3. Paneller (tam liste)

| Panel | İçerik | Kritik kural |
|---|---|---|
| **Bina detay** | Seviye, maliyet, süre, "Yükselt", **gereksinim zinciri**, "Yık" | Sıralı ilerleme (`can_upgrade_now`) |
| **İnşaat kuyruğu** | 3 ücretsiz slot + **ek maliyet %25/%56/%95…** gösterimi | Ek maliyet **açıkça** yazılmalı |
| **Kışla** | Araştırma (kilitli birimler + gereken Kışla seviyesi), eğitim (adet, süre, vatandaş) | Araştırma **tek seferlik** |
| **Köşk** | Kont eğitimi (**Altın Zırh** gerekli) | Zırh yoksa buton kilitli + açıklama |
| **Market** | Katır, kaynak takası | |
| **Kuyumcu** | Altın Zırh | |
| **Simyager** | Teknikler (listesi bilinmiyor → `known:false`) | Boş liste + "araştırılıyor" |
| **Dünya Haritası** | 200×200, renk kodları, miniharita, koordinat arama | Korumalı/korunmasız ayrımı |
| **Hareket gönderme** | Hedef koordinat, birlik seçimi, tahmini süre/varış, **min. birlik = 3×Kışla** uyarısı, **Kont ≤ 80 alan** | İhlalde buton kilitli + neden |
| **Raporlar** | Savaş (5 faz, moral/şans), casusluk, ticaret | Türkçe, `BattleReport` |
| **Mesajlar** | Sistem + oyuncu | Forum **yok** |
| **Puan/Sıralama** | Köy puanı, toplam puan, Güç Alanı | |
| **Ayarlar** | Dünya profili (TR/EN), hız, ses (müzik yok), dil (TR) | |

---

## 4. Dikey düzen ve dokunma

- **Temel çözünürlük:** 1080×1920 (portrait), `stretch=canvas_items`, `aspect=expand`.
- **Dokunma hedefi ≥ 88 px** (1080 genişlikte rahat).
- Paneller **alt sayfa (bottom sheet)** olarak açılır; geri jest/yukarı kaydırma ile kapanır.
- Güvenli alan (çentik/navbar) için `SafeArea` kenar boşlukları.
- Yazı tipi: **Nunito** (ana UI) · **Cinzel** (başlık/logo). Türkçe glifler doğrulandı.

---

## 5. Durum renkleri (kullanıcının renk kararıyla)

| Anlam | Renk |
|---|---|
| Ana marka / birincil buton | **Safir `#6E9BE8`** (hover `#8FB4F0`) |
| Başarı / yükseltilebilir | `#7ED957` |
| Uyarı / ek maliyet | `#F7C948` |
| Hata / eksik | `#F2705D` |
| Pasif / kilitli | `#D9E0EA` |
| Dost / kendi / nötr / düşman | `#6EC1E4` / `#7ED957` / `#C9C2B6` / `#F2705D` |
| Panel zemin / kenar | `#FFFDF7` / `#9A6437` (ahşap) |

---

## 6. Kabul kriterleri (A-ARAYUZ teslimi)

1. Boot → Ana Menü → Köy Ekranı akışı **çalışıyor**.
2. Bir bina yükseltilemiyorsa **neden yükseltilemediği** (eksik önkoşul/kaynak) **ekranda yazılı**.
3. **Gereksinim zinciri** listesi `requirement_chain`'den geliyor ve **sıralı**; tıklayınca ilgili binaya gidiyor.
4. İnşaat kuyruğunda **ek maliyet yüzdesi** görünüyor.
5. İnşaat tamamlanınca kaynak/puan **canlı** güncelleniyor (`EventBus`).
6. Harita: köy renkleri + koordinat arama + miniharita.
7. Hareket gönderirken **min. birlik** ve **Kont mesafesi** ihlali engelli.
8. Tüm metinler **resmî Türkçe** terimlerle (`docs/TERIMLER.md`).
9. `godot --headless --path .\game --quit-after 5` → **hata yok**.
10. Ana sahneler için **ekran görüntüsü** (headless `--quit-after` ile üretilemezse editörde) rapora eklenir.
