# King's Age Mobil — Oyun Analizi ve Plan

Bu depo, **King's Age** (Gameforge, incelenen sürüm **7.1.1**) oyununun tüm oyun mantığının
resmî yardım sitesinden çıkarılıp **eksiksiz dokümante edildiği** ve bu oyunun **mobil (Godot)**
bir yeniden yapımı için **plan** oluşturulduğu çalışma alanıdır.

> **Durum:** Şu an **kodlama yapılmıyor**. Bu faz yalnızca *analiz + dokümantasyon + plan* fazıdır.

---

## 1. Proje Kararları (kullanıcı onaylı)

| Konu | Karar |
|---|---|
| Doküman dili | 🇹🇷 Türkçe |
| Çok oyunculu yapı | **Önce tek oyunculu** (bot/AI rakiplerle oynanabilir sürüm), **sonra online** |
| Hedef teknoloji | **Godot** (GDScript, iOS + Android) |
| Grafik tarzı | **2.5D** (2D sprite katmanları + parçacık/ışık/parallax efektleri) |
| İsim ve görseller | **Özgün isim + özgün görseller** (mekanikler ve sayılar birebir) |
| Türkçe terimler | **Resmî TR kaynaktan** alınır (`s59-tr.kingsage.gameforge.com`) — kendi çevirimizi yapmıyoruz |
| Forum | **Hiç alınmayacak** (ittifak forumu ve tüm forum özellikleri) |
| Analiz derinliği | **Her şey, en ince detayına kadar** |

### Telif / hukuk notu
- Oyunun **mekanikleri, kuralları ve sayısal dengesi** (telif koruması kapsamı dışındaki fikir/veri)
  birebir modellenecek — kullanıcı kararı budur.
- **"KingsAge" adı, logosu, özgün görselleri, sesleri ve metinleri kullanılmayacak.**
  İsimler (bina, birim, kaynak, dünya adları) ve görseller **bize ait özgün** olacak.
- Karakter/yerleşim isimleri, ikonlar, UI görselleri ve oyun içi metinler sıfırdan üretilecek.

---

## 2. Doküman Haritası

