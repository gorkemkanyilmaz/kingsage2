# TASKS-CODE.md — Kodlama Görev Panosu (Taht ve Kılıç)

> **Durum simgeleri:** ⏳ Bekliyor · 🔄 Devam Ediyor · ✅ **Tamamlandı** · ⛔ Bloke · ❓ Karar Bekliyor
> **Kural:** Her iş bu panoya **görev olarak** yazılır; bitince durumu **✅ Tamamlandı** yapılır ve
> altına kısa bir **kanıt** (dosya/komut/çıktı) eklenir. Böylece bağlam hiç kopmaz.
> **Devam dosyası:** `DURUM.md` (önce o okunur). **Sözleşme/terimler:** `docs/TERIMLER.md`.

---

## 0. Proje Kararları (onaylı)

| Konu | Karar |
|---|---|
| Oyun adı | **Taht ve Kılıç** |
| Motor | **Godot 4.7.2-stable** (portable, `tools/godot/`) |
| Platform | iOS + Android (öncelik), dikey (Portrait) 1080×1920 |
| Dil | **Sadece Türkçe** (resmî KingsAge TR terimleri) |
| Premium/Kron | **Sonraki faz** |
| Online | **Sonraki faz** (önce tek oyunculu + bot) |
| Kurallara bağlılık | **%100** — süreler, maliyetler, gereksinim zinciri birebir |
| Sanat | **Ücretsiz (CC0/OFL)** assetler + pastel & canlı palet |

---

## 1. Ajan Kadrosu (Agent Roster)

| Kod | Ajan | Sorumluluk alanı (dosya sahipliği) |
|---|---|---|
| **A-HALKA** | Foundation | `game/project.godot`, `game/autoload/**`, `game/scripts/core/**`, `game/scenes/boot/**`, `game/icon.svg` |
| **A-KURAL** | Kural Motoru Verisi | `game/data/rules/**`, `tools/validate_rules.py` |
| **A-MOTOR** | Kural Motoru (kod) + köy modeli | `game/scripts/rules/**`, `game/scripts/model/**` |
| **A-VARLIK** | Varlık (Asset) | `game/assets/**` (+ `ASSET-MANIFEST.md`) |
| **A-EKONOMI** | Ekonomi & Binalar | `game/scripts/sim/economy/**`, `game/scripts/sim/buildings/**` |
| **A-ORDU** | Ordu & Eğitim | `game/scripts/sim/army/**` |
| **A-SAVAS** | Savaş Simülatörü | `game/scripts/sim/battle/**` |
| **A-KESIF** | Casusluk/Fetih/Destek/Talan | `game/scripts/sim/actions/**` |
| **A-DUNYA** | Dünya & Harita | `game/scripts/world/**`, `game/scenes/map/**` |
| **A-ARAYUZ** | UI & 2.5D Köy | `game/scripts/ui/**`, `game/scenes/village/**`, `game/scenes/ui/**` |
| **A-BOT** | Bot / AI | `game/scripts/ai/**` |
| **A-QA** | Test & Doğrulama | `game/tests/**` |

> **Çakışma önleme:** Her ajan **yalnızca kendi klasörüne** yazar. Ortak dosya (`project.godot`) yalnızca **A-HALKA**'ya aittir.

---

## FAZ 1 — Altyapı

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-1.1 | `git init` + `.gitignore` + ilk commit | A-ŞEF (ana) | ✅ Tamamlandı |
| T-1.2 | Godot 4.7.2 portable indir/kur (`tools/godot/`) | A-ŞEF | ✅ Tamamlandı |
| T-1.3 | Proje klasör ağacı + `game/data/*.json` kopyası | A-ŞEF | ✅ Tamamlandı |
| T-1.4 | Kodlama görev panosu (`TASKS-CODE.md`) | A-ŞEF | ✅ Tamamlandı |

