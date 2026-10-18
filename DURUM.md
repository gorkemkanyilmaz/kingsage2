# DURUM — Nerede Kaldık? (Devam Dosyası)

> 🔴 **SONRAKİ OTURUMDA ÖNCE BU DOSYAYI OKU.**
> Sonra sırayla: `README.md` → `docs/TERIMLER.md` → `TASKS.md`

**Son güncelleme:** 3. oturum sonu
**Proje:** King's Age mobil klonu (Godot, 2.5D) — **analiz + dokümantasyon + plan fazı**
**Kural:** Bu fazda **KOD YAZILMIYOR.** (Kod fazına geçiş kullanıcı onayına bağlı.)

---

## 1. Kullanıcının Kesin Talimatları (bağlayıcı)

1. **Doküman dili:** 🇹🇷 Türkçe.
2. **İngilizce terimleri KENDİM Türkçeleştirmeyeceğim.** Resmî Türkçe kaynaktan
   (`https://s59-tr.kingsage.gameforge.com/help.php`) alınacak → hepsi `docs/TERIMLER.md`'de.
3. **Forum kısmı hiç alınmayacak** (ittifak forumu, tüm forum özellikleri).
4. Araştırmada şu linkler **hariç**: Help, Forum, Logout, Rules, Legal, T&Cs, Privacy Policy, change-logs.
5. Her şeyi **sürekli logla**; sonraki oturum bu dosyadan devam edebilsin.
6. Nihai hedef: **Godot ile mobil**, **2.5D grafik**, mekanikler birebir, **isim ve görseller özgün**.
7. Çok oyunculu: **önce tek oyunculu (bot/AI)**, sonra online.

---

## 2. ✅ Tamamlanan İşler

### 2.1 Veri toplama
- 🇬🇧 **EN (s59-en):** 54 sayfa → `research/raw/*.html`, metinler → `research/text/*.txt`
- 🇹🇷 **TR (s59-tr):** 52 sayfa → `research/raw-tr/*.html`, metinler → `research/text-tr/*.txt`
- URL listeleri: `research/urls.txt`, `research/urls-tr.txt`

### 2.2 Yapısal veri (`data/`) — **TR kaynağından, resmî Türkçe adlarla**
- `data/buildings.json` — 15 binanın tam seviye tabloları
- `data/units.json` — 11 birim (detay + araştırma + eğitim + savaş tabloları)
- `data/building-points.json` — bina puan tablosu (kümülatif)

### 2.3 Referans dokümanlar — **TR kaynağından üretildi**
- `docs/reference/buildings/*.md` (15 + README) — başlıklar ve adlar Türkçe
- `docs/reference/units/*.md` (11 + README) — Türkçe
- `docs/reference/puan-tablosu.md` — Türkçe (tam gelişmiş köy = **10.000**)

### 2.4 Ana dokümanlar
| Dosya | Durum |
|---|---|
| `README.md` | ✅ |
| `docs/TERIMLER.md` | ✅ resmî TR terimler |
| `docs/00-PROJE-OZETI-VE-KARARLAR.md` | ✅ |
| `docs/01-KAYNAK-ANALIZI.md` | ✅ |
| `docs/02-OYUN-DONGUSU-VE-TERIMLER.md` | ✅ |
| `docs/03-KAYNAKLAR-VE-SETTLER.md` | ✅ |
| `docs/04-BINALAR.md` | ✅ |
| `docs/05-ASKERLER.md` | ✅ |
| `docs/06-SAVAS-SISTEMI.md` | ✅ |
| `docs/07-CASUSLUK.md` | ✅ |
| `docs/08-FETIH.md` | ✅ |
| `docs/09-KOMUTLAR-DESTEK-VE-YAGMA.md` | ✅ |
| `docs/10-HARITA-VE-DUNYA.md` | ✅ |
| `docs/11-OYUNCU-PUAN-KORUMA.md` | ✅ |
| `docs/12-ITTIFAKLAR.md` | ✅ (forum kaldırıldı) |
| `docs/13-PREMIUM.md` | ✅ |
| `docs/14-TICARET-VE-PAZAR.md` | ✅ **YENİ** |
| `docs/15-MATEMATIK-VE-FORMULLER.md` | ✅ **YENİ** |
| `docs/16-GODOT-MOBIL-PLANI.md` | ✅ **YENİ** |
| `docs/18-SANAT-VE-ISIMLENDIRME.md` | ✅ **YENİ** |
| `docs/17-KURALLAR.md` | ❌ kapsam dışı (kullanıcı kararı) |
| `TASKS.md` | ✅ |
| `DURUM.md` | ✅ (bu dosya) |

