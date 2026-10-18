# 04 — Binalar

> **Tam seviye tabloları (maliyet/işçi/ek sütun) için:** [`reference/buildings/`](reference/buildings/)
> **Yapısal veri:** [`../data/buildings.json`](../data/buildings.json)

## 1. Bina Listesi ve Rolleri

| Bina (EN) | **Resmî Türkçe** | Anahtar | Rol | Max Lv | Gereksinim |
|---|---|---|---:|---:|---|
| **Castle** | **Kale** | `main` | Köyün kalbi; inşaatları başlatır. Seviye ↑ → **daha çok inşaatçı → daha hızlı inşaat**. Lv15 + Simyager tekniği → **binayı yık** açılır | 50 | — |
| **Quarry** | **Taş ocağı** | `stone` | **Taş** üretir | 50 | — |
| **Sawmill** | **Oduncu Kampı** | `wood` | **Odun** üretir | 50 | — |
| **Ore Mine** | **Maden ocağı** | `iron` | **Demir** üretir | 50 | — |
| **Warehouse** | **Depo** | `storage` | Hammadde **saklama kapasitesi** | 50 | — |
| **Hideout** | **Gizli Depo** | `hide` | **Talan + casusluk** koruması | 30 | Değirmen Lv3 |
| **Miller** | **Değirmen** | `farm` | **Maksimum vatandaş** sayısı | 50 | — |
| **Barracks** | **Kışla** | `barracks` | Birlik **araştırma + eğitim**; seviye ↑ → **süre ↓** | 30 | Depo Lv3 **+** Değirmen Lv3 |
| **Town Wall** | **Sur** | `wall` | Savunmada **duvar bonusu** (%100→%220) | 20 | Kışla Lv1 |
| **Donkey Stable** | **Katır çiftliği** | `stable` | **Katır üretimi** (saatlik) | 30 | Market Lv1 |
| **Market** | **Market** | `market` | **Ticaret**; tutulabilecek **katır üst limiti** | 30 | Depo Lv5 |
| **Alchemist** | **Simyager** | `garage` | **Kalıcı teknik/bonus araştırması** | 5 | Kışla Lv5 |
| **Residence** | **Köşk** | `snob` | **Kont eğitimi** (fetih birimi) | 10 | Simyager Lv5 |
| **Goldsmith** | **Kuyumcu** | `smith` | **Altın zırh** üretimi (Kont için) | 5 | Köşk Lv1 |
| **Memorial** | **Anıt** | `statue` | **Tahkimatı %50 artırır**; güç/aura verir | 1 | **Tüm binalar maksimum** |

### Başlangıçta mevcut binalar
**Kale, Taş ocağı, Oduncu Kampı, Maden ocağı, Değirmen, Depo** hiçbir gereksinim istemez →
oyuncu bunlarla başlar.

---

## 2. Teknoloji Ağacı (Techtree)

Yardım sitesindeki grafik ağaç, bina detay sayfalarındaki **Requirements** tablolarından
birebir doğrulanarak aşağıdaki bağımlılık listesine dönüştürüldü:

```
(Kale, Taş ocağı, Oduncu Kampı, Maden ocağı, Değirmen, Depo)     ← serbest başlangıç

Değirmen Lv3 ────────────────────► Gizli Depo
Değirmen Lv3 + Depo Lv3 ─────────► Kışla
Kışla Lv1 ───────────────────────► Sur
Depo Lv5 ────────────────────────► Market
Market Lv1 ──────────────────────► Katır çiftliği
Kışla Lv5 ───────────────────────► Simyager
Simyager Lv5 ────────────────────► Köşk
Köşk Lv1 ────────────────────────► Kuyumcu
TÜMÜ MAKSİMUM ───────────────────► Anıt
```

### Yardım sitesindeki grafik ağaçta görünen "seviye düğümleri"
Bunlar, ilgili binanın **diğer binaları açan eşik seviyeleridir**:

| Bina | Ağaçta görünen seviyeler |
|---|---|
| Oduncu Kampı, Maden ocağı, Taş ocağı, Kale | 1 … 50 |
| Depo | 1, **3**, **5**, 50 |
| Değirmen | 1, **3**, 50 |
| Gizli Depo | 1 … 30 |
| Kışla | 1, **5**, 30 |
| Sur | 1 … 20 |
| Simyager | 1 … 5 |
| Köşk | 1 … 10 |
| Kuyumcu | 1 … 5 |
| Market | 1 … 30 |
| Katır çiftliği | 1 … 30 |
| Anıt | 1 |

---

## 3. İnşaat Kuralları

1. **Bina menüsü:** Kale menüsünden seçilir.
2. **Maliyet:** wood/stone/iron harcanır; **nüfus bağlanır**.
3. **Süre:** inşaat belirli bir süre sürer; süre bitince bina aktif olur.
4. **İptal:** inşaat **her an iptal edilebilir**; yatırılan kaynaklar **iade edilir**
   (kuyruk ek maliyetleri **iade edilmez**).
