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

## FAZ 2 — Halka (Foundation) — *kritik yol*

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-2.1 | `project.godot`: ad, dikey 1080×1920, gl_compatibility, autoload kayıtları | A-HALKA | ⏳ Bekliyor |
| T-2.2 | `EventBus.gd`: global sinyaller (bina tamamlandı, birlik hazır, ordu vardı, kaynak değişti, rapor üretildi…) | A-HALKA | ⏳ Bekliyor |
| T-2.3 | `GameData.gd`: `data/*.json` → tipli sözlükler (bina, birim, puan, kural) + sorgu API | A-HALKA | ⏳ Bekliyor |
| T-2.4 | `GameConfig.gd`: **sunucu ayarları** (hız, birim hızı, gece bonusu, koruma süreleri, Kont mesafesi, iptal süreleri, oran limitleri, min. saldırı birimi) | A-HALKA | ⏳ Bekliyor |
| T-2.5 | `GameState.gd`: kök durum (köyler, kaynaklar, kuyruklar, hareketler, raporlar, oyuncu) + serileştirme | A-HALKA | ⏳ Bekliyor |
| T-2.6 | `GameClock.gd`: tick döngüsü + **offline hızlı-ileri** | A-HALKA | ⏳ Bekliyor |
| T-2.7 | `SaveManager.gd`: kaydet/yükle (yerel) + `saveVersion` | A-HALKA | ⏳ Bekliyor |
| T-2.8 | `scenes/boot/Boot.tscn` + `Boot.gd`: veriyi yükle, başlık + yüklenen bina sayısını göster | A-HALKA | ⏳ Bekliyor |
| T-2.9 | `icon.svg` (özgün, pastel) | A-HALKA | ⏳ Bekliyor |
| T-2.10 | **Doğrulama:** `godot --headless --quit --path game` → hata yok | A-HALKA | ⏳ Bekliyor |