## FAZ 2 — Halka (Foundation) — *kritik yol* ✅

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-2.1 | `project.godot`: ad, dikey 1080×1920, gl_compatibility, autoload kayıtları | A-HALKA | ✅ Tamamlandı |
| T-2.2 | `EventBus.gd`: global sinyaller | A-HALKA | ✅ Tamamlandı |
| T-2.3 | `GameData.gd`: `data/*.json` + `rules/*.json` → sözlük + sorgu API | A-HALKA | ✅ Tamamlandı |
| T-2.4 | `GameConfig.gd`: sunucu ayarları (JSON yükle/kaydet) | A-HALKA | ✅ Tamamlandı |
| T-2.5 | `GameState.gd`: kök durum + serileştirme | A-HALKA | ✅ Tamamlandı |
| T-2.6 | `GameClock.gd`: tick + **offline hızlı-ileri** | A-HALKA | ✅ Tamamlandı |
| T-2.7 | `SaveManager.gd`: `user://` kaydet/yükle + `saveVersion` | A-HALKA | ✅ Tamamlandı |
| T-2.8 | `scenes/boot/Boot.tscn` + `Boot.gd` | A-HALKA | ✅ Tamamlandı |
| T-2.9 | `icon.svg` (özgün, pastel) | A-HALKA | ✅ Tamamlandı |
| T-2.10 | **Doğrulama:** `godot --headless` → hata yok | A-HALKA + A-ŞEF | ✅ Tamamlandı |
| T-2.11 | `GameData` sayısal alanları yüklerken **int'e çevir** (KingsAge tamsayı matematiği) | A-HALKA | ✅ Tamamlandı |
| T-2.12 | `GameClock` yalnızca **aktif köy varsa** tick ilerletsin | A-HALKA | ✅ Tamamlandı |
| T-2.13 | `world-profiles.json` (tr/en) + `GameConfig.apply_profile()` | A-HALKA | ✅ Tamamlandı |
| T-2.14 | Varsayılan hızı **1**'e çek (kullanıcı kararı) + doğrula | A-ŞEF | ✅ Tamamlandı |

> **Kanıt (A-ŞEF bağımsız doğrulaması):**
> `Godot_v4.7.2-stable_win64_console.exe --headless --path .\game --quit-after 5` → `EXIT=0`
> `[Boot] Veri katmanı hazır — 15 bina yüklendi.` / `Bina: 15 · Birim: 11 · Puan tablosu: 50 seviye · Kural dosyası: 6`

## FAZ 3 — Kural Motoru (Rules Engine) ✅ — *gereksinim zinciri burada*

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-3.1 | `game/data/rules/requirements.json`: **gereksinim DAG'ı** | A-KURAL | ✅ Tamamlandı |
| T-3.2 | `game/data/rules/costs.json`: büyüme faktörleri + temel maliyetler | A-KURAL | ✅ Tamamlandı |
| T-3.3 | `game/data/rules/production.json`: üretim/depo/gizli depo/değirmen/katır/sur eğrileri | A-KURAL | ✅ Tamamlandı |
| T-3.4 | `game/data/rules/time-factors.json`: zaman faktörü serileri + kuyruk ek maliyeti | A-KURAL | ✅ Tamamlandı |
| T-3.5 | `game/data/rules/battle.json`: savaş sabitleri + 5 faz | A-KURAL | ✅ Tamamlandı |
| T-3.6 | `game/data/rules/units.json`: birim araştırma/eğitim gereksinimleri | A-KURAL | ✅ Tamamlandı |
| T-3.7 | `tools/validate_rules.py`: DAG + referans + tablo doğrulaması | A-KURAL | ✅ Tamamlandı |
| T-3.8 | `game/data/rules/README.md`: şema sözleşmesi | A-KURAL | ✅ Tamamlandı |

> **Kanıt:** `python tools/validate_rules.py` → **117 kontrol / 117 başarılı / 0 hata, exit 0** (A-ŞEF bağımsız çalıştırdı).
> **Negatif testler:** 7 kusur enjekte edildi (döngü, yanlış faktör, seviye>maks, bozuk tablo, …) → hepsi `exit 1` (doğrulayıcı gerçekten yakalıyor).
> **🔎 Yeni bulgu:** Demir büyüme faktörü iki gruptur → **çekirdek binalar 1,165 / diğer standart binalar 1,160**. `docs/15` düzeltildi.

## FAZ 3b — Kural Motoru (kod) + Köy Modeli — A-MOTOR ✅

| ID | Görev | Durum |
|---|---|---|
| T-3b.1 | `RulesEngine.gd` — maliyet + gereksinim sorguları | ✅ Tamamlandı |
| T-3b.2 | `RulesEngine` — üretim/kapasite/nüfus/sur/puan | ✅ Tamamlandı |
| T-3b.3 | `RulesEngine` — birim sorguları | ✅ Tamamlandı |
| T-3b.4 | `game/scripts/rules/ASSUMPTIONS.md` (7 bilinmeyen) | ✅ Tamamlandı |
| T-3b.5 | `VillageModel.gd` | ✅ Tamamlandı |
| T-3b.6 | `game/tests/test_rules.gd` — maliyet birebirliği | ✅ Tamamlandı |
| T-3b.7 | **Sözleşme düzeltmeleri:** `researched` durumu, `can_upgrade_now`, `unit_speed` float | 🔄 Devam Ediyor |

> **Kanıt (A-ŞEF bağımsız çalıştırdı):** `godot --headless --script res://tests/test_rules.gd` → **126/126 PASS, EXIT=0**.
> **En kritik kanıt:** `cost()` == `data/buildings.json` → **15 bina × 461 seviye × 3 kaynak = 1383 kontrol, hata 0**.
> `requirement_chain` topolojik ve eksiksiz (Anıt = 15 düğüm). Tam gelişmiş köy = **10000** puan.