5. **Eşzamanlılık:** Bir yerleşimde **aynı anda tek inşaat** süreci çalışır.
6. **Kuyruk:** **3 inşaat işine kadar** kuyruk kullanılabilir; bu işler sırayla tamamlanır.
7. **Ek maliyet:** 3'ten fazla iş kuyruğa konulursa **maliyet artar**:

| Kuyruktaki iş | Ek maliyet |
|---:|---:|
| 1 | 0% |
| 2 | 0% |
| 3 | 0% |
| 4 | +25% |
| 5 | +56% |
| 6 | +95% |
| 7 | +144% |
| 8 | +205% |
| 9 | +281% |
| 10 | +376% |

> **Premium hesap:** inşaat kuyruğu **sınırsız** ve **ek maliyet yok**.

8. **Yıkım (Tear down):** Kale **Lv15** olduğunda ve **Simyager'da ilgili teknik** araştırıldığında
   bina yıkılabilir.

---

## 4. Özel Mekanikler

### Castle (Kale)
- Yerleşimin merkezi; inşaatlar burada yönetilir.
- Seviye ↑ → **daha çok inşaatçı** → inşaatlar **daha hızlı**.
- **Lv15 + Simyager tekniği** → bina **yıkma** açılır.

### Memorial (Anıt)
- Kale meydanındaki devasa heykel; **tahkimatı %50 artırır**.
- Ek olarak: **fetih sırasında "realm of power" kaybını azaltır**
  (bkz. `08-FETIH.md` → normalde 2.250–2.750, anıt varsa 1.750–2.250).
- **Yalnızca tüm binalar tam geliştirildiğinde** inşa edilebilir (tek seviye).

### Alchemist (Simyager)
- Kaynak harcayarak **teknik (technique)** araştırılır → **kalıcı bonus**.
- Araştırılan teknik **bir kez** yapılır → **tüm yerleşimlerde global** olur, tekrar gerekmez.
- Bazı teknikler **haritada** etki eder ve **harita ayarlarından ayrıca aktif edilmelidir**.
- Laboratuvar seviyesi ↑ → araştırma **daha başarılı**.
- Bilinen teknikler: **bina yıkma (Kale Lv15 ile)**, **detaylı genel bakış (premium ile)**,
  **harita vurgulama** vb. → *tam teknik listesi yardım sitesinde yok* (bkz. Açık Sorular).

### Residence (Köşk) ve Kont
- **Kont**, Kışla yerine **Köşk'ta** eğitilir; **eğitim süresi Köşk seviyesine** bağlıdır.
- Kont **araştırılmaz** (Kışla istisnası).

### Goldsmith (Kuyumcu) ve Altın Zırh
- **Altın Zırh** burada üretilir; **Kont** atamak için gereklidir.
- **Her yeni zırh setinde maliyet artar** ("her kont bir öncekinden daha görkemli zırh ister").
- Zırh, **yeni bir yerleşimi yönetmek üzere Kont atandığında** kullanılır.

### Katır çiftliği ve Market
- Katırlar Market'te **hammadde taşımak** için kullanılır.
- **Temel katır üretimi** vardır (saatlik); **çiftlik seviyesi üretimi artırır**,
  **Market seviyesi maksimum katır sayısını** belirler.
- Katır hedefe vardığında **geri dönmez** → yenisinin üretilmesi gerekir.
  Katır köyden ayrılır ayrılmaz **yeniden üretilmeye başlar**.
- Detaylar: [`14-TICARET-VE-PAZAR.md`](14-TICARET-VE-PAZAR.md)

### Barracks (Kışla)
- Birim **araştırma** ve **eğitim** burada yapılır.
- Seviye ↑ → **araştırma ve eğitim süresi azalır**.
- Askerlerin **bakım maliyeti yoktur**; sayı **nüfusla** sınırlıdır.

---

## 5. Bina Seviye Tabloları — Sütun Anlamları

Her bina detay sayfasında şu tablo vardır:

| Sütun | Anlam |
|---|---|
| **Level** | Hedef seviye (o seviyeye çıkmak için gereken) |
| **İhtiyaç (Taş/Odun/Demir)** | O seviyeye çıkmak için gereken hammaddeler |
| **Workers per level/Total** | Bu seviyede **bağlanan** nüfus / **toplam bağlı** nüfus |
| **Bina özel sütun** | Üretim / kapasite / vatandaş / katır / duvar bonusu / time factor |

> ⚠️ **`Time factor` sütunu:** Her seviyede azalan bir yüzde (ör. Kışla Lv1 %80 → Lv30 %10).
> **İnşaat süresinin kesin hesabı yardım sitesinde verilmiyor.** (Bkz. Açık Sorular.)
