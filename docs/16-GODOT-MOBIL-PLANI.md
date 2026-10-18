# 16 — Godot Mobil Planı (Teknik Tasarım)

> Bu bir **tasarım/plan** dokümanıdır — **kod içermez.**
> Hedef: **Godot 4.x**, **mobil (iOS + Android)**, **2.5D** (2D sprite + ışık/parçacık/parallax),
> oynanış **birebir** KingsAge mekanikleriyle, **özgün isim ve görsellerle**.
> Önce **tek oyunculu (bot/AI)**, sonra **online**.

---

## 1. Hedefler ve Kısıtlar

| Konu | Karar |
|---|---|
| Motor | **Godot 4.x** (GDScript ağırlıklı) |
| Platform | **iOS + Android** (öncelik mobil), masaüstü ikincil |
| Görsel | **2.5D**: izometrik zemin + sprite binalar + ışık, parçacık, parallax |
| Veri | `data/*.json` (mevcut araştırma çıktısı) → Godot `Resource` |
| Simülasyon | **Sunucu-otoriter mantığa hazır**; tek oyunculuda yerel simülasyon |
| Kaydetme | Yerel (tek oyunculu) + ileride hesap tabanlı |
| Dil | TR (resmî terimler) + ileride yerelleştirme |

---

## 2. Proje İskeleti (Godot)

```
res://
├─ project.godot
├─ autoload/              # Singleton servisler
│  ├─ GameState.gd        # Tüm oyun durumu (kök)
│  ├─ GameClock.gd        # Tick/simülasyon zamanlayıcısı
│  ├─ ConfigService.gd    # Sunucu ayarları (hız, gece bonusu, koruma...)
│  ├─ DataService.gd      # JSON → Resource yükleyici
│  ├─ EventBus.gd         # Global sinyal veri yolu
│  └─ SaveService.gd      # Kaydet/yükle + offline ilerleme
├─ data/                  # data/*.json kopyaları (buildings, units, points)
├─ resources/             # .tres tanımları (BuildingDef, UnitDef, ServerConfig)
├─ scenes/
│  ├─ boot/               # Yükleme, yön seçimi, ilk köy
│  ├─ village/            # İzometrik köy ekranı
│  ├─ map/                # Dünya haritası + miniharita
│  ├─ ui/                 # Menüler, paneller, raporlar, mesajlar
│  └─ battle/             # Savaş simülasyonu görselleştirme
├─ scripts/
│  ├─ sim/                # Saf mantık: ekonomi, üretim, inşaat, savaş
│  ├─ ai/                 # Bot/AI davranışları
│  └─ net/                # (Faz 8) istemci-sunucu
└─ assets/
   ├─ sprites/  effects/  fonts/  audio/
```

---

## 3. Veri Katmanı

- Kaynak: mevcut **`data/buildings.json`, `data/units.json`, `data/building-points.json`**
  (TR kaynaktan üretildi, resmî Türkçe adlarla).
- `DataService` bu JSON'ları okur → **typed Resource**'lara çevirir:
  - `BuildingDef` (anahtar, ad, maks. seviye, gereksinimler, seviye tablosu, son sütun)
  - `UnitDef` (maliteyet, istatistik, araştırma/eğitim, gereksinimler)
- **Sunucu ayarları** `ConfigService` içinde (JSON): hız, birim hızı, gece bonusu penceresi,
  koruma süreleri, Kont mesafesi, min. saldırı birimi, iptal süreleri, oran limitleri.
  → **TR ve EN dünyaları farklı olduğu için ayarlar mutlaka veri olarak tutulur** (`10-HARITA-VE-DUNYA.md` §6).

---

## 4. Simülasyon Mimarisi

### 4.1 Tick döngüsü
- `GameClock` bir **birikimli tick** döngüsü çalıştırır (ör. 1 sn).
- Her tick'te **olay kuyruğu** işlenir: bina tamamlandı, birlik eğitildi, ordu vardı, kaynak üretimi.
- **Offline ilerleme:** Uygulama kapalıyken geçen süre `SaveService`'te saklanır; açılışta
  **hızlı-ileri** (fast-forward) ile telafi edilir. Üretim doğrusal → integral alınabilir.

### 4.2 Katmanlar
```
[ Ekonomi ]   üretim, depo, vatandaş, inşaat kuyruğu
[ Ordu   ]    araştırma, eğitim, destek, kov
[ Savaş  ]    5 faz muharebe (06-SAVAS-SISTEMI.md)
[ Harita ]    dünya, kıtalar, terkedilmiş/bonus köyler, hareketlerin yolu
[ Oyuncu ]    puan, güç alanı, sıralama, koruma, uyku modu
[ İttifak]    rütbe, yetki, diplomasi (forum YOK)
```

### 4.3 Savaş Simülatörü
- Saf, deterministik fonksiyon: `(saldıranOrdusu, savunanOrdusu, ayarlar, rastgeleTohum) → rapor`
- 5 faz sırayla:
  1. **Sura zarar** (Şahmerdan)
  2. **Casus Saldırısı**
  3. **Normal Asker Saldırısı**
  4. **Binalara zarar** (Mancınık)
  5. **Fetihler ve Yağma**
- Deterministik olması, ileride sunucu doğrulaması ve **tekrar oynatma** için gereklidir.

