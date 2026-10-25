# DURUM — Nerede Kaldık? (Devam Dosyası)

> 🔴 **SONRAKİ OTURUMDA ÖNCE BU DOSYAYI OKU.**
> Sonra sırayla: `README.md` → `docs/TERIMLER.md` → `TASKS.md`

**Son güncelleme:** 9. oturum (UI YAZI & ÇİZGİ NETLİĞİ / CRISPNESS + AYARLAR HIZ SATIRI) — bkz. **`TASKS-GRAPHICS.md`** §Faz 8 & **`TASKS-CODE.md`**
**Proje:** **Taht ve Kılıç** — King's Age mobil klonu (Godot 4.7.2, dikey, 2.5D, Türkçe)
**Aşama:** 🟢 **Mobil UI & Etkileşim Fazı Tamamlandı** (%100 Başarılı Testler: test_village_pan_zoom 18/18, test_village_ui_flow 56/56, test_building_upgrades 67/67, test_player_agent 80/80, test_settings_nav PASS, test_all_scenes PASS).
- **Akıcı Zoom & Pan (Kaydırma):** Çift parmakla sıkıştırma (pinch-to-zoom), fare tekerleğiyle yakınlaşma (1.0x - 2.2x), tek parmakla serbest harita sürükleme ve kenar kenetleme eklendi.
- **Sürükleme vs Tıklama Ayrımı:** Mobilde haritayı kaydırırken binalara denk gelse dahi binaların kazara açılmasını önleyen hassas drag-threshold mekanizması kuruldu.
- **Yüzen Zoom Arayüzü (ZoomHUD):** Tek elle rahat kullanım için sağ üstte zarif `+`, `−` ve `⛶` (sıfırla/ortala) yüzen kontrol paneli eklendi.
- **Büyük ve Net Seviye Plaketleri:** 46x26'dan 70x36 piksele çıkarılan, 17px kalın fontlu, derin gölgeli ve yüksek kontrastlı zarif beyaz seviye kutucukları (`Sv. 1`, `Sv. 2`, `🔒`, `+`).
- **Modern Pastel Bottom Sheet (`BuildingPanel`):** 28px kavisli modern çekmece, üst tutma çubuğu (handle), 3'lü pastel maliyet kapsülleri (sage, terracotta, steel), pastel kartlı gereksinim zinciri ve zümrüt yükselt butonu.
- **Modern Pastel Üst Sekme (`ResourceBar`):** Cam/parşömen melez frosted zemin, kraliyet arması köy başlığı, hammadde kapsülleri (odun/taş/demir), yuvarlatılmış depo ve vatandaş sayaçları.
- **Modern Alt Navigasyon (`BottomNav`):** Kavisli üst kenarlı, altın ışıltılı aktif pill kapsüllü modern alt bar.
- **8. oturum — Harita Kartografyası:** Yeni `scenes/map/WorldDecor.gd` nehirler, göller, orman adacıkları, dağ sırtları ve serpiştirilmiş ağaç/kayalarla düz parşömeni gerçek bir Orta Çağ haritasına çevirdi (tek `_draw()` → mobil dostu, sabit tohum).
- **8. oturum — Harita HUD:** Yeni `scenes/map/MapRuler.gd` çerçeve, canlı koordinat cetveli, kenar vinyeti ve "Bölge X | Y" rozeti ekledi; başlık Cinzel serif, X/Y kutuları ve "Git" düğmesi yeniden stillendi; `MapVillageView`'daki opak buton gölgesi (cream square) giderildi.
- **8. oturum — Ortak Atmosfer:** Yeni `ui/Backdrop.gd` ile tüm menü/panel ekranlarına parşömen dokusu, aquarelle lekeleri, kenar vinyeti ve arma filigranı.
- **8. oturum — Ekran Kartları:** Ana Menü / Köy Seçim / Ayarlar kart (plaque) düzeni + Cinzel başlıklar; Sıralama'da altın/gümüş/bronz madalya + oyuncu vurgusu; Raporlar'da tür renkli kartlar + boş-durum görünümü.
- **8. oturum — Araç:** `tools/capture_screens.gd` 8 ekranı (kaydırılmış harita dahil) `screenshots/`'a yakalıyor; `screenshots/` git dışında. 14 test paketi + `test_all_scenes` → tamamı PASS.
- **9. oturum — Yazı & Çizgi Netliği (MSDF):** 540×960 pencere / 1080×1920 tasarım yarı ölçek küçültmesinden doğan "bulanıklık" giderildi; kullanılan 4 tema fontu (`Nunito-Regular/Bold/SemiBold`, `Cinzel-Bold`) `multichannel_signed_distance_field=true` + `msdf_size=64` (mesafe alanı → her ölçekte net glif). Küçük yazılar büyütüldü: köy üst çubuğu (24–28), bina paneli (24–32), alt nav 22, kuyruk HUD 22/20, harita lejantı 20 + cetvel 24 + köy jetonu 18, Ayarlar etiketleri 26.
- **9. oturum — Ayarlar hız satırı:** SpinBox okları gizlenip yerine net `−` / `+` düğmeleri, ortalanmış 30 px rakamlar; `OptionButton`/`PopupMenu` parşömen temaları (chevron oku + gölgeli panel) ve tema artık `project.godot` üzerinden global uygulanıyor.
- **9. oturum — Regresyon:** `test_all_scenes` + 15 test dosyası (army 66, bot 20, economy 126, integration 26, rules 159, save 18, village_ui_flow 56, building_upgrades 67, player_agent 80, pan_zoom 18, settings_nav, actions, battle, world) → **tamamı EXIT=0**.

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