## FAZ 4 — Varlıklar (Assets) ✅

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-4.1 | CC0/OFL pastel & canlı paketler (18 Kenney + 8 font ailesi) | A-VARLIK | ✅ Tamamlandı |
| T-4.2 | Türkçe destekleyen ücretsiz fontlar (OFL) — 19/19 font `ç ğ ı İ ö ş ü` doğrulandı | A-VARLIK | ✅ Tamamlandı |
| T-4.3 | `game/assets/` düzeni + `ASSET-MANIFEST.md` + `licenses/` (29 lisans metni) | A-VARLIK | ✅ Tamamlandı |
| T-4.4 | `game/assets/PALET.md` (pastel & canlı palet) | A-VARLIK | ✅ Tamamlandı |

> **Kanıt (A-ŞEF doğrulaması):** 9.494 dosya / **50,4 MB**; `licenses/KENNEY` 21 + `licenses/FONTS-OFL` 8 lisans metni; tüm dosya adları ASCII; Gameforge kaynaklı 0 dosya.

## FAZ 5 — Ekonomi & Bina Simülasyonu — ✅ Tamamlandı (A-EKONOMI)

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-5.1 | Hammadde üretimi (saatlik) + Depo tavanı + taşma | A-EKONOMI | ✅ Tamamlandı |
| T-5.2 | Vatandaş sistemi (boş/çalışan, Değirmen tavanı) | A-EKONOMI | ✅ Tamamlandı |
| T-5.3 | İnşaat kuyruğu (3 iş ücretsiz + ek maliyet) + süre | A-EKONOMI | ✅ Tamamlandı |
| T-5.4 | Gereksinim doğrulama (sıralı ilerleme + zincir) | A-EKONOMI | ✅ Tamamlandı |
| T-5.5 | Binayı yık (Kale Lv15 + Simyager tekniği) | A-EKONOMI | ✅ Tamamlandı |
| T-5.6 | Puan hesaplama + Köy Puanı + Toplam Puan (2.500/ek köy) | A-EKONOMI | ✅ Tamamlandı |
| T-5.7 | Güç Alanı döngüsü (saatlik %1 artış, saldırı düşüşü, fetih %30) | A-EKONOMI | ✅ Tamamlandı |
| T-5.8 | `GameLoop.gd` — **§7b sim modül protokolü** (tick → olaylar → EventBus) | A-EKONOMI | ✅ Tamamlandı |
| T-5.9 | **İptalde iade düzeltmesi:** taban maliyet iade, **ek maliyet iade DEĞİL** | A-EKONOMI | 🔄 Devam Ediyor |

> **Kanıt (A-ŞEF bağımsız çalıştırdı):** `godot --headless --script res://tests/test_economy.gd` → **108/108 PASS, EXIT=0**.
> Doğrulananlar: 1 saat üretim + depo tavanı · 100 küçük tick ≈ 120 (kayan-nokta telafisi) · kuyruk ek maliyeti %25/%56/%95 ·
> sıralı `can_upgrade_now` · gereksinim ihlali reddi (Kışla ← Depo 3 + Değirmen 3) · **30 gün offline hızlı-ileri çökme yok** ·
> Güç Alanı %1/saat + tavan/kırpma/fetih %30 · tam gelişmiş köy = 10000 · `GameLoop` modül yükleme + EventBus köprüsü.
>
> ⚠️ **A-ŞEF düzeltmesi:** Görev metnimde "iptalde iade yok" **yanlıştı**. Kaynak (`buildings.txt`): taban maliyet **iade edilir**,
> kuyruk ek maliyeti **iade edilmez**. `docs/19` §3.2 güncellendi, T-5.9 ile düzeltiliyor.

## FAZ 6 — Ordu & Eğitim — ✅ Tamamlandı (A-ORDU)

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-6.1 | Birim araştırma (Kışla seviyeleri + kuyruk + `researched`) | A-ORDU | ✅ Tamamlandı |
| T-6.2 | Birim eğitimi (maliyet + vatandaş + süre) | A-ORDU | ✅ Tamamlandı |
| T-6.3 | Birim kovma (dismiss) + vatandaş iadesi | A-ORDU | ✅ Tamamlandı |
| T-6.4 | Altın Zırh (Kuyumcu) + Kont eğitimi (Köşk) | A-ORDU | ✅ Tamamlandı |
| T-6.5 | Ordu limitleri (min. saldırı birimi = 3 × Kışla) | A-ORDU | ✅ Tamamlandı |
| T-6.6 | Bonus köy "eğitim" etkisi (+%10 hızlı → ×0,90) | A-ORDU | ✅ Tamamlandı |
| T-6.7 | `ArmySimulator.gd` — **§7b** protokol (kaynak dosya adı sözleşmeye birebir) | A-ORDU | ✅ Tamamlandı |

