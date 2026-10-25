# ⚔️ Taht ve Kılıç (KingsAge 2) — Vercel & Cloudflare Canlı Dağıtım Rehberi

Bu rehber, oyunun **100'lerce eşzamanlı oyuncuyu destekleyen, SQL Injection ve hile korumalı, sunucu yetkili (Server-Authoritative)** mimariye taşınması ve **Vercel Free + Cloudflare Free** üzerinde canlıya alınması için adım adım hazırlanmıştır.

---

## 🏛️ 1. Mimari Nasıl Çalışır?

```
┌─────────────────────────────────┐
│     Godot İstemcileri           │
│  (iOS App Store, Android, PC)   │
└───────────────┬─────────────────┘
                │ HTTPS / JSON API (Bearer Token)
                ▼
┌─────────────────────────────────┐
│     Cloudflare (Free)           │ ── DDoS Koruması, SSL ve Hızlı CDN
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│      Vercel Serverless          │ ── FastAPI (Python 3.10+)
│      (server/api/index.py)      │ ── Yetkili Hesaplamalar (Maden, Ordu, Savaş)
└───────────────┬─────────────────┘
                │ SQL (Parametrik, %100 Injection Korumalı)
                ▼
┌─────────────────────────────────┐
│    Serverless Veritabanı        │ ── Turso (libSQL) / Supabase / Neon
│      (%100 Ücretsiz Katman)     │ ── Dünyalar, Köyler, Birlikler, Mesajlar
└─────────────────────────────────┘
```

---

## 🚀 2. Adım Adım Canlıya Alma Talimatları

### Adım 1: Ücretsiz Serverless Veritabanı Açma (Turso veya Supabase)

Vercel fonksiyonları durumsuz (stateless) çalıştığı için tüm oyuncuların verisini kalıcı tutacak **ücretsiz** bir veritabanı gereklidir:

#### Seçenek A: Turso (Önerilen — En Hızlı ve SQLite Uyumlu)
1. [turso.tech](https://turso.tech) adresine gidin ve ücretsiz hesap açın (GitHub ile giriş yapabilirsiniz).
2. `Create Database` butonuna basıp veritabanı adı olarak `kingsage-db` girin.
3. Size verilen **Database URL** (`libsql://kingsage-db-kullanici.turso.io`) ve **Auth Token**'ı kopyalayın.

#### Seçenek B: Supabase (PostgreSQL)
1. [supabase.com](https://supabase.com) adresine gidip ücretsiz proje açın.
2. `Project Settings -> Database -> Connection String` (URI) bölümündeki URL'yi kopyalayın.

---

### Adım 2: Sunucuyu Vercel'e Dağıtma

Projede hazır olan `server/` klasörü doğrudan Vercel uyumludur:

1. Projeyi GitHub'a push edin (veya Vercel CLI kullanın).
2. [vercel.com](https://vercel.com) adresine gidin -> **Add New... -> Project** seçin.
3. KingsAge 2 repository'nizi seçin.
4. **Root Directory** olarak `server` klasörünü seçin.
5. **Environment Variables** bölümüne:
   - `DATABASE_URL` = Adım 1'de aldığınız veritabanı bağlantı adresi.
6. **Deploy** butonuna basın!
7. 1 dakika içinde size özel canlı URL'niz hazır olacaktır (Örnek: `https://kingsage-server.vercel.app`).

---

### Adım 3: Cloudflare DNS ve DDoS Koruması (Opsiyonel ama Tavsiye Edilir)

Eğer kendinize ait bir alan adınız (domain) varsa:
1. Cloudflare panelinde alan adınızı ekleyin.
2. DNS ayarlarında CNAME kaydı açarak Vercel projenize yönlendirin (`cname.vercel-dns.com`).
3. Cloudflare Proxy (Turuncu Bulut) aktif kalarak DDoS koruması ve SSL sağlar.

---

### Adım 4: Godot Oyununu Canlı Sunucuya Bağlama

Vercel linkinizi aldıktan sonra oyunu canlıya bağlamak tek bir satırdır:

[NetworkManager.gd](file:///c:/Users/Gorkem/Desktop/kingsage2/game/autoload/NetworkManager.gd) dosyasını açın:
```gdscript
# Yerel geliştirme yerine Vercel linkinizi yazın:
const DEFAULT_SERVER_URL := "https://kingsage-server.vercel.app"
```

Artık oyun açıldığında:
- Google / Apple oturumları Vercel sunucusunda doğrulanır.
- Oyuncunun köyü, madenleri ve orduları doğrudan Vercel üzerinden veritabanına yazılır.
- Başka bir telefondan veya bilgisayardan giren diğer oyuncu, haritada canlı olarak görünür ve birbirlerine mektup yazıp ordu gönderebilirler.

---

## 🔒 3. Güvenlik Güvenceleri

| Güvenlik Kriteri | Nasıl Korunuyor? |
| :--- | :--- |
| **SQL Injection** | Tüm SQL sorguları `%100 Parametrik` (`?` veya `$1`) çalışır. Kullanıcı girdisi asla SQL stringine eklenmez. |
| **Hile / Memory Modding** | Maden artışı veya ordu üretimi istemcide yapılmaz. Sunucu her eylemi yetkili (authoritative) olarak denetler. |
| **Yetki Gaspı (IDOR)** | Her oyuncu sadece kendi köyüne emir verebilir (`village.owner == user.display_name`). Başkasının köyüne müdahale `403 Forbidden` ile reddedilir. |
| **Mesaj Gizliliği** | Gelen kutusunda her kullanıcı yalnızca `to_name == user` olan mektupları görebilir. |
| **XSS / HTML Temizliği** | Kullanıcı mektupları ve köy isimleri `html.escape()` ile temizlenir. |
| **15 Gün Başlangıç Koruması** | Yeni katılan köylere sunucu düzeyinde 15 gün fetih ve saldırı kalkanı atanır. |

---

## 🧪 4. Yerel Test (Bilgisayarınızda Çalıştırma)

Vercel'e göndermeden önce sunucuyu kendi bilgisayarınızda test etmek için:

```bash
cd server
python test_server_api.py
```

Tüm güvenlik ve entegrasyon testlerinin başarıyla geçtiğini (`PASS`) görebilirsiniz.
