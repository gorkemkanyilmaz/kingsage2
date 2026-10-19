# TASKS-GRAPHICS — 2.5D Görsel, Efekt ve Animasyon Revizyon Planı

> **Proje:** Taht ve Kılıç (KingsAge 2.5D Mobil Uyarlaması)  
> **Konu:** Köy İçi, Dünya Haritası, İnşaat Animasyonları, Seviye Atlama VFX ve Görsel Arayüz Revizyonu  
> **Tarih:** 2026-10-18 · **Durum:** 🚀 Yürütmede

---

## 1. Genel Hedef ve Vizyon
Mevcut arayüzdeki düz renkli ve emoji tabanlı görünümü; Kenney CC0 Orta Çağ varlıkları, Godot 4.7.2'nin yerleşik 2.5D izometrik perspektif kabiliyetleri, `Tween` animasyonları, `CPUParticles2D` parçacık sistemleri ve durum bazlı stil filtreleriyle **büyüleyici, yaşayan ve modern bir 2.5D strateji dünyasına** dönüştürmek.

---

## 2. Ajan Dağılımı ve Görev Bölümü

| Ajan Kodu | Rol | Sorumluluk Alanı |
|---|---|---|
| **A-MIMAR** | Mimari & Koordinatör | Görev takibi, mimari uyum, kural ve veri katmanı bütünlüğü |
| **A-GORSAL-KOY** | 2.5D Köy & Binalar | İzometrik zemin, patikalar, 15 bina modeli, seviye rozetleri, pasif/kilitli filtreleri |
| **A-ANIMASYON** | VFX, İnşaat & Partikül | Çekiç vurma animasyonu, inşaat iskelesi, altın seviye atlama yıldız patlaması |
| **A-HARITA** | 2.5D Dünya Haritası | Parşömen harita dokusu, kartografik kale/çadır ikonları, ordu hareket rotaları |
| **A-ARAYUZ** | Orta Çağ UI & Temalar | Dokulu RPG panelleri, ahşap/bronz çerçeveli ResourceBar ve BottomNav |
| **A-QA** | Doğrulama & Test | Başsız ve canlı testler, bellek temizliği ve regresyon kontrolü |

---

## 3. Ayrıntılı Görev Listesi

### Faz 1: Ayarlar & Navigasyon Hata Düzeltmesi (Tamamlandı)
- [x] **T-G.1.1:** `Settings.gd` içindeki `GameConfig.get()` çağrıları ve özellik erişim hatası giderildi.
- [x] **T-G.1.2:** "🏰 Köye Dön" ve "🏠 Ana Menüye Dön" butonlarının sahne geçişleri doğrulandı.

### Faz 2: 2.5D Köy Zemini ve İzometrik Binalar (A-GORSAL-KOY)
- [x] **T-G.2.1:** **2.5D Topoğrafik Zemin:** Düz yeşil renk yerine `medieval-rts` & `cartography` zemin dokularıyla katmanlı köy zemini, tepeler, taş patikalar, çevre çitleri ve ağaçlar eklendi.
- [x] **T-G.2.2:** **15 Bina Modeli & Sprite Eşlemesi:**
  - Kale (`main`): `castleWide.png`
  - Değirmen (`farm`): `mill.png` + dönen yelken kanatları (`elementCross.png`)
  - Oduncu Kampı (`wood`): `buildingTiles_020.png`
  - Taş Ocağı (`stone`): `mine.png`
  - Maden Ocağı (`iron`): `buildingTiles_019.png`
  - Depo (`storage`): `buildingTiles_015.png`
  - Gizli Depo (`hide`): `buildingTiles_016.png`
  - Kışla (`barracks`): `buildingTiles_025.png`
  - Katır Çiftliği (`stable`): `buildingTiles_026.png`
  - Simyager (`garage`): `buildingTiles_024.png`
  - Market (`market`): `buildingTiles_018.png`
  - Kuyumcu (`smith`): `buildingTiles_027.png`
  - Köşk (`snob`): `castle.png`
  - Anıt (`statue`): `churchLarge.png`
  - Sur (`wall`): `gate.png`
  - 15 binanın tümü `BuildingView.gd` ile 2.5D izometrik sprite ve derinlik gölgesine kavuşturuldu.