> **Kanıt (A-ŞEF bağımsız çalıştırdı):** `godot --headless --script res://tests/test_army.gd` → **66/66 PASS, EXIT=0**.
> Diğer testler etkilenmedi (`test_rules` 159, `test_world` 152, `test_battle` 50 → hepsi EXIT=0).
> Doğrulananlar: Kışla kapısı (Okçu 5) · `researched` tek seferlik · vatandaş rezervi + iade ·
> `min_attack_units` · Kont yalnız Köşk + **Altın Zırh** ile · `training` bonuslu köyde süre ×0,90.
> **Not:** "Araştırma/eğitim" içeriği `docs/05-ASKERLER.md`'dedir (`docs/07` = **casusluk**).

## FAZ 7 — Savaş Simülatörü (5 faz) ✅

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-7.1 | Faz 1: **Sura zarar** (Şahmerdan) | A-SAVAS | ✅ Tamamlandı |
| T-7.2 | Faz 2: **Casus Saldırısı** | A-SAVAS | ✅ Tamamlandı |
| T-7.3 | Faz 3: **Normal Asker Saldırısı** (moral + şans + sur + gece + Anıt) | A-SAVAS | ✅ Tamamlandı |
| T-7.4 | Faz 4: **Binalara zarar** (Mancınık) | A-SAVAS | ✅ Tamamlandı |
| T-7.5 | Faz 5: **Fetihler ve Yağma** (Gizli Depo, Kont, Güç Alanı) | A-SAVAS | ✅ Tamamlandı |
| T-7.6 | Deterministik (tohumlu) + **Savaş Raporu** (Türkçe) | A-SAVAS | ✅ Tamamlandı |
| T-7.7 | `ASSUMPTIONS.md` — 6 bilinmeyen formül belgelendi | A-SAVAS | ✅ Tamamlandı |

> **Kanıt (A-ŞEF bağımsız çalıştırdı):** `godot --headless --script res://tests/test_battle.gd` → **50/50 PASS, EXIT=0**.
> Doğrulananlar: aynı tohum → aynı sonuç · sur ↑ → savunan kaybı ↓ · gece → savunan kaybı ↓ · moral daima %30–%100 ·
> ganimet ≤ kapasite ve ≤ hedef hammadde · Gizli Depo korur · min. birlik 3×Kışla · Kont fetih koşulu (Anıt 1750–2250, talanda fetih yok).

## FAZ 8 — Casusluk / Fetih / Destek / Talan — 🔄 Devam Ediyor (A-KESIF)

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-8.1 | Normal + gizli casus saldırısı (gizli = 3× yavaş) | A-KESIF | 🔄 Devam Ediyor |
| T-8.2 | Casusluk raporu + bilgi kademeleri + Gizli Depo etkisi | A-KESIF | 🔄 Devam Ediyor |
| T-8.3 | Destek (kendi/dost köye birlik gönderme) | A-KESIF | 🔄 Devam Ediyor |
| T-8.4 | Talan (taşıma kapasitesi + gizli depo sınırı) | A-KESIF | 🔄 Devam Ediyor |
| T-8.5 | Fetih (Kont + güç alanı 0) + fetih koruması | A-KESIF | 🔄 Devam Ediyor |
| T-8.6 | Saldırı/destek/ticaret **iptal** kuralları (30/15 dk) | A-KESIF | 🔄 Devam Ediyor |
| T-8.7 | **10:1 oran** → Kanun Kaçağı (ceza 2 ay) + min. birlik kapısı | A-KESIF | 🔄 Devam Ediyor |
| T-8.8 | `ActionSimulator.gd` — **§7b** varış çözümleme + dönüş hareketleri | A-KESIF | 🔄 Devam Ediyor |

## FAZ 9 — Dünya & Harita ✅

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-9.1 | Dünya ızgarası — **karar: ~200×200, ~100 bot köyü**, kıta **100×100 (4 kıta)** | A-DUNYA | ✅ Tamamlandı |
| T-9.2 | Köy yerleşimi (yön), bonus köyler (6 resmî tip + 'Usta'), terkedilmiş köyler (soyguncular) | A-DUNYA | ✅ Tamamlandı |
| T-9.3 | Miniharita + komşu/ittifak renkleri | A-DUNYA | ✅ Tamamlandı |
| T-9.4 | Yolculuk süresi hesabı (mesafe + en yavaş birim + `unit_speed`) | A-DUNYA | ✅ Tamamlandı |
| T-9.5 | **Kaynak düzeltmeleri:** 6 bonus tipi, soyguncu ordusu, `realm=points` | A-DUNYA | ✅ Tamamlandı |

