# Test Scenarios and Checklist

Bu belge, **Taht ve Kılıç** (KingsAge klonu) projesinde kullanıcı tarafından talep edilen **Bölüm 1**, **Bölüm 7**, **Bölüm 8** ve **Bölüm 9** test senaryolarının yürütülmesini, doğrulama adımlarını ve kontrol listesini (checklist) içerir.

Tüm testler Godot 4.7.2 headless konsolu üzerinden bağımsız test ajanları (`game/tests/test_player_agent.gd`, `game/tests/test_actions.gd`, `game/tests/test_battle.gd`, `game/tests/test_all_scenes.gd`) ile koşturulmuş ve **%100 PASS (0 HATA)** ile doğrulanmıştır.

---

## Bölüm 1: Yeni Oyun ve Başlangıç Yönü Seçimi

Oyuncunun oyuna ilk kez giriş yapması, harita üzerinde bölge/yön seçimi yapması, başlangıç köyünün üretilmesi ve başlangıç ekonomi/bina durumunun kurallara uygunluğu test edilir.

- [x] **Kuzeybatı Yönünde Boş Koordinat Tahsisi:** Harita üretim algoritması (seed bazlı) oyuncunun seçtiği Kuzeybatı (NW) çeyreğinde (24|24) geçerli ve boş bir koordinat buldu.
- [x] **Başlangıç Hammaddeleri (1000/1000/1000):** Yeni kurulan köyün kaynak havuzu birebir kural tablosuna göre `Odun: 1000`, `Taş: 1000`, `Demir: 1000` olarak başlatıldı.
- [x] **Başlangıç Binaları Seviyeleri:**
  - [x] `Kale`: Seviye 1
  - [x] `Depo`: Seviye 1 (Kapasite: 1.000)
  - [x] `Değirmen`: Seviye 1 (Maksimum vatandaş: 250)
- [x] **Oyuncu Profili ve Başlangıç Koruması:** Oyuncu için 5 günlük başlangıç saldırı koruması (`protection_until_unix`) ve 110 başlangıç puanı başarıyla tanımlandı.

---

## Bölüm 7: Casusluk / Gözlem Görevi ve Rapor İncelenmesi

Casus birimlerinin seferle hedef köye intikali, gözlem mekaniği, savunma casuslarıyla etkileşim, rapor formatı ve köye geri dönüş akışı test edilir.

- [x] **Casus Seferi Başlatma:** Köyden 10 Casus ile hedef köye gözlem seferi başarıyla başlatıldı.
- [x] **Birliklerin Köyden Düşülmesi:** Göreve çıkan 10 casus anında aktif köy mevcudundan düşüldü (`20 -> 10`).
- [x] **Yolculuk ve Varış Simülasyonu:** Simülasyon saati ilerletilerek casusların hedef köye varışı ve gözlem eyleminin tetiklenmesi sağlandı.
- [x] **Gözlem Raporu Oluşturma:** Hedef köyün bina seviyeleri ve hammadde durumunu içeren resmi Türkçe `'spy'` raporu başarıyla oluşturuldu.
- [x] **Gizli Depo Casusluk Koruması:** Hedef köydeki Gizli Depo kapasitesinin casusların tespit edebileceği kaynak miktarından düşüldüğü doğrulandı.
- [x] **Casusların Köye Dönüşü:** Gözlem görevini tamamlayan birlikler dönüş hareketini tamamlayarak köye eksiksiz geri katıldı (`10 -> 20`).

---

## Bölüm 8: Yağma / Talan Görevi, 5 Fazlı Savaş ve Ganimet Dönüşü

Askeri birliklerin hedef köye talan seferine çıkması, 5 fazlı deterministik muharebe çözümü, moral/sur/gece bonusu hesaplamaları, ganimet taşıma kapasitesi ve dönüş akışı test edilir.