---

## 3. 🔄 Bu Oturumda Yapılan (3. oturum)

1. **`make-docs.ps1` TR uyumlu** hale getirildi (dilden bağımsız ayrıştırma:
   `Maksimum seviye`, `Gereksinimler`, `Giderler`, ikon tabanlı istatistik okuma, `def_cav.png` ile savaş tablosu).
2. Referans bina/birim dokümanları **TR kaynağından yeniden üretildi** (Türkçe açıklama + resmî adlar).
3. **`make-points.ps1` TR uyumlu**; puan tablosu Türkçe; **tam gelişmiş köy = 10.000** doğrulandı.
4. **`docs/14-TICARET-VE-PAZAR.md`** yazıldı (Market + Katır çiftliği tam tablolar).
5. **`docs/15-MATEMATIK-VE-FORMULLER.md`** yazıldı (maliyet/üretim/depo/vatandaş/sur/zaman faktörü eğrileri + açık sorular).
6. **`docs/16-GODOT-MOBIL-PLANI.md`** yazıldı (mimari + 2.5D + yol haritası).
7. **`docs/18-SANAT-VE-ISIMLENDIRME.md`** yazıldı (özgün isim önerileri + telif listesi).
8. Dokümanlarda **resmî TR terim hizalaması** yapıldı (Simyager, Köşk, Katır, Gizli Depo, Şahmerdan, Güç Alanı, Köy Puanı …).
9. `docs/12-ITTIFAKLAR.md` → **forum tamamen çıkarıldı**, "KAPSAM DIŞI" işaretlendi.

### ⚠️ Windows/PowerShell notu (tekrar keşfetmemek için)
- `.ps1` dosyalarına **UTF-8 BOM** eklenmezse PowerShell 5.1 dosyayı ANSI okur → Türkçe karakterler bozulur.
  BOM ekleme:
  ```powershell
  $enc = New-Object System.Text.UTF8Encoding($true)
  $p='research\make-docs.ps1'
  [System.IO.File]::WriteAllText($p,[System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8),$enc)
  ```
- `edit` aracı BOM'u düşürebilir → **düzenlemeden sonra BOM'u yeniden ekle**, sonra çalıştır.
- Konsolda `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`.

---

## 4. ⏳ Sıradaki Adımlar (öncelik sırasıyla)

### A. Dokümantasyon cilası (küçük)
1. `docs/05-ASKERLER.md` tablosundaki sütun başlıklarını (Wood/Stone/Iron → Odun/Taş/Demir) kontrol et.
2. `docs/06`, `docs/07`, `docs/13` içindeki İngilizce kalan başlıklı ifadeleri (varsa) TR'ye çevir.
3. `docs/00` §1 amaç/kapsam bloğunu okuyup güncel kararlarla hizala.

### B. Araştırma boşlukları (istemci doğrulaması) ⛔
> Bunlar yardım sitesinde **yok**; oyunu oynayarak/veri kazıyarak doğrulanmalı.
> Karar: MVP'de **parametrik** tutulacak.
- İnşaat süresi formülü (zaman faktörü × taban süre)
- Araştırma/eğitim süresi katsayısı
- Katır başına taşıma kapasitesi + katır yolculuk süresi
- Simyager teknik listesi (ad/maliyet/süre/etki)
- Altın zırh maliyet artış çarpanı
- Moral eğrisi (puan oranı → moral)
- Casusluk "hayatta kalan casus" formülü
- Şahmerdan/Mancınık hasar formülleri
- Üretimin vatandaş başına mı bina başına mı olduğu

### C. Kod fazına hazırlık (kullanıcı onayıyla)
4. Godot 4.x proje iskeleti (`16-GODOT-MOBIL-PLANI.md` §2)
5. Veri katmanı: `data/*.json` → `Resource`
6. MVP dikey dilim: köy + ekonomi + inşaat + basit savaş

---

## 5. 🔑 Kritik Teknik Bilgiler