> **Kanıt (A-ŞEF bağımsız çalıştırdı):** `godot --headless --script res://tests/test_world.gd` → **152/152 PASS, EXIT=0**;
> `test_rules.gd` → **159/159 PASS** (çapraz uyum).
> Örnek dünya (tohum 4242): 210 köy (100 bot + 100 soyguncu + 10 bonus), 4 kıta, **6 bonus tipinin tamamı** üretiliyor,
> soyguncu garnizonları Kışla seviyesiyle uyumlu, `realm_of_power == points` değişmezi tüm köylerde sağlanıyor,
> süreçten bağımsız sabit hash `dd986b0a…`. `POINTS_PER_LEVEL` tablosu `building-points.json` ile **bina×seviye tam çapraz** doğrulandı.

> **Kanıt (A-ŞEF bağımsız çalıştırdı):** `godot --headless --script res://tests/test_world.gd` → **107/107 PASS, EXIT=0**.
> Örnek dünya (tohum 4242): 210 köy (100 bot + 100 terkedilmiş + 10 bonus), 4 kıta, 20×20 miniharita, süreçten bağımsız sabit hash.

## FAZ 10 — UI & 2.5D — 📋 Tasarım sözleşmesi hazır (`docs/20-ARAYUZ-TASARIMI.md`)

> 🔴 A-ARAYUZ bu dosyayı **bağlayıcı** kabul eder: ekran akışı, panel listesi, bina→sprite eşlemesi,
> durum renkleri ve **10 kabul kriteri** orada tanımlı.

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-10.1 | UI teması (pastel & canlı) + fontlar (Nunito/Cinzel) + ortak kontroller | A-ARAYUZ | ⏳ Bekliyor |
| T-10.2 | Kale menüsü + bina panelleri + **gereksinim zinciri görünümü** ⭐ | A-ARAYUZ | ⏳ Bekliyor |
| T-10.3 | Kışla paneli (araştır/eğit/kov) + Köşk (Altın Zırh) + Market/Kuyumcu | A-ARAYUZ | ⏳ Bekliyor |
| T-10.4 | 2.5D izometrik köy ekranı (TileSet + sprite + Y-sort + parçacık) | A-ARAYUZ | ⏳ Bekliyor |
| T-10.5 | Harita ekranı + emir gönderme akışı (min. birlik / Kont mesafesi kapıları) | A-ARAYUZ | ⏳ Bekliyor |
| T-10.6 | Rapor/Mesaj/Sıralama/Ayarlar ekranları | A-ARAYUZ | ⏳ Bekliyor |
| T-10.7 | Ana Menü + Yön/Köy seçimi + `GameLoop` sahneye bağlama | A-ARAYUZ | ⏳ Bekliyor |

## FAZ 11 — Bot / AI

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-11.1 | Ekonomi botu (üretim/bina dengesi) | A-BOT | ⏳ Bekliyor |
| T-11.2 | Askerî bot (keşif, hedef seçimi, savunma) | A-BOT | ⏳ Bekliyor |
| T-11.3 | Zorluk seviyeleri + kişilik | A-BOT | ⏳ Bekliyor |

## FAZ 12 — Kaydet/Yükle, Test, Denge

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-12.1 | Kaydet/yükle + offline telafi doğrulaması | A-QA | ⏳ Bekliyor |
| T-12.2 | Kural doğrulama testleri (maliyet/süre/gereksinim) | A-QA | ⏳ Bekliyor |
| T-12.3 | Savaş simülatörü birim testleri | A-QA | ⏳ Bekliyor |
| T-12.4 | Ekonomi dengesi simülasyonu (ör. 30 günlük ilerleme) | A-QA | ⏳ Bekliyor |

## FAZ 13/14 — (Sonra) Premium & Online
> Kullanıcı kararı: **şimdilik kapsam dışı.**

---

## 🔧 Teknik Kararlar (A-HALKA'nın 6 sorusuna yanıt — A-ŞEF)

| # | Soru | Karar |
|---|---|---|
| 1 | Autoload adları (`GameConfig` vs `ConfigService`) | **`GameConfig`/`GameData`/`GameState`/`GameClock`/`SaveManager`/`EventBus` geçerlidir.** `docs/16` hizalandı. |
| 2 | JSON sayıları float mı int mi? | **`GameData` yüklerken tamsayı alanları `int`'e çevirir** (KingsAge tamsayı matematiği). → T-2.11 |
| 3 | Kayıt/ayar dosya yolları | Onaylandı: `user://taht_ve_kilic_save.json`, `user://taht_ve_kilic_config.json` |
| 4 | Oyun saati ne zaman başlar? | Saat **yalnızca aktif köy varken** tick ilerletir. → T-2.12 |
| 5 | Dünya profili (TR/EN) | **İki hazır profil** (TR varsayılan: gece bonusu 00–06, Kont 80 / EN: gece kapalı, Kont 100); ilk açılışta seçim ekranı **yok**, ayarlardan değiştirilebilir. |
| 6 | `EventBus` sinyal adları sözleşme mi? | **Evet.** Mevcut sinyaller **yeniden adlandırılamaz**; ajanlar **yeni** sinyal ekleyebilir. |

