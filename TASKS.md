# TASKS — Görev Listesi (Task Breakdown)

> Durum simgeleri: ✅ bitti · 🔄 sürüyor · ⏳ bekliyor · ⛔ bloke · ❌ kapsam dışı
> Referans: `DURUM.md` (devam noktası), `docs/TERIMLER.md` (resmî TR terimler)

---

## FAZ 0 — Karar ve Hazırlık ✅

- [x] Hedef platform ve teknoloji seçildi: **Godot**, mobil (iOS + Android)
- [x] Grafik tarzı: **2.5D** (2D sprite + efekt)
- [x] Oynanış kapsamı: **önce tek oyunculu (bot)**, sonra online
- [x] İsim/görsel: **özgün**; mekanikler **birebir**
- [x] Doküman dili: **Türkçe**
- [x] Telif riski not edildi (`docs/00-PROJE-OZETI-VE-KARARLAR.md` §3)

---

## FAZ 1 — Oyun Analizi ve Veri Toplama ✅

### 1.1 EN kaynak
- [x] Yardım sitesi yapısı çıkarıldı
- [x] 54 sayfa indirildi (`research/raw/`)
- [x] Doğrulama/retry mekanizması kuruldu (rate-limit fallback çözümü)
- [x] 54 metin dosyası üretildi (`research/text/`)

### 1.2 TR kaynak (resmî Türkçe)
- [x] 52 sayfa indirildi (`research/raw-tr/`)
- [x] Metinler üretildi (`research/text-tr/`)
- [x] Resmî bina/birim/terim adları çıkarıldı → `docs/TERIMLER.md`

### 1.3 Yapısal veri
- [x] `data/buildings.json`
- [x] `data/units.json`
- [x] `data/building-points.json`
- [x] `docs/reference/buildings/*.md` (15)
- [x] `docs/reference/units/*.md` (11)
- [x] `docs/reference/puan-tablosu.md`

---

## FAZ 2 — Dokümantasyon Tamamlama ✅

### 2.1 Resmî TR terimlerine hizalama ✅
- [x] `docs/01-KAYNAK-ANALIZI.md` — anahtar tabloları TR adlarla değiştir
- [x] `docs/02-OYUN-DONGUSU-VE-TERIMLER.md` — sözlüğü `TERIMLER.md`'ye bağla
- [x] `docs/03-KAYNAKLAR-VE-SETTLER.md` — terim düzelt
- [x] `docs/04-BINALAR.md` — resmî TR bina adları kolonu
- [x] `docs/05-ASKERLER.md` — resmî TR birim adları
- [x] `docs/06-SAVAS-SISTEMI.md` — terim düzelt
- [x] `docs/07-CASUSLUK.md` — terim düzelt
- [x] `docs/08-FETIH.md` — terim düzelt
- [x] `docs/09-KOMUTLAR-DESTEK-VE-YAGMA.md` — terim düzelt
- [x] `docs/10-HARITA-VE-DUNYA.md` — terim düzelt
- [x] `docs/11-OYUNCU-PUAN-KORUMA.md` — terim düzelt
- [x] `docs/13-PREMIUM.md` — terim düzelt
- [x] `README.md` — `TERIMLER.md` + `DURUM.md` bağlantıları
- [x] `docs/reference/*` — TR kaynağından yeniden üretildi

### 2.2 Forum kapsam dışı ❌✅
- [x] `docs/12-ITTIFAKLAR.md` — forum bölümünü **tamamen çıkar**
- [x] İttifak dokümanında "KAPSAM DIŞI" notu bırak

### 2.3 Eksik dokümanlar ✅
- [x] `docs/14-TICARET-VE-PAZAR.md` — Market + Katır çiftliği tam tablolar
- [x] `docs/15-MATEMATIK-VE-FORMULLER.md` — türetilmiş formüller + açık sorular
- [x] `docs/16-GODOT-MOBIL-PLANI.md` — teknoloji/mimari/2.5D/yol haritası
- [x] `docs/18-SANAT-VE-ISIMLENDIRME.md` — özgün isimler + görsel stil + telif listesi
- [x] `docs/17-KURALLAR.md` — ❌ kapsam dışı (kullanıcı kararı)

### 2.4 Araştırma boşlukları (istemci doğrulaması) ⛔
- [ ] İnşaat süresi formülü (`Time factor`)
- [ ] Araştırma/eğitim süresi katsayısı
- [ ] Market eşek üretim/kapasite formülü
- [ ] Simyager teknik listesi (isim/maliyet/süre/etki)
- [ ] Altın zırh maliyet artış çarpanı
- [ ] Moral eğrisi (puan oranı → moral)
- [ ] Casusluk hayatta kalma formülü
- [ ] Şahmerdan/Mancınık hasar formülleri

