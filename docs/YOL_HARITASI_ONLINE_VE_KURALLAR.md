# KingsAge 2 — Büyük Sistem ve Çevrimiçi Entegrasyon Yol Haritası

Bu belge, verilen tam yetki çerçevesinde oyunu eksiksiz, modern, otantik KingsAge kurallarına birebir bağlı ve 500 anlık kullanıcıyı kaldırabilecek online mimari ile donatmak için uygulanacak adımları listeler.

---

## 1. Arayüz ve Görsel İyileştirmeler (UI/UX)
- [x] **Alt Menü (BottomNav) 6 Buton**:
  - `Köy`, `Harita`, `Raporlar`, `Mesajlar`, `Sıra`, `Menü` butonları birebir ahşap dock dokusu ile uyarlandı.
- [ ] **Raporlar ve Mesajlar Ayrımı**:
  - `Raporlar` tıklandığında yalnızca savaş, casusluk ve ticaret raporları listesi görünür.
  - `Mesajlar` tıklandığında gelen kutusu, mektuplar ve yeni mesaj yazma arayüzü görünür.
- [ ] **Haritada Koruma Kalkanı (Protection Shield)**:
  - Çapı tam köy karesi boyutuna küçültülecek (büyük daire yerine köy sınırlarına oturan zarif kalkan).
  - Opasite/şeffaflık artırılacak (daha zarif, göz yormayan mistik altın ışıltı).

## 2. Giriş Sistemi (Google & Apple Sign-In)
- [ ] **Giriş Ekranı (LoginScreen)**:
  - Yalnızca "Google ile Giriş Yap" ve "Apple ile Giriş Yap" seçenekleri.
  - Başka kayıt veya misafir butonu bulunmayacak.
  - Auth token / ID yönetimi ve oturum saklama (PlayerProfile / AuthManager).

## 3. KingsAge Otantik Sefer & Savaş Kuralları
- [ ] **Sefer Türlerinin Sadeleştirilmesi**:
  - `Talan / Yağma` ayrı butonu kaldırılacak.
  - Yalnızca iki ana işlem:
    1. **Saldır (Attack)**: Düşman/bot köyüne ordu gönderir. Muharebede galip gelinirse sağ kalan askerler taşıma kapasitelerince otomatik yağma yapar.
    2. **Hammadde Gönder (Transport / Trade)**: Katırlarla hammadde transferi.
- [ ] **Casusluk Optimizasyonu**:
  - KingsAge casusluk kurallarına tam uyum (hayatta kalan casus oranına göre kaynak, bina seviyesi, dışarıdaki birlik kademeleri; gizli casuslukta savunana bildirim gitmemesi; savunma casuslarının saldırı casuslarını avlaması).

## 4. Bot Sistemi Revizyonu
- [ ] **Bot Başlangıç Seviyesi**:
  - Oyun başında botlar yüksek seviye değil, tıpkı yeni başlayan bir oyuncu gibi Seviye 1 binalar ile başlayacak.
- [ ] **Bot Sayısı ve Davranışı**:
  - Dünyada tam 20 adet bot köyü bulunacak.
  - Bot köylerinde **başlangıç saldırı koruması olmayacak** (oyuncular diledikleri an yağmalayabilir).
  - Botlar oyunculara **asla saldırmayacak** (yalnızca kendi köylerini geliştirecek ve savunma askeri üretecek).

## 5. Çevrimiçi Mimari (Online Backend & 500 CCU)
- [ ] **Hafif ve Hızlı Backend Sunucusu (FastAPI / SQLite-PostgreSQL)**:
  - Auth endpointleri (Google/Apple token doğrulama veya mock provider).
  - Köy, bina, kuyruk, birlik, hareket, rapor ve mesaj durumlarının veritabanında saklanması.
  - Oyuncu giriş yaptığında çevrimdışı geçen sürenin (offline progression) deterministik hesaplanarak köy durumunun senkronize edilmesi.
  - 500 CCU'yu kaldırabilecek connection pool ve asenkron mimari.
- [ ] **Godot Çevrimiçi Ağ Katmanı (NetworkClient / CloudSync)**:
  - Godot HTTPRequest tabanlı REST senkronizasyonu.
  - Çevrimdışı/çevrimiçi durum geçişi.

## 6. Uçtan Uca Simülasyon, Testler ve Ekran Görüntüleri
- [ ] Dokümantasyon kurallarına tam uyum testi (önkoşullar, hammadde maliyetleri, depo tavanı, nüfus, kışla, ittifak, kont fetih).
- [ ] Ekran görüntüsü (screenshot) doğrulaması ile UI çakışmalarının ve taşmalarının sıfırlanması.