- [x] **Talan Seferi Başlatma:** 150 Okçu birimi ile soyguncu köyüne yağma/talan seferi başarıyla oluşturuldu.
- [x] **Birliklerin Köyden Düşülmesi:** Göreve çıkan 150 okçu köydeki mevcut birliklerden derhal düşüldü (`200 -> 50`).
- [x] **5 Fazlı Deterministik Muharebe Çözümü:**
  - [x] Faz 1: Şahmerdan & Sur hasarı
  - [x] Faz 2: Casus muharebesi
  - [x] Faz 3: Ana ordu çarpışması (moral & şans faktörleri dahil)
  - [x] Faz 4: Mancınık bina hedeflemesi
  - [x] Faz 5: Fetih / Yağma hesaplaması
- [x] **Savaş Raporu Bütünlüğü:** Muharebe sonucunu, kayıpları ve 5 fazın tüm detaylarını içeren resmi formatta savaş raporu üretildi.
- [x] **Ganimet Taşıma ve Dönüş:** Hayatta kalan birimler taşıma kapasitelerince ganimeti alarak dönüş hareketine geçti ve ana köye ulaşıp kaynakları köy deposuna ekledi.

---

## Bölüm 9: UI Buton & Sahne Bütünlüğü Testi

Oyundaki tüm kritik pencereler, alt ve üst navigasyon elemanları, paneller ve buton düğümlerinin sahne ağacında var olduğu, çökme yaratmadığı ve tıklanabilir olduğu test edilir.

- [x] **MainMenu (Ana Menü):**
  - [x] `'Yeni Oyun'` butonu (`BtnNewGame`)
  - [x] `'Devam Et'` butonu (`BtnContinue` - kayıt kontrolüyle aktif/pasif)
  - [x] `'Ayarlar'` butonu (`BtnSettings`)
- [x] **VillageSelect (Köy/Yön Seçim Ekranı):**
  - [x] Kuzeybatı (`BtnNW`)
  - [x] Kuzeydoğu (`BtnNE`)
  - [x] Güneybatı (`BtnSW`)
  - [x] Güneydoğu (`BtnSE`)
  - [x] Rastgele (`BtnRandom`)
- [x] **BottomNav (Alt Navigasyon Barı):**
  - [x] `Köy` sekme butonu (`BtnVillage`)
  - [x] `Harita` sekme butonu (`BtnMap`)
  - [x] `Raporlar` sekme butonu (`BtnReports`)
  - [x] `Sıralama` sekme butonu (`BtnRanking`)
  - [x] `Menü / Ayarlar` sekme butonu (`BtnMenu`)
- [x] **BuildingPanel (Bina Detay ve İnşaat Çekmecesi):**
  - [x] `'Kapat'` butonu (`CloseButton`)
  - [x] `'Yükselt'` / `'Sıraya Ekle'` butonu (`UpgradeButton`)
- [x] **WorldMap & SendTroopsPanel (Harita ve Sefer Arayüzü):**
  - [x] Harita koordinata git butonu (`BtnGoto`)
  - [x] Sefer paneli `'Saldır'` butonu (`BtnAttack`)
  - [x] Sefer paneli `'Talan'` butonu (`BtnRaid`)

---

## Doğrulama Özeti

| Test Kategorisi | İlgili Dosya | Koşulan Testler | Durum |
|---|---|---|---|
| **Bölüm 1** (Yeni Oyun & Yön) | `game/tests/test_player_agent.gd` | 7 Assertion | ✅ PASS (0 Hata) |
| **Bölüm 7** (Casusluk & Rapor) | `game/tests/test_player_agent.gd` + `test_actions.gd` | 15 Assertion | ✅ PASS (0 Hata) |
| **Bölüm 8** (Talan, Savaş & Ganimet) | `game/tests/test_player_agent.gd` + `test_battle.gd` | 18 Assertion | ✅ PASS (0 Hata) |
| **Bölüm 9** (UI Buton & Sahne Bütünlüğü) | `game/tests/test_player_agent.gd` + `test_all_scenes.gd` | 18 Assertion | ✅ PASS (0 Hata) |