---

## FAZ 3 — Teknik Tasarım (kod öncesi) 🔄

- [ ] Oyun durumu (state) veri modeli tasarımı
- [ ] Kayıt/yükleme (savegame) formatı
- [ ] Tick/simülasyon döngüsü mimarisi
- [ ] Config şeması (sunucu ayarları: hız, gece bonusu, koruma, kont mesafesi...)
- [ ] UI/UX akış şeması (köy, kale, kışla, harita, market, ittifak, premium)
- [ ] Ekonomi dengesi doğrulama (maliyet/üretim eğrileri)
- [ ] Savaş simülatörü tasarımı (muharebe 5 faz)
- [ ] Sanat varlık listesi (bina sprite'ları, birim sprite'ları, UI, efektler)

---

## FAZ 4 — Godot MVP (Dikey Dilim) ⏳

- [ ] Godot 4.x proje iskeleti
- [ ] Veri katmanı: JSON → Resource (`data/*.json` kullanımı)
- [ ] Köy ekranı (2.5D izometrik, temel tilemap)
- [ ] Kaynak üretimi + depo + gizli depo
- [ ] Vatandaş (nüfus) sistemi ve Değirmen limiti
- [ ] Kale menüsü + inşaat kuyruğu (3 iş + ek maliyet)
- [ ] Kışla: araştırma + eğitim + kov
- [ ] Basit savaş: saldırı → 5 faz → talan
- [ ] Kaydetme/yükleme + offline ilerleme

---

## FAZ 5 — Tek Oyunculu Tam Oyun ⏳

- [ ] Dünya haritası (1000×1000, 100 kıta)
- [ ] Miniharita + vurgulama
- [ ] Çoklu köy + Feth etme (Kont + güç alanı)
- [ ] Casusluk (normal + gizli)
- [ ] Destek birlikleri
- [ ] Simyager teknikleri
- [ ] Kuyumcu + Altın zırh
- [ ] Market + katırlar + ticaret
- [ ] Bonus köyler + terkedilmiş köyler (soyguncular)
- [ ] Bot/AI rakipler (muharebe + ekonomi)
- [ ] Puan/sıralama/saldırı koruması
- [ ] İttifaklar (forum HARİÇ) + diplomasi

---

## FAZ 6 — 2.5D Görsel Yükseltme ⏳

- [ ] Animasyonlu izometrik binalar
- [ ] Parçacık efektleri (inşaat, savaş, kaynak)
- [ ] Işık/gölge, parallax arka plan
- [ ] UI cilası + animasyonlar
- [ ] Ses tasarımı (özgün)

---

## FAZ 7 — Premium / İçerik ⏳

- [ ] İnşa listesi (sınırsız, ek maliyetsiz)
- [ ] Araştırma listesi
- [ ] Saldırı planlayıcı
- [ ] Geliştirilmiş miniharita + harita işaretleme
- [ ] Mesaj/rapor klasörleri
- [ ] Yolculuk süresi hesaplayıcı
- [ ] Toplu eğitim
- [ ] Kutsal Emanetler + Kron sistemi (karar bekliyor)

---

## FAZ 8 — Online Altyapı ⏳

- [ ] Sunucu mimarisi (yetkili sunucu - authoritative)
- [ ] Hesap sistemi + kimlik doğrulama
- [ ] Gerçek zamanlı dünya durumu + senkronizasyon
- [ ] PvP muharebe doğrulama
- [ ] Anti-cheat / çoklu hesap önleme
- [ ] İttifaklar (online)

---

## FAZ 9 — Yayın ⏳

- [ ] Performans optimizasyonu (mobil)
- [ ] Yerelleştirme altyapısı
- [ ] Mağaza hazırlığı (App Store / Google Play)
- [ ] Analitik + hata izleme
- [ ] Kapalı beta → açık beta → yayın

---

## KAPSAM DIŞI ❌

- İttifak forumu ve tüm forum özellikleri
- Gameforge'a ait marka, logo, görsel, ses, metin
- Kurallar/Kurumsal/GİŞ/Gizlilik sayfalarının analizi

---

## Sıradaki Görevler (kısa vadeli)

1. **Küçük terim cilası** — `docs/05`, `docs/06`, `docs/07`, `docs/13` içindeki kalan İngilizce sütun/başlık ifadelerini TR'ye çevir.
2. **Kullanıcıya kod fazı onayı sor** (Godot proje iskeleti için).
3. **Onay gelirse:** `16-GODOT-MOBIL-PLANI.md` §2–§4 uyarınca Godot 4.x iskeleti + veri katmanı (`data/*.json` → Resource).
4. **Araştırma boşlukları (FAZ 2.4)** — istemciden doğrulanacak formüller; MVP'de parametrik tutulacak.