---

## 5. Sahne ve UI Yapısı

### 5.1 Köy ekranı (2.5D)
- **İzometrik tilemap** zemin + bina sprite'ları (seviyeye göre görsel değişim).
- Binaya dokun → **Kale menüsü/ilgili panel** açılır.
- Üretim binalarında **animasyon** (ör. değirmen döner, ocak tüter).
- Alt bar: hammadde + vatandaş + boş vatandaş + saat.

### 5.2 Dünya haritası
- Izgara (plan: **1000×1000 alan / 100 kıta** — bkz. `10-HARITA-VE-DUNYA.md`).
- Komşu köyler, terkedilmiş/bonus köyler, ittifak renkleri.
- **Miniharita** + (premium) **harita işaretleme**.

### 5.3 UI akışı
```
Boot → Yön seçimi → İlk köy
  ├─ Köy (Kale, üretim binaları, Kışla, Sur, Market, Simyager, Köşk, Kuyumcu, Anıt)
  ├─ Harita (saldırı/destek/casus/fetih emirleri)
  ├─ Raporlar (Savaş Raporu, Casusluk Raporu)
  ├─ Mesajlar
  ├─ Sıralama (Teşhir Direği, Savaşlar)
  ├─ İttifak (rütbe/yetki/diplomasi)
  └─ Premium (Taht Salonu)
```

---

## 6. 2.5D Görsel Strateji

| Katman | Teknik |
|---|---|
| Zemin | İzometrik tilemap, hafif yükseklik farkı |
| Binalar | Y-billboard sprite + gölge; seviyeye göre varyant |
| Derinlik | Y-sıralama (depth sort) + oklüzyon kesme |
| Işık | `CanvasModulate` + `PointLight2D` (gündüz/gece döngüsü) |
| Efektler | `GPUParticles2D` (duman, toz, ateş, kaynak uçuşu) |
| Arka plan | Parallax (dağ/orman katmanları) |
| Kamera | İzometrik eğim, yakınlaştırma, sürükle-kaydır |
| Performans | Atlas sprite'lar, LOD, mobil için parçacık limitleri |

---

## 7. Bot / AI (Tek Oyunculu)

- **Ekonomi botu:** üretim/bina dengesi, kaynak birikimi, inşaat sırası.
- **Askerî bot:** keşif (casus), hedef seçimi, ordu kurulumu, savunma desteği.
- **Zorluk seviyeleri:** pasif / dengeli / agresif.
- **Kişilik:** terkedilmiş köy soyguncuları (bina inşa eder, ordu kurar, puan artırır).
- Bot kararları **aynı simülasyon API'sini** kullanır (oyuncuyla aynı kurallar).

---

## 8. Kaydetme / Yükleme

- Tek oyunculu: yerel dosya (JSON veya Godot `Resource` serileştirme).
- Alanlar: tüm köyler, binalar, birlikler, hareketler (uçuştaki ordular + varış zamanı),
  kaynaklar, kuyruklar, puan/güç alanı, mesajlar, ittifak, ayarlar, zaman damgası.
- **Offline telafi:** yükleme anında geçen süre tick'lenir.
- Sürüm uyumu için `saveVersion` alanı.

---

## 9. Online Faz (Ayrı Faz — Faz 8)

- **Sunucu-otoriter** mimari: istemci yalnızca emir gönderir, sonuç sunucudan gelir.
- Simülasyon mantığı **paylaşılan** (istemci + sunucu aynı kurallar); sunucu doğrular.
- Hesap, kimlik doğrulama, dünya durumu senkronizasyonu.
- **Anti-cheat**, çoklu hesap ve **internet bağlantı paylaşımı** kuralları.
- Tek oyunculu kod **mümkün olduğunca yeniden kullanılır** (aynı `sim/` katmanı).

---

## 10. Yol Haritası (özet)

| Faz | İçerik | Durum |
|---|---|---|
| 0 | Kararlar | ✅ |
| 1 | Analiz + veri | ✅ |
| 2 | Dokümantasyon | 🔄 |
| 3 | Teknik tasarım | 🔄 (bu doküman) |
| 4 | **MVP dikey dilim** (köy + ekonomi + inşaat + basit savaş) | ⏳ |
| 5 | Tek oyunculu tam oyun (harita, fetih, casusluk, bot) | ⏳ |
| 6 | 2.5D görsel yükseltme | ⏳ |
| 7 | Premium içerik | ⏳ |
| 8 | Online altyapı | ⏳ |
| 9 | Yayın | ⏳ |

> Detaylı görev listesi: [`../TASKS.md`](../TASKS.md)

---

## 11. Teknik Riskler

| Risk | Önlem |
|---|---|
| Kesin süre/hasar formülleri bilinmiyor | MVP'de **parametrik** tut; istemciden doğrula (§`15` §7) |
| Mobil performans | Atlas, LOD, parçacık limiti, test cihaz matrisi |
| 2.5D karmaşıklığı | Önce basit izometrik, sonra ışık/efekt katmanı |
| Telif | **Özgün isim + görsel**; hiç Gameforge varlığı kullanılmaz (`18`) |
| Online karmaşıklık | Tek oyunculuda temiz ayrım; sunucu sonra |