---

## 🔬 Açık Araştırma Soruları (kural setinde `known:false`)

| # | Bilinmeyen | Nerede işaretli |
|---|---|---|
| 1 | İnşaat/araştırma/eğitim **süre formülü** (zaman faktörü × taban) | `time-factors.json#unresolved` |
| 2 | **Simyager zaman faktörü** (kaynakta tüm seviyeler %0 — veri anomalisi) | `time-factors.garage.known=false` |
| 3 | **Moral eğrisi** (puan oranı → moral %) | `battle.json#morale` |
| 4 | **Casus sağkalım formülü** + gizli casusluk hız çarpanı | `battle.json#spy` |
| 5 | **Şahmerdan duvar hasarı** + **Mancınık bina hasarı** | `battle.json#siege` |
| 6 | **Kayıp dağıtım eğrisi** (oran → kayıplar) | `battle.json#loss_distribution` |
| 7 | **Katır taşıma kapasitesi** + katır yolculuk süresi | `production.json#unresolved` |
| 8 | Üretim **bina başına mı, vatandaş başına mı?** (şimdilik "bina başına" varsayıldı) | `production.json#unresolved` |
| 9 | **Simyager teknik listesi** + **Altın Zırh maliyet artışı** | `battle.json#count`, `docs/15` §7 |
| 10 | **Kanun Kaçağı 10:1 kaybı** kesin muhasebesi (ceza 60 gün sabitlendi; metinde "2 ay") | `battle.json` |

> Karar: MVP'de **parametrik** tutulur; oyun oynanarak/veri kazınarak doğrulanacak. Hiçbiri **uydurulmadı**.

---

## ❓ Karar Bekleyen Sorular (kullanıcıya)

| # | Soru | Durum |
|---|---|---|
| S-1 | Ekran yönü | ✅ Dikey (cevaplandı) |
| S-2 | Oyun adı | ✅ Taht ve Kılıç (cevaplandı) |
| S-3 | Premium MVP'de? | ✅ Hayır (cevaplandı) |
| S-4 | Git deposu | ✅ Evet (cevaplandı) |
| S-5 | Oyun dili | ✅ Sadece TR (cevaplandı) |
| S-6 | Godot kurulumu | ✅ İndiriliyor (cevaplandı) |
| S-7 | Varsayılan oyun hızı | ✅ **1× birebir** (KingsAge süreleri aynen) |
| S-8 | Dünya ölçeği | ✅ **~200×200, ~100 bot köyü** |
| S-9 | İlerleme yapısı | ✅ **Sonsuz kum havuzu** (kazanma koşulu yok) |
| S-10 | Varsayılan oyun hızı (netleştirme) | ✅ **1** (temel/yavaş). ⚠️ Gerçek KingsAge sunucuları **4**; `apply_profile()` ile değiştirilebilir. |
| S-11 | Birim sprite'ları | ✅ **Baştan özgün üretim** (11 birim; CC0 setlerde asker ayrımı yok) |
| S-12 | Arka plan müziği | ✅ **Şimdilik müziksiz** (yalnız CC0 efekt + jingle) |
| S-13 | Ana marka rengi | ✅ **Safir mavisi `#6E9BE8`** |

---

## 📓 İlerleme Günlüğü

- **[Kod-1]** Proje kararları alındı; git başlatıldı; Godot 4.7.2 indiriliyor; klasör ağacı kuruldu. (T-1.1, T-1.3, T-1.4 ✅)
- **[Kod-2]** Godot indirildi ve doğrulandı: `Godot_v4.7.2-stable_win64_console.exe --version` → `4.7.2.stable.official.ed1daf0bf`. (T-1.2 ✅)
- **[Kod-3]** 1. ajan dalgası başlatıldı (arka planda, çakışmasız klasörler):
  - **A-HALKA** → `game/project.godot`, `game/autoload/**`, `game/scripts/core/**`, `game/scenes/boot/**`, `game/icon.svg` (FAZ 2)
  - **A-KURAL** → `game/data/rules/**`, `tools/validate_rules.py` (FAZ 3)
  - **A-VARLIK** → `game/assets/**` (FAZ 4)
  - Ajanların ortak kuralı: **tahmin yok** → belirsizlikleri `AÇIK SORU:` olarak raporlayacaklar; ben kullanıcıya ileteceğim.