## FAZ 3 — Kural Motoru (Rules Engine) — *gereksinim zinciri burada*

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-3.1 | `game/data/rules/requirements.json`: **gereksinim DAG'ı** (bina → gereksinimler zinciri) | A-KURAL | ⏳ Bekliyor |
| T-3.2 | `game/data/rules/costs.json`: maliyet büyüme faktörleri + tam maliyet fonksiyonları | A-KURAL | ⏳ Bekliyor |
| T-3.3 | `game/data/rules/production.json`: üretim/depo/gizli depo/değirmen/katır/sur eğrileri | A-KURAL | ⏳ Bekliyor |
| T-3.4 | `game/data/rules/time-factors.json`: zaman faktörü serileri (Kale, Kışla, Simyager, Köşk) + inşa kuyruğu ek maliyeti | A-KURAL | ⏳ Bekliyor |
| T-3.5 | `game/data/rules/battle.json`: savaş sabitleri (duvar %, gece ×2, moral aralığı, şans ±%25, oranlar, fazlar) | A-KURAL | ⏳ Bekliyor |
| T-3.6 | `game/data/rules/units.json`: birim araştırma/eğitim gereksinimleri (Kışla seviyeleri) | A-KURAL | ⏳ Bekliyor |
| T-3.7 | `tools/validate_rules.py`: DAG asiklik + tüm referanslar geçerli + tablolar tutarlı → rapor | A-KURAL | ⏳ Bekliyor |
| T-3.8 | `game/data/rules/README.md`: şema açıklaması (A-HALKA'nın okuyacağı sözleşme) | A-KURAL | ⏳ Bekliyor |

## FAZ 4 — Varlıklar (Assets)

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-4.1 | CC0/OFL **pastel & canlı** izometrik bina, birim, harita, UI paketleri indir | A-VARLIK | ⏳ Bekliyor |
| T-4.2 | Türkçe destekleyen ücretsiz font(lar) (OFL) | A-VARLIK | ⏳ Bekliyor |
| T-4.3 | `game/assets/` altında düzenle + `ASSET-MANIFEST.md` (kaynak URL + lisans) | A-VARLIK | ⏳ Bekliyor |
| T-4.4 | **Palet rehberi** (`assets/PALET.md`): pastel & canlı renk kodu listesi | A-VARLIK | ⏳ Bekliyor |

## FAZ 5 — Ekonomi & Bina Simülasyonu

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-5.1 | Hammadde üretimi (saatlik) + Depo tavanı + taşma | A-EKONOMI | ⏳ Bekliyor |
| T-5.2 | Vatandaş sistemi (boş/çalışan, Değirmen tavanı) | A-EKONOMI | ⏳ Bekliyor |
| T-5.3 | İnşaat kuyruğu (3 iş ücretsiz + ek maliyet tablosu) + süre hesabı | A-EKONOMI | ⏳ Bekliyor |
| T-5.4 | Gereksinim doğrulama (inşa/geliştirme öncesi zincir kontrolü) | A-EKONOMI | ⏳ Bekliyor |
| T-5.5 | Binayı yık (Kale Lv15 + Simyager tekniği) | A-EKONOMI | ⏳ Bekliyor |
| T-5.6 | Puan hesaplama + Köy Puanı + Toplam Puan (2.500/ek köy) | A-EKONOMI | ⏳ Bekliyor |
| T-5.7 | Güç Alanı döngüsü (saatlik %1 artış, saldırı düşüşü, 0 → fetih) | A-EKONOMI | ⏳ Bekliyor |

## FAZ 6 — Ordu & Eğitim

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-6.1 | Birim araştırma (Kışla seviyesi gereksinimleri + kuyruk) | A-ORDU | ⏳ Bekliyor |
| T-6.2 | Birim eğitimi (maliyet + vatandaş + Kışla süre katsayısı) | A-ORDU | ⏳ Bekliyor |
| T-6.3 | Birim kovma (dismiss) + vatandaş iadesi | A-ORDU | ⏳ Bekliyor |
| T-6.4 | Altın zırh üretimi (Kuyumcu) + Kont eğitimi (Köşk) + maliyet artışı | A-ORDU | ⏳ Bekliyor |
| T-6.5 | Ordu büyüklüğü limitleri (min. saldırı birimi = 3 × Kışla) | A-ORDU | ⏳ Bekliyor |

## FAZ 7 — Savaş Simülatörü (5 faz)

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-7.1 | Faz 1: **Sura zarar** (Şahmerdan) | A-SAVAS | ⏳ Bekliyor |
| T-7.2 | Faz 2: **Casus Saldırısı** | A-SAVAS | ⏳ Bekliyor |
| T-7.3 | Faz 3: **Normal Asker Saldırısı** (moral + şans + sur + gece) | A-SAVAS | ⏳ Bekliyor |
| T-7.4 | Faz 4: **Binalara zarar** (Mancınık; savunan kaybına bağlı) | A-SAVAS | ⏳ Bekliyor |
| T-7.5 | Faz 5: **Fetihler ve Yağma** | A-SAVAS | ⏳ Bekliyor |
| T-7.6 | Deterministik + tohumlanabilir; **Savaş Raporu** üretimi | A-SAVAS | ⏳ Bekliyor |

## FAZ 8 — Casusluk / Fetih / Destek / Talan

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-8.1 | Normal + gizli casus saldırısı (gizli = 3× yavaş) | A-KESIF | ⏳ Bekliyor |
| T-8.2 | Casusluk raporu + bilgi kademeleri + Gizli Depo etkisi | A-KESIF | ⏳ Bekliyor |
| T-8.3 | Destek (kendi/dost köye birlik gönderme) | A-KESIF | ⏳ Bekliyor |
| T-8.4 | Talan (taşıma kapasitesi + gizli depo sınırı) | A-KESIF | ⏳ Bekliyor |
| T-8.5 | Fetih (Kont + güç alanı 0) + fetih koruması | A-KESIF | ⏳ Bekliyor |
| T-8.6 | Saldırı/destek/ticaret **iptal** kuralları + süreler | A-KESIF | ⏳ Bekliyor |

## FAZ 9 — Dünya & Harita

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-9.1 | Dünya ızgarası (1000×1000, 100 kıta) + koordinat | A-DUNYA | ⏳ Bekliyor |
| T-9.2 | Köy yerleşimi (yön seçimi), bonus köyler, terkedilmiş köyler (soyguncular) | A-DUNYA | ⏳ Bekliyor |
| T-9.3 | Miniharita + komşu/ittifak renkleri | A-DUNYA | ⏳ Bekliyor |
| T-9.4 | Yolculuk süresi hesabı (mesafe + birim hızı + hız ayarı) | A-DUNYA | ⏳ Bekliyor |

## FAZ 10 — UI & 2.5D

| ID | Görev | Ajan | Durum |
|---|---|---|---|
| T-10.1 | UI teması (pastel & canlı) + fontlar + ortak kontroller | A-ARAYUZ | ⏳ Bekliyor |
| T-10.2 | Kale menüsü + bina panelleri + **gereksinim zinciri görünümü** | A-ARAYUZ | ⏳ Bekliyor |
| T-10.3 | Kışla paneli (araştır/eğit/kov) | A-ARAYUZ | ⏳ Bekliyor |
| T-10.4 | 2.5D izometrik köy ekranı (tilemap + sprite + ışık) | A-ARAYUZ | ⏳ Bekliyor |
| T-10.5 | Harita ekranı + emir gönderme akışı | A-ARAYUZ | ⏳ Bekliyor |
| T-10.6 | Rapor/Mesaj/Sıralama ekranları | A-ARAYUZ | ⏳ Bekliyor |

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

## ❓ Karar Bekleyen Sorular (kullanıcıya)

| # | Soru | Durum |
|---|---|---|
| S-1 | Ekran yönü | ✅ Dikey (cevaplandı) |
| S-2 | Oyun adı | ✅ Taht ve Kılıç (cevaplandı) |
| S-3 | Premium MVP'de? | ✅ Hayır (cevaplandı) |
| S-4 | Git deposu | ✅ Evet (cevaplandı) |
| S-5 | Oyun dili | ✅ Sadece TR (cevaplandı) |
| S-6 | Godot kurulumu | ✅ İndiriliyor (cevaplandı) |

---

## 📓 İlerleme Günlüğü

- **[Kod-1]** Proje kararları alındı; git başlatıldı; Godot 4.7.2 indiriliyor; klasör ağacı kuruldu. (T-1.1, T-1.3, T-1.4 ✅)
- **[Kod-2]** Godot indirildi ve doğrulandı: `Godot_v4.7.2-stable_win64_console.exe --version` → `4.7.2.stable.official.ed1daf0bf`. (T-1.2 ✅)
- **[Kod-3]** 1. ajan dalgası başlatıldı (arka planda, çakışmasız klasörler):
  - **A-HALKA** → `game/project.godot`, `game/autoload/**`, `game/scripts/core/**`, `game/scenes/boot/**`, `game/icon.svg` (FAZ 2)
  - **A-KURAL** → `game/data/rules/**`, `tools/validate_rules.py` (FAZ 3)
  - **A-VARLIK** → `game/assets/**` (FAZ 4)
  - Ajanların ortak kuralı: **tahmin yok** → belirsizlikleri `AÇIK SORU:` olarak raporlayacaklar; ben kullanıcıya ileteceğim.
