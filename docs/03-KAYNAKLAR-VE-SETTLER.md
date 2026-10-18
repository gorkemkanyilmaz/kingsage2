# 03 — Hammaddeler, Vatandaşlar ve Depolama

> 🇹🇷 Resmî terimler: [`TERIMLER.md`](TERIMLER.md) — **Odun / Taş / Demir / Vatandaş / Depo / Gizli Depo / Değirmen**

## 1. Kaynak Türleri

Oyunda **3 hammadde** + **vatandaşlar** vardır:

| Hammadde | Üretildiği bina | İkon | Nitelik |
|---|---|---|---|
| **Odun** (Wood) | **Oduncu Kampı** (Sawmill) | `res1.png` | Tüketilebilir |
| **Taş** (Stone) | **Taş ocağı** (Quarry) | `res2.png` | Tüketilebilir |
| **Demir** (Iron) | **Maden ocağı** (Ore Mine) | `res3.png` | Tüketilebilir |
| **Vatandaşlar** (Settlers) | **Değirmen** (Miller) | `worker.png` | **Tükenmez, bağlanır** |

### Hammaddeler (Odun / Taş / Demir)
- Neredeyse **tüm aksiyonlar** için gerekir.
- İlgili binalarda **sürekli (saatlik)** üretilir.
- **Market** üzerinden takas edilebilir / satılabilir / satın alınabilir.
- **Depo (Warehouse)** kapasitesi kadar saklanabilir. **Kapasite aşılırsa hammadde kaybolur.**
- **Gizli Depo** kapasitesine kadar **talandan** korunur.

### Vatandaşlar (Settlers)
- Hammaddenin aksine **tükenmez**; bina/birliklere **bağlanır** ve o nesne var olduğu sürece bağlı kalır.
- Her köyün **kendi vatandaş havuzu** vardır.
- Bir nesne vatandaşın bir kısmını **bağlar** → bu kısım **"çalışan vatandaş"**,
  kalan **"boş vatandaş"**.
- Yeterli boş vatandaş yoksa **aksiyon yapılamaz** (inşa/eğitim bloke).
- **Toplam vatandaş yalnızca Değirmen geliştirildiğinde artar.** Sürekli üretilmez.
- **Vatandaş serbest bırakma:** Bina/birlik yok olursa (yıkım, savaşta ölüm) bağlı vatandaş serbest kalır.
- ⚠️ **Önemli kural:** Köyden ayrılan birlikler, **savaşta ölene kadar** ait oldukları köydeki
  vatandaşı **bağlı tutmaya devam eder**.

---

## 2. Depolama ve Koruma

| Bina | İşlev | Sütun |
|---|---|---|
| **Depo** (Warehouse) | Hammadde **saklama üst sınırı** | *Capacity* |
| **Gizli Depo** (Hideout) | **Talandan korunan** hammadde miktarı; ayrıca **casuslara karşı korur** | *Capacity* |

- **Talan kuralı:** Bir köyde kalan hammadde **asla gizli depo kapasitesinden az olamaz.**
  (Yani en az gizli depo kadar hammadde her zaman korunur.)
- Gizli Depo ayrıca **hırsız ellere ve casus gözlerine** karşı korur.

### Referans tabloları
- Depo kapasitesi: [`reference/buildings/storage.md`](reference/buildings/storage.md)
- Gizli Depo kapasitesi: [`reference/buildings/hide.md`](reference/buildings/hide.md)
- Maksimum vatandaş: [`reference/buildings/farm.md`](reference/buildings/farm.md)

### Örnek değerler (ham yardım tablolarından)
| Seviye | Depo kapasitesi | Gizli Depo | Maks. vatandaş |
|---:|---:|---:|---:|
| 1 | 1.000 | 150 | 250 |
| 5 | 1.750 | 301 | 385 |
| 10 | 3.523 | 718 | 662 |
| 20 | 14.277 | 4.088 | 1.951 |
| 30 | 57.853 | 23.278 | 5.751 |
| 50 | 950.000 | — (max 30) | 50.000 |

*(Kesin ve tam değerler için yukarıdaki referans dosyalarına bakınız.)*

---

## 3. Hammadde Üretimi

- **Oduncu Kampı / Taş ocağı / Maden ocağı** saatte hammadde üretir. Üretim **bina seviyesiyle katlanarak** artar.
- Üretim binalarının tablosundaki son sütun: **Production per hour**.

| Seviye | Üretim / saat (üç maden için aynı eğri) |
|---:|---:|
| 1 | 120 |
| 2 | 134 |
| 5 | 185 |
| 10 | 319 |
| 20 | 948 |
| 30 | 2.815 |
| 40 | 8.355 |
| 50 | 24.800 |

> Not: Yardım sitesi üretimin **vatandaş başına** mı yoksa **bina başına** mı olduğunu netleştirmiyor;
> tabloda tek bir "Production per hour" değeri var. (Bkz. `15-MATEMATIK-VE-FORMULLER.md`)

---

## 4. Vatandaşın Kısıtlayıcı Rolü

- **Binalar** ve **birlikler** vatandaş bağlar.
- Yeni vatandaş **yalnızca Değirmen** geliştirilerek kazanılır.
- **Sonuç:** Değirmen seviyesi tüm köyün "tavan"ını belirler — hem bina gelişimi hem ordu
  büyüklüğü Değirmen ile sınırlıdır.
- Yardım metni: *"Ordular için bakım maliyeti yoktur, fakat birlik sayısı mevcut vatandaşla sınırlıdır."*