## 3. 🟢 KODLAMA FAZI (4. oturum — güncel)

> **Canlı görev panosu: `TASKS-CODE.md`** ← tüm görevler + durumları burada. Her biten iş ✅ Tamamlandı işaretlenir.

### 3.1 Onaylanan kararlar (kullanıcı)
| Konu | Karar |
|---|---|
| Oyun adı | **Taht ve Kılıç** |
| Motor | **Godot 4.7.2-stable** (portable, `tools/godot/`) |
| Ekran | **Dikey (Portrait)**, 1080×1920 |
| Dil | **Sadece Türkçe** (resmî KingsAge TR terimleri) |
| Premium/Kron | **Sonraki faz** |
| Online | **Sonraki faz** (önce tek oyunculu + bot) |
| Sanat | **Ücretsiz CC0/OFL** varlıklar, **pastel & canlı** palet |
| Git | ✅ başlatıldı (`git init`, ilk commit `435b2b0`) |
| Godot kurulumu | ✅ indirildi + doğrulandı (`4.7.2.stable.official.ed1daf0bf`) |
| Varsayılan oyun hızı | **1× birebir** (KingsAge süreleri aynen; hız = sunucu ayarı) |
| Dünya ölçeği | **~200×200, ~100 bot köyü** (KingsAge 1000×1000'in mobil uyarlaması) |
| İlerleme yapısı | **Sonsuz kum havuzu** (kazanma koşulu yok) |

### 3.2 Kurulan altyapı
- Depo **git deposu** oldu. `.gitignore`: Godot çıktıları, `tools/` ve **telifli araştırma ham metinleri** (`research/raw*/`, `research/text*/`) hariç.
- Klasör ağacı: `game/{autoload,data/rules,resources,scripts/{core,rules,sim,world,ai,ui},scenes/{boot,village,map,ui,battle},assets/{sprites,fonts,audio},tests}`
- `data/*.json` → `game/data/` kopyalandı.
- **Ajan kadrosu** ve dosya sahipliği `TASKS-CODE.md` §1'de.

### 3.3 Çalışan ajanlar (1. dalga — arka planda)
| Ajan | Kapsam | Dosya sahipliği |
|---|---|---|
### 3.3 Ajan Kadrosu ve Tamamlanan Fazlar (TÜM FAZLAR TAMAMLANDI)
| Faz | Ajan | Kapsam | Durum | Kanıt |
|---|---|---|---|---|
| **FAZ 1** | A-ŞEF | Git altyapısı, Godot 4.7.2 taşınabilir kurulum | ✅ Tamamlandı | Git init, `tools/godot/` 4.7.2 |
| **FAZ 2** | A-HALKA | Foundation, Autoloads, EventBus, GameClock, SaveManager | ✅ Tamamlandı | Headless boot EXIT=0 |
| **FAZ 3** | A-KURAL | Kural motoru JSON tabloları, DAG, validate_rules.py | ✅ Tamamlandı | 117/117 kural kontrolü |
| **FAZ 3b** | A-MOTOR | RulesEngine.gd, VillageModel.gd | ✅ Tamamlandı | `test_rules.gd` 159/159 PASS |
| **FAZ 4** | A-VARLIK | CC0/OFL sprite'lar (18 paket) ve 8 font ailesi | ✅ Tamamlandı | `ASSET-MANIFEST.md`, `PALET.md` |
| **FAZ 5** | A-EKONOMI | Üretim, depo, kuyruk ek maliyeti, iptal iadesi | ✅ Tamamlandı | `test_economy.gd` 126/126 PASS |
| **FAZ 6** | A-ORDU | Araştırma, eğitim, Altın Zırh, Kont | ✅ Tamamlandı | `test_army.gd` 66/66 PASS |
| **FAZ 7** | A-SAVAS | 5 fazlı savaş simülasyonu, Türkçe savaş raporu | ✅ Tamamlandı | `test_battle.gd` 50/50 PASS |
| **FAZ 8** | A-KESIF | Casusluk, fetih, destek, talan, 10:1 Kanun Kaçağı | ✅ Tamamlandı | `test_actions.gd` 105/105 PASS |
| **FAZ 9** | A-DUNYA | 200×200 dünya modeli, 4 kıta, bonus ve soyguncular | ✅ Tamamlandı | `test_world.gd` 152/152 PASS |
| **FAZ 10** | A-ARAYUZ | Pastel tema, 2.5D izometrik köy, tüm UI panelleri | ✅ Tamamlandı | `game/ui/UI-RAPORU.md` (10 Kriter) |
| **FAZ 11** | A-BOT | Yapay zeka botları (ekonomi, ordu, talan, kişilikler) | ✅ Tamamlandı | `test_bot.gd` 20/20 PASS |
| **FAZ 12** | A-QA | Save/load, 30 gün offline telafi, entegrasyon | ✅ Tamamlandı | `test_save` 18/18, `test_integration` 26/26 |

---

## 4. 📊 Test ve Kalite Güvence Durumu

Toplam **742 / 742 assertion %100 PASS (EXIT 0)**:
- `validate_rules.py`: **117** kontrol PASS
- `test_rules.gd`: **159** PASS
- `test_world.gd`: **152** PASS
- `test_economy.gd`: **126** PASS
- `test_actions.gd`: **105** PASS
- `test_army.gd`: **66** PASS
- `test_battle.gd`: **50** PASS
- `test_integration.gd`: **26** PASS
- `test_bot.gd`: **20** PASS (100 bot × 30 gün simülasyonu ~47 sn)
- `test_save.gd`: **18** PASS

---

## 5. 🔑 Kritik Teknik Bilgiler ve Çalıştırma

### Godot ile Oyunu Başlatma:
```powershell
# Konsol üzerinden çalıştırma:
.\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path .\game

# Headless modda test çalıştırma:
.\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path .\game --script res://tests/test_integration.gd
```

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

**Sonraki oturumun ilk somut işi:** `TASKS-CODE.md`'deki **🔄 Devam Ediyor / ⏳ Bekliyor** görevlere bak →
tamamlananları doğrula → 2. dalga ajanlarını (A-EKONOMI, A-ORDU, A-SAVAS, A-KESIF, A-DUNYA) başlat.

---

## 7. 📁 Depo Ağacı (özet)

```
kingsage/
├─ README.md                     ← ENTRY POINT
├─ DURUM.md                      ← BU DOSYA
├─ TASKS.md                      ← analiz/doküman görevleri
├─ TASKS-CODE.md                 ← 🔴 KODLAMA GÖREV PANOSU (canlı)
├─ .gitignore
├─ data/                         ← kaynak yapısal veri
│  ├─ buildings.json  units.json  building-points.json
├─ game/                         ← 🎮 GODOT PROJESİ
│  ├─ project.godot              ← A-HALKA
│  ├─ icon.svg
│  ├─ autoload/                  ← EventBus, GameConfig, GameData, GameState, GameClock, SaveManager
│  ├─ data/                      ← buildings.json, units.json, building-points.json, rules/
│  ├─ resources/
│  ├─ scripts/{core,rules,sim,world,ai,ui}/
│  ├─ scenes/{boot,village,map,ui,battle}/
│  ├─ assets/{sprites,fonts,audio}/   ← A-VARLIK
│  └─ tests/
├─ tools/                        ← (git ignore) Godot binary + validate_rules.py
├─ docs/                         ← TERIMLER.md + 00..18 + reference/
└─ research/                     ← script'ler + urls (ham metinler git ignore)
```