- **[Kod-4]** **FAZ 2 (Foundation) ✅ tamamlandı ve A-ŞEF tarafından bağımsız doğrulandı.**
  `godot --headless --path game --quit-after 5` → `EXIT=0`; 15 bina, 11 birim, 50 seviye puan tablosu, 6 kural dosyası yüklendi.
  A-HALKA'nın 6 sorusu teknik karara bağlandı (autoload adları, int dönüşümü, dosya yolları, saat başlangıcı, dünya profilleri, EventBus sözleşmesi). → küçük iyileştirmeler T-2.11/T-2.12 olarak A-HALKA'ya verildi.
- **[Kod-5]** Kullanıcı ürün kararları: **oyun hızı 1× birebir**, **dünya ~200×200 / ~100 bot köyü**, **sonsuz kum havuzu**.
- **[Kod-6]** `docs/16-GODOT-MOBIL-PLANI.md` gerçek autoload adlarına ve klasör yapısına hizalandı (ConfigService/DataService/SaveService adları geçersiz kılındı).
- **[Kod-7]** **FAZ 3 (Kural Motoru) ✅ tamamlandı.** A-KURAL 6 kural JSON + `README.md` (şema sözleşmesi) + `tools/validate_rules.py` üretti.
  Doğrulayıcı: **117/117 başarılı**. Negatif testlerle doğrulayıcının gerçekten hata yakaladığı kanıtlandı.
  **🔎 Yeni bulgu:** demir faktörü çekirdek binalarda 1,165 / diğer standart binalarda 1,160 → `docs/15` düzeltildi.
  Kalan bilinmeyenler `known:false` + `assumption` ile işaretlendi (10 madde; aşağıda ❓ bölümünde).
- **[Kod-8]** **FAZ 4 (Varlıklar) ✅** A-VARLIK 18 CC0 paket + 8 OFL font ailesi indirdi ve düzenledi: **9.494 dosya / 50,4 MB**, 29 lisans metni, `ASSET-MANIFEST.md`, `PALET.md`. 19/19 font Türkçe glifleri doğrulandı.
- **[Kod-9]** **T-2.11/T-2.12/T-2.13 ✅** A-HALKA: int normalizasyonu, saat kapısı (aktif köy şartı), dünya profilleri (`apply_profile`). Self-test ile doğrulandı.
  A-HALKA'nın 4 ek sorusu karara bağlandı: (1) int normalizasyonu onay, (2) **tek doğruluk kaynağı `world-profiles.json`** (`rules/battle.json#config_defaults` yalnız açıklama, çalışma zamanında okunmaz), (3) profil değişimi geriye dönük hesaplanmaz, (4) ilk köy otomatik aktif — doğru davranış.
- **[Kod-10]** Kullanıcı kararları uygulandı: **hız 1**, **özgün birim sprite'ları**, **müziksiz**, **Safir `#6E9BE8`**. `world-profiles.json` + `GameConfig` hız 1'e çekildi.
- **[Kod-11]** **`docs/19-MOTOR-API-SOZLESMESI.md`** yazıldı — tüm kod ajanları için bağlayıcı arayüz (veri şekilleri, `RulesEngine`/`VillageModel`/`WorldModel`/`BattleSimulator` imzaları, determinizm kuralları).
- **[Kod-12]** 2. ajan dalgası başlatıldı: **A-MOTOR** (kural motoru kodu + köy modeli), **A-DUNYA** (dünya/harita), **A-SAVAS** (savaş simülatörü).
- **[Kod-13]** **FAZ 7 (Savaş Simülatörü) ✅ tamamlandı.** A-SAVAS 5 fazın tamamını + Türkçe savaş raporunu + `ASSUMPTIONS.md`'yi yazdı.
  Kanıt: **50/50 test PASS, EXIT=0** (A-ŞEF bağımsız çalıştırdı). Determinizm (aynı tohum → aynı sonuç), sur/gece etkisi, ganimet sınırları ve Kont fetih koşulu kanıtlandı.
  Bilinmeyen 6 formül (`known:false`) tek sabitle belgelendi — **uydurulmadı**.
- **[Kod-14]** **FAZ 3b (Kural Motoru kodu) ✅** + **FAZ 9 (Dünya modeli) ✅** tamamlandı.
  - A-MOTOR: `RulesEngine.gd` + `VillageModel.gd` → **126/126 test PASS**. En kritik kanıt: `cost()` 15 bina × 461 seviye × 3 kaynak = **1383 kontrol, hata 0**.
  - A-DUNYA: `WorldModel.gd` + `WorldGenerator.gd` + `Travel.gd` → **107/107 test PASS**, süreçten bağımsız sabit hash.