- [x] **T-G.2.3:** **Bina Seviye Rozetleri (Level Badges):** Her binanın üzerinde şık kalkan/rozet içerisinde net okunaklı seviye ("Sv. 1", "Sv. 5", "Sv. 30", "+ İnşa Et") göstergesi.
- [x] **T-G.2.4:** **Durum Bazlı Filtreleme (State-Driven Visuals):**
  - *Kilitli / Önkoşulsuz:* Gri filtre (`modulate = Color(0.45, 0.45, 0.45, 0.65)`) + kilit rozeti (`🔒 Kilitli`).
  - *İnşa Edilebilir:* Net, parlak renkler ve `+ İnşa Et` rozeti.
  - *İnşaatta:* Ahşap iskele ve çalışma sahası overlay'i, mini ilerleme çubuğu ve `🔨 İnşaatta` rozeti.

### Faz 3: İnşaat Animasyonları & Seviye Atlama VFX (A-ANIMASYON)
- [x] **T-G.3.1:** **İnşaat Sahası ve Çekiç Vurma Animasyonu:**
  - İnşaatı devam eden bina üzerine ahşap iskele çerçevesi yerleştirildi.
  - Ritmik olarak inip kalkan çekiç (`Tween` rotation: 🔨) ve her vuruşta inşaat tozu / kıvılcım parçacıkları (`CPUParticles2D`).
- [x] **T-G.3.2:** **Seviye Atlama Kutlama Efekti (Level Up VFX):**
  - `building_completed` sinyali geldiğinde bina merkezinde 35 adet altın yıldız/ışık parçacık patlaması (`CPUParticles2D`).
  - Bina üzerinde elastik sıçrama (bounce tween) ve yukarı süzülüp kaybolan `✨ SEVİYE X! ✨` etiketi.
- [x] **T-G.3.3:** **Köy Yaşamı & Ortam Animasyonları (Ambient):**
  - Değirmenin kanatlarının tatlı bir hızda dönmesi (`Tween` sonsuz rotasyon).
  - Hover durumunda binaların hafifçe yukarı yükselmesi (`Tween`).

### Faz 4: 2.5D Parşömen Dünya Haritası (A-HARITA)
- [x] **T-G.4.1:** **Parşömen Harita Dokusu:** `parchmentAncient.png` ile Orta Çağ kartografik harita zemini uygulandı.
- [x] **T-G.4.2:** **Şık Köy Modelleri (`MapVillageView.gd`):**
  - Oyuncu köyü: Altın taçlı görkemli kale (`castleWide.png` + 👑 + koordinat plaketi).
  - Soyguncu köyleri: Barbar çadırı ve çadır ikonu (`tent.png` + ⛺).
  - Diğer köyler: Kırmızı/düşman bayraklı kaleler (`castle.png` + 🚩).
- [x] **T-G.4.3:** **Doğal Harita Unsurları:** Boş arazilere rastgele dağlar (`rocksMountain.png`) ve çam ormanları (`treePines.png`) serpiştirildi.

### Faz 5: UI/HUD Tematik Cilalama (A-ARAYUZ)
- [x] **T-G.5.1:** `Settings.gd` navigasyon butonları çift parametre hatasından arındırıldı ve düzeltildi.
- [x] **T-G.5.2:** `BuildingPanel` arayüzünün 2.5D bina sistemiyle senkronize çalışması sağlandı.

### Faz 6: Test ve Doğrulama (A-QA)
- [x] **T-G.6.1:** Tüm sahnelerin derleme ve çalışma kontrolü (`test_all_scenes.gd`) — PASS.
- [x] **T-G.6.2:** VFX ve arayüz testleri (`test_village_ui_flow.gd` 56/56, `test_building_upgrades.gd` 67/67, `test_player_agent.gd` 80/80, `test_settings_nav.gd`) — %100 PASS.