| Konu | Bilgi |
|---|---|
| EN kaynak | `https://s59-en.kingsage.gameforge.com/help.php?m=...` |
| TR kaynak | `https://s59-tr.kingsage.gameforge.com/help.php?m=...` |
| Sürüm | 7.1.1 / 7.1.1-r1 |
| İçerik kapsayıcısı | `class="contentpane"` |
| Kaynak ikonları | `res1=Odun`, `res2=Taş`, `res3=Demir`, `worker=Vatandaş` |
| **HTML tablo sütun sırası** | **Taş, Odun, Demir** (JSON'da **Odun/Taş/Demir**'e çevrilir!) |
| Birim istatistik ikonları | `units/att.png`, `units/def.png`, `units/def_cav.png`, `units/def_archer.png` |
| Binler ayırıcı | `1.160` = 1160 |
| Rate-limit | Hızlı istekte sunucu "Tanıtım" döndürür → doğrulama + bekleme şart |
| PowerShell | `"$base?m=x"` hatası: `$($base)?...` veya `$base + '?m=' + $x` kullan |
| Git | `kingsage` klasörü **git deposu değil** |

### Türetilmiş eğriler (özet)
- **Bina maliyeti:** standart odun ×1,165 / taş ×1,170 / demir ×1,160;
  Kışla ×1,21/1,23/1,22; Köşk ×1,30; Kuyumcu ×1,40
- **Üretim:** `120 × 1,115^(sv−1)` → sv50 = 24.800/saat
- **Depo:** `1.000 × 1,150^(sv−1)` → sv50 = 950.000
- **Gizli Depo:** `150 × 1,19^(sv−1)` → sv30 = 23.278
- **Değirmen (maks. vatandaş):** `250 × 1,115^(sv−1)` → sv50 = 50.000
- **Katır üretimi:** `16 × 1,18^(sv−1)` → sv30 = 2.000/saat
- **Sur bonusu:** %105 → %220
- **Tam gelişmiş köy puanı:** **10.000**

### Dosya adı eşleşmeleri
- `research/raw(-tr)/buildings_details_<key>.html` — key ∈ {main, stone, wood, iron, storage, hide,
  farm, barracks, wall, stable, market, garage, snob, smith, statue}
- `research/raw(-tr)/units_details_<key>.html` — key ∈ {farmer, spear, sword, axe, bow, spy, light,
  heavy, ram, kata, snob}

---

## 6. 📌 Nasıl Devam Edilir (adım adım)

```powershell
# 1) Depoya gir
cd C:\Users\Gorkem\Desktop\kingsage

# 2) Durumu oku
#    -> DURUM.md (bu dosya), README.md, docs\TERIMLER.md, TASKS.md

# 3) Veri yeniden üretilecekse (TR kaynağından)
powershell -NoProfile -ExecutionPolicy Bypass -File 'research\make-docs.ps1'   -RawDir 'research\raw-tr' -DataDir 'data' -DocDir 'docs\reference'
powershell -NoProfile -ExecutionPolicy Bypass -File 'research\make-points.ps1'
#    NOT: düzenleme sonrası .ps1 dosyalarına UTF-8 BOM ekle (bkz. §3 notu)

# 4) Gerekiyorsa sayfa yeniden indirme
powershell -NoProfile -ExecutionPolicy Bypass -File 'research\fetch-tr.ps1' -ListFile 'research\urls-tr.txt' -From 1 -To 20
powershell -NoProfile -ExecutionPolicy Bypass -File 'research\html2text.ps1' -RawDir 'research\raw-tr' -TextDir 'research\text-tr'
```

**Sonraki oturumun ilk somut işi:** §4.A (küçük terim cilası) → sonra kullanıcıya
**kod fazına geçiş onayı** sor.

---

## 7. 📁 Depo Ağacı (özet)

```
kingsage/
├─ README.md                     ← ENTRY POINT
├─ DURUM.md                      ← BU DOSYA
├─ TASKS.md
├─ data/
│  ├─ buildings.json  units.json  building-points.json
├─ docs/
│  ├─ TERIMLER.md                ← RESMÎ TR TERİMLER
│  ├─ 00..18-*.md                ← ana dokümanlar
│  └─ reference/
│     ├─ buildings/*.md          ← 15 bina (TR)
│     ├─ units/*.md              ← 11 birim (TR)
│     └─ puan-tablosu.md
└─ research/
   ├─ raw/ (EN 54)   raw-tr/ (TR 52)
   ├─ text/ (EN 54)  text-tr/ (TR 52)
   ├─ urls.txt  urls-tr.txt
   └─ fetch-pages.ps1  fetch-tr.ps1  html2text.ps1  make-docs.ps1  make-points.ps1
```