| # | Dosya | İçerik |
|---|---|---|
| — | [`DURUM.md`](DURUM.md) | 🔴 **Devam dosyası** — sonraki oturum önce bunu okur |
| — | [`TASKS.md`](TASKS.md) | **Görev listesi (task breakdown)** |
| — | [`docs/TERIMLER.md`](docs/TERIMLER.md) | 🇹🇷 **Resmî Türkçe terimler** (EN ↔ TR) |
| — | [`docs/00-PROJE-OZETI-VE-KARARLAR.md`](docs/00-PROJE-OZETI-VE-KARARLAR.md) | Amaç, kapsam, fazlar, açık sorular |
| 01 | [`docs/01-KAYNAK-ANALIZI.md`](docs/01-KAYNAK-ANALIZI.md) | Help sitesi envanteri, veri toplama yöntemi, eşleşme tabloları |
| 02 | [`docs/02-OYUN-DONGUSU-VE-TERIMLER.md`](docs/02-OYUN-DONGUSU-VE-TERIMLER.md) | Çekirdek oyun döngüsü + terimler sözlüğü |
| 03 | [`docs/03-KAYNAKLAR-VE-SETTLER.md`](docs/03-KAYNAKLAR-VE-SETTLER.md) | Odun/Taş/Demir, vatandaşlar, depolama, Gizli Depo, Değirmen |
| 04 | [`docs/04-BINALAR.md`](docs/04-BINALAR.md) | 15 bina, rolleri, gereksinimler, techtree, inşaat kuyruğu, yıkım |
| 05 | [`docs/05-ASKERLER.md`](docs/05-ASKERLER.md) | 11 birim, araştırma, eğitim, istatistikler, limitler |
| 06 | [`docs/06-SAVAS-SISTEMI.md`](docs/06-SAVAS-SISTEMI.md) | Muharebe fazları, moral, şans, duvar, gece bonusu, kayıplar |
| 07 | [`docs/07-CASUSLUK.md`](docs/07-CASUSLUK.md) | Casusluk (normal + gizli), hesap, bilgi kademeleri |
| 08 | [`docs/08-FETIH.md`](docs/08-FETIH.md) | Fetih, **Güç Alanı**, Kont sayısı, Altın zırh |
| 09 | [`docs/09-KOMUTLAR-DESTEK-VE-YAGMA.md`](docs/09-KOMUTLAR-DESTEK-VE-YAGMA.md) | Saldırı emirleri, destek, talan, saldırı uyarı bayrakları |
| 10 | [`docs/10-HARITA-VE-DUNYA.md`](docs/10-HARITA-VE-DUNYA.md) | 1000x1000 dünya, kıtalar, miniharita, Simyager teknikleri |
| 11 | [`docs/11-OYUNCU-PUAN-KORUMA.md`](docs/11-OYUNCU-PUAN-KORUMA.md) | Puanlar, sıralamalar, inaktiflik, uyku modu, saldırı koruması |
| 12 | [`docs/12-ITTIFAKLAR.md`](docs/12-ITTIFAKLAR.md) | İttifaklar, rütbeler, diplomasi (**forum KAPSAM DIŞI**) |
| 13 | [`docs/13-PREMIUM.md`](docs/13-PREMIUM.md) | Kron, Kutsal Emanetler, Taht Salonu |
| 14 | [`docs/14-TICARET-VE-PAZAR.md`](docs/14-TICARET-VE-PAZAR.md) | Market, katırlar, hammadde takası |
| 15 | [`docs/15-MATEMATIK-VE-FORMULLER.md`](docs/15-MATEMATIK-VE-FORMULLER.md) | Türetilmiş formüller (maliyet, üretim, puan, savaş, fetih) + açık sorular |
| 16 | [`docs/16-GODOT-MOBIL-PLANI.md`](docs/16-GODOT-MOBIL-PLANI.md) | Teknoloji, mimari, 2.5D grafik, yol haritası |
| 18 | [`docs/18-SANAT-VE-ISIMLENDIRME.md`](docs/18-SANAT-VE-ISIMLENDIRME.md) | Özgün isim önerileri, görsel stil, **telif kontrol listesi** |
| ❌ | `docs/17-KURALLAR.md` | Kapsam dışı (kullanıcı kural sayfasını araştırma dışı bıraktı) |
| Ref | [`docs/reference/`](docs/reference/) | **Ham referans**: her bina ve birim için tam seviye tabloları (TR) |

---

## 3. Yapısal Veri (`data/`)

| Dosya | İçerik |
|---|---|
| [`data/buildings.json`](data/buildings.json) | 15 binanın tam seviye tabloları (wood/stone/iron, işçi, ek sütun) |
| [`data/units.json`](data/units.json) | 11 birimin maliyet/istatistik + araştırma/eğitim/savaş tabloları |
| [`data/building-points.json`](data/building-points.json) | Bina puan tablosu (seviye × bina) |

Bu JSON'lar ileride Godot tarafında **doğrudan veri kaynağı** olarak kullanılabilir.

---

## 4. Kaynak Veri Arşivi (`research/`)

| Yol | İçerik |
|---|---|
| `research/raw/*.html` | 🇬🇧 İndirilen **54** EN yardım sayfasının ham HTML'i |
| `research/text/*.txt` | EN sayfaların nav'dan arındırılmış metin hâli |
| `research/raw-tr/*.html` | 🇹🇷 İndirilen **52** TR yardım sayfasının ham HTML'i |
| `research/text-tr/*.txt` | TR sayfaların metin hâli |
| `research/urls.txt` | EN indirilen URL listesi |
| `research/urls-tr.txt` | TR indirilen URL listesi |
| `research/fetch-pages.ps1` | EN: doğrulamalı, oturumlu, yavaş indirme betiği |
| `research/fetch-tr.ps1` | TR: aynı mantıkla indirme betiği |
| `research/html2text.ps1` | HTML → metin dönüştürücü (`-RawDir` / `-TextDir`) |
| `research/make-docs.ps1` | Bina/birim referans Markdown + JSON üretici |
| `research/make-points.ps1` | Puan tablosu üretici |

---

## 5. Sıradaki Adım

→ [`DURUM.md`](DURUM.md) (devam dosyası) → sıradaki somut iş: **Faz 3 teknik tasarım** ve
**Godot proje iskeleti** (kod fazı başlangıcı, kullanıcı onayıyla).

> Şu an **kod yazılmıyor.** Dokümantasyon/plan tamamlanıyor.
