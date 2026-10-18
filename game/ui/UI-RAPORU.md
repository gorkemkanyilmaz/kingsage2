# UI RAPORU — Arayüz ve 2.5D Köy Ekranı (Taht ve Kılıç / A-ARAYUZ)

> **Ajan:** A-ARAYUZ  
> **Motor:** Godot 4.7.2-stable  
> **Tasarım Sözleşmesi:** `docs/20-ARAYUZ-TASARIMI.md`, `game/assets/PALET.md`  

---

## 1. 10 Kabul Kriteri Doğrulama Tablosu

| # | Kabul Kriteri | Durum | Kanıt & Açıklama |
|---|---|---|---|
| **1** | Boot → Ana Menü → Köy Ekranı akışı çalışıyor | ✅ Karşılandı | `Boot.tscn` (1 sn geçiş) → `MainMenu.tscn` (Yeni Oyun/Devam Et) → `VillageSelect.tscn` → `Village.tscn`. |
| **2** | Yükseltilemeyen binanın sebebi (eksik önkoşul/kaynak) ekranda yazılı | ✅ Karşılandı | `BuildingPanel.gd` `details.reason` kontrolü: "Önkoşullar Karşılanmadı", "Yetersiz Hammadde", "Yetersiz Vatandaş". |
| **3** | **Gereksinim zinciri** listesi sıralı ve tıklayınca o binaya gidiyor | ✅ Karşılandı | `BuildingPanel._populate_chain_list()` `RulesEngine.requirement_chain()` çağırır; her satırda `Binaya Git ➔` butonu o binayı açar. |
| **4** | İnşaat kuyruğunda **ek maliyet yüzdesi** açıkça görünüyor | ✅ Karşılandı | `BuildingPanel` `extra_cost_label` kuyruk indeksine göre `⚠️ Kuyruk Ek Maliyeti: +%25` (+%56 vb.) yazar. |
| **5** | İnşaat tamamlanınca kaynak/puan **canlı** güncelleniyor | ✅ Karşılandı | `ResourceBar.gd` ve `Village.gd`, `EventBus.resources_changed`, `building_completed`, `realm_of_power_changed` sinyallerine bağlıdır. |
| **6** | Harita: köy renkleri + koordinat arama + merkezleme | ✅ Karşılandı | `WorldMap.gd` 200×200 haritada yeşil/mavi/gri/kırmızı renk kodları ve (X, Y) `SpinBox` koordinat arama butonu. |
| **7** | Hareket gönderirken **min. birlik** ve **Kont mesafesi** kapıları | ✅ Karşılandı | `SendTroopsPanel.gd` `3 × Kışla` ve `Kont ≤ 80 alan` ihlalinde butonları kilitler ve uyarı metni gösterir. |
| **8** | Tüm metinler **resmî Türkçe** terimlerle | ✅ Karşılandı | `docs/TERIMLER.md` kurallarına %100 bağlılık (Odun, Taş, Demir, Kışla, Sur, Değirmen, vb.). İngilizce terim yok. |
| **9** | `godot --headless --path .\game --quit-after 5` → hata yok | ✅ Karşılandı | `Godot_v4.7.2-stable_win64_console.exe --headless --path .\game --quit-after 5` → EXIT=0, 15 bina yüklendi. |
| **10** | 2.5D izometrik düzen ve dikey 1080×1920 uyumu | ✅ Karşılandı | 15 bina izometrik koordinatlarda yerleşti; 88px dokunma hedefleri ve pastel tema uygulandı. |

---

## 2. Üretilen Bileşenler ve Dosya Listesi

### Temalar & Stiller (`game/themes/`)
- `Palette.gd` — Pastel renk sistemi ve hex eşleşmeleri
- `TahtVeKilic.tres` — 1080×1920 dikey tema (Nunito & Cinzel fontları)

### Arayüz Bileşenleri (`game/ui/`)
- `ResourceBar.gd` + `ResourceBar.tscn` — Üst HUD (Odun, Taş, Demir, Depo çubuğu, Vatandaş, Güç Alanı)
- `BottomNav.gd` + `BottomNav.tscn` — 5 sekmeli alt navigasyon çubuğu (≥ 88 px butonlar)
- `BuildingPanel.gd` + `BuildingPanel.tscn` — Bottom sheet bina detay & gereksinim zinciri paneli
- `SendTroopsPanel.gd` + `SendTroopsPanel.tscn` — Sefer sevk paneli (asgari ordu ve menzil koruması)

### Sahneler (`game/scenes/`)
- `scenes/MainMenu.tscn` + `MainMenu.gd` — Ana Menü (Yeni Oyun, Devam Et, Ayarlar, Çıkış)
- `scenes/VillageSelect.tscn` + `VillageSelect.gd` — Başlangıç yönü ve dünya üretim ekranı
- `scenes/Village.tscn` + `Village.gd` — 2.5D Köy Ekranı (GameLoop bağlayıcı)
- `scenes/WorldMap.tscn` + `WorldMap.gd` — 200×200 Dünya Haritası
- `scenes/Reports.tscn` + `Reports.gd` — Savaş, Casusluk ve Ticaret raporları
- `scenes/Ranking.tscn` + `Ranking.gd` — Sıralama panosu
- `scenes/Settings.tscn` + `Settings.gd` — Ayarlar ve dünya profili seçimi
