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

### Faz 7: Harita Kartografyası & Menü Atmosferi Cilası (8. oturum)
- [x] **T-G.7.1:** **Kartografik Dekor Katmanı (`scenes/map/WorldDecor.gd`):** Düz parşömen zemin; tek bir `Control._draw()` içinde nehirler (kıvrımlı poligon + akış çentikleri), göller (su lekesi + kartografi ikonu), orman adacıkları (yosun lekesi + çepere dizilen çam ikonları), dağ sırtları ve serpiştirilmiş tek ağaç/kayalarla zenginleştirildi. Binlerce düğüm yerine tek çizim listesi → mobil dostu. Sabit tohum (deterministik).
- [x] **T-G.7.2:** **Sabit Harita HUD'u (`scenes/map/MapRuler.gd`):** Harita kenarına çift çizgili çerçeve, köşe vurguları, canlı koordinat cetveli (kaydırmayla güncellenen X/Y etiketleri), kenar vinyeti, cetvel şeritleri ve alt-sol "Bölge X | Y" rozeti eklendi.
- [x] **T-G.7.3:** **Harita Başlığı & Jetonlar:** Başlık Cinzel serif + parşömen tonuna çevrildi; X/Y kutuları koyu "harita aleti" görünümü (oklar gizli), "Git" düğmesi altın parşömen düğmesi yapıldı. `MapVillageView` jetonundaki opak buton gölgesi (cream square hatası) tamamen şeffaf `StyleBoxEmpty` ile giderildi.
- [x] **T-G.7.4:** **Ortak Parşömen Arka Planı (`ui/Backdrop.gd`):** Tüm menü/panel ekranlarına döşenmiş parşömen dokusu, köşe aquarelle lekeleri, kenar vinyeti ve arma filigranı veren tek yeniden kullanılabilir katman.
- [x] **T-G.7.5:** **Ana Menü / Köy Seçim / Ayarlar:** Kart (plaque) düzeni, Cinzel başlıklar, arma filigranları (kale / pusula / yel değirmeni) ve merkezî içerik kartı.
- [x] **T-G.7.6:** **Sıralama & Raporlar:** Sıralama ilk 3 için altın/gümüş/bronz madalya, alternatif satır zeminleri ve oyuncunun köyü vurgusu; raporlar tür renkli sol şeritli kartlar + ikonlar ve zengin boş-durum görünümü; iki ekrana da Cinzel başlık şeridi.
- [x] **T-G.7.7:** **Görsel Denetim Aracı (`tools/capture_screens.gd`):** 8 ekranı (kaydırılmış harita dahil) `screenshots/` klasörüne 540×960 olarak yakalar; örnek raporlarla kart görünümünü de doğrular. `screenshots/` artık git dışında.
- [x] **T-G.7.8:** **Regresyon:** 14 test paketi (rules/world/economy/army/battle/actions/save/integration/bot/player_agent/building_upgrades/settings_nav/pan_zoom/ui_flow) + `test_all_scenes` → **tamamı PASS**.

### Faz 8: Yazı & Çizgi Netliği (Crispness) Cilası (9. oturum)
> **Sorun:** Masaüstü geliştirme penceresi 540×960 iken tasarım tabanı 1080×1920 olduğu için tüm UI yarı ölçekte yeniden örnekleniyordu; glifler 2× küçültülünce (bitmap → bilinear) yazılar ve panel kenarları bulanık görünüyordu ("bulanıklık" = ölçek küçültme yumuşaması).
- [x] **T-G.8.1:** **MSDF font hattı:** Kullanılan 4 tema fontunda (`Nunito-Regular`, `Nunito-Bold`, `Nunito-SemiBold`, `Cinzel-Bold`) `multichannel_signed_distance_field=true`, `msdf_size=64` (mesafe alanı tabanlı glifler her ölçekte — küçültmede de — yeniden örneklenmeden net kalır).
- [x] **T-G.8.2:** **Küçük yazı boyutları büyütüldü:** Üst çubuk 24–28 (köy adı 26, Puan/Güç/Vatandaş 24, hammadde/depo 28), bina paneli 24–32 (başlık 32, seviye/kontrol 28, sekme 28, maliyet/buton 30), alt nav 22, kuyruk HUD 22/20, harita lejantı 20 + "Köyüm" 22 + cetvel 24, köy jetonu etiketi 18, Ayarlar etiketleri 26. Fiziksel boyut ≥ ~12 px'e çıkarıldı.
- [x] **T-G.8.3:** **Yerleşim sıkıştırması:** Üst çubuk kenar boşlukları 22→16, ayırıcı 12→8; vatandaş/güç etiketleri ikon+sayı kısa biçimine (`👥 233 / 250`, `⚡ Güç: 110`) alındı → büyüyen yazılara karşın 1080 px genişliğe sığdı, taşma yok.
- [x] **T-G.8.4:** **Doğrulama:** `test_all_scenes` + 14 paket (rules/world/economy/army/battle/actions/save/integration/bot/player_agent/building_upgrades/settings_nav/pan_zoom/ui_flow) → **tamamı EXIT=0**; `screenshots/` 540×960 ve 1080×1920 karşılaştırmalı olarak gözle denetlendi (bina paneli açık/kilitli/aktif inşaat durumları dahil).