- **[Kod-15]** **Kaynaktan yeni doğrulamalar** (`research/text-tr/`):
  - **Bonus köyler:** 6 resmî tip + 'Usta'; **+%10** odun/taş/demir/vatandaş, **+%10 hızlı eğitim**, **+%3 üretim** (A-DUNYA'nın 1.25 varsayımı **düzeltiliyor**).
  - **Terkedilmiş köyler:** soyguncular **bina inşa eder + asker üretir** → normal birim anahtarlarıyla modellenecek.
  - **Kont kuralı:** "güç alanını **maksimumun yarısından fazla** düşüremez" → A-SAVAS bunu zaten doğru uygulamış (`mini(loss, max/2)`).
  - **Gece bonusu:** genel metin 00:00–08:00 der ama **TR dünya ayarı 00:00–06:00** → config kazanır, doğru.
  - **TR dünya ayarları** birebir doğrulandı: hız 4, birim hızı 4, min. birim 3×Kışla, koruma 5/7 gün, oran 10:1, Kont 80 alan, Kanun Kaçağı 2 ay, saatlik %1.
  - `docs/10` §1'deki **hatalı kıta formülü** düzeltildi (`K` + `floor(Y/100)` + `floor(X/100)`), bonus/terkedilmiş köy bölümleri eklendi.
- **[Kod-16]** `docs/19` sözleşme düzeltmeleri: **`researched` durumu** (araştırma gerçek bir eylemdir — Kışla seviyesinden türetilemez), `can_upgrade_now`, `unit_speed` **float**, `bonus_type`, `realm=points`. A-MOTOR ve A-DUNYA'ya düzeltme görevleri verildi.
- **[Kod-17]** A-MOTOR düzeltmeleri tamam: **159/159 test PASS** (A-ŞEF doğruladı). `researched` bayrağı, `can_upgrade_now`, `unit_speed` float (Casus 2.25 alan/dk), `refresh_points`/`refresh_realm`.
- **[Kod-18]** `docs/19` **§7b "Sim modül protokolü"** eklendi: her sim modülü `static func process_tick(state, now_unix, delta_seconds) -> Array` sağlar; `GameLoop.gd` modülleri **yol ile** yükler (`ResourceLoader.exists`) → modüller birbirini beklemeden yazılabilir.
- **[Kod-19]** **3. ajan dalgası başlatıldı:** **A-EKONOMI** (`game/scripts/sim/economy/**` + `game/scripts/core/GameLoop.gd`), **A-ORDU** (`game/scripts/sim/army/**`).
- **[Kod-20]** A-DUNYA kaynak düzeltmeleri tamam: **152/152 test PASS** (A-ŞEF doğruladı). 6 resmî bonus tipi + 'Usta', soyguncu garnizonları (Kışla uyumlu), `realm_of_power == points` değişmezi, kıta etiketleri (`499|506 → K54` doğrulandı), `POINTS_PER_LEVEL` ↔ `building-points.json` tam çapraz doğrulama.
- **[Kod-21]** `docs/19` §3.1'e **bonus köy etki tablosu** ve kanonik sorgu sözleşmesi eklendi (`production_multiplier`, `citizen_multiplier`, `training_speed_multiplier`). A-DUNYA'nın sarmalayıcıları onaylandı; A-EKONOMI/A-ORDU iki yoldan da aynı sonucu üretmeli.
- **[Kod-22]** **FAZ 6 (Ordu & Eğitim) ✅** A-ORDU tamamladı: **66/66 test PASS** (A-ŞEF doğruladı). Araştırma (`researched` tek seferlik), eğitim + vatandaş rezervi, dismiss iadesi, **Altın Zırh (Kuyumcu) + Kont (Köşk)**, `min_attack_units`, `training` bonusu ×0,90.
- **[Kod-23]** `docs/19` **§7b** protokolü işliyor: `ArmySimulator.gd` yol/`process_tick` imzasıyla birebir uyumlu → `GameLoop` takacak.
- **[Kod-24]** **Doküman indeksi notu:** `docs/07` = **casusluk** (araştırma değil); araştırma/eğitim içeriği `docs/05-ASKERLER.md`'de; kaynak/nüfus `docs/03-KAYNAKLAR-VE-SETTLER.md`'de. Ajan brieflerinde dosya adları buna göre düzeltilmeli.
- **[Kod-25]** **FAZ 5 (Ekonomi & Bina Simülasyonu) ✅** A-EKONOMI tamamladı: **108/108 test PASS** (A-ŞEF doğruladı). Üretim + depo tavanı, kuyruk ek maliyeti, sıralı ilerleme, gereksinim ihlali reddi, **30 gün offline hızlı-ileri çökme yok**, Güç Alanı, `GameLoop` (§7b) + EventBus köprüsü.
- **[Kod-26]** ⚠️ **A-ŞEF sadakat düzeltmesi:** Görev metnimde "iptalde iade yok" **yanlıştı**. Kaynak (`buildings.txt`): **taban maliyet İADE EDİLİR**, kuyruk ek maliyeti **iade EDİLMEZ**. `docs/19` §3.2 güncellendi (`cost_paid` / `extra_paid` ayrımı) → A-EKONOMI'ye T-5.9 düzeltmesi verildi.
