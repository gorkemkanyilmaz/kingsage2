# 01 — Kaynak Analizi, Sayfa Envanteri ve Veri Toplama Yöntemi

## 1. Kaynak Yapısı

**İki kaynak paralel kullanıldı:**
- 🇬🇧 İngilizce: `https://s59-en.kingsage.gameforge.com/help.php` → `research/raw/`, `research/text/`
- 🇹🇷 Türkçe (resmî): `https://s59-tr.kingsage.gameforge.com/help.php` → `research/raw-tr/`, `research/text-tr/`

> 🇹🇷 **Türkçe adlar ve terimler yalnızca resmî TR kaynaktan alınır.** Tam sözlük: [`TERIMLER.md`](TERIMLER.md)

Yardım sitesi tek bir PHP giriş noktası kullanır:

```
https://s59-en.kingsage.gameforge.com/help.php?m=<modul>[&sub=<alt>][&build=<bina>][&unit=<birim>]
```

- `m` → ana modül (ör. `buildings`, `units`, `player`, `villages`)
- `sub` → alt sekme (ör. `details`, `attack`, `conquer`)
- `build` / `unit` → detay kimliği (ör. `barracks`, `spear`)

### Gezinme (nav) yapısı
Üst menü: `Help | Forum | Logout | Rules | Legal | T&Cs | Privacy Policy`
Sekmeler: `Introduction`, `Premium`, `Alliances`, `BB-Codes`, `Other Information`
Sağ kısayollar: `Player`, `Settlements`, `Buildings`, `Units`, `Map`

**Kapsam dışı bırakılanlar (kullanıcı talimatı):** Help(kendisi), Forum, Logout, Rules, Legal,
T&Cs, Privacy Policy, Change-logs. *(Rules yine de arşivlendi, bkz. `17-KURALLAR.md`.)*

---

## 2. İndirilen Sayfa Envanteri (54 sayfa)

### Ana modüller (11)
| Dosya | URL |
|---|---|
| `index` / `intro` | `help.php` , `help.php?m=intro` |
| `premium` | `?m=premium` |
| `ally` | `?m=ally` |
| `bbcodes` | `?m=bbcodes` |
| `worldinfo` | `?m=worldinfo` |
| `player` | `?m=player` |
| `villages` | `?m=villages` |
| `buildings` | `?m=buildings` |
| `units` | `?m=units` |
| `map` | `?m=map` |

### Bina detayları (15 + 1 genel)
`main` Castle · `stone` Quarry · `wood` Sawmill · `iron` Ore Mine · `storage` Warehouse ·
`hide` Hideout · `farm` Miller · `barracks` Barracks · `wall` Town Wall · `stable` Donkey Stable ·
`market` Market · `garage` Alchemist · `snob` Residence · `smith` Goldsmith · `statue` Memorial
(+ `?m=buildings&sub=details` → genel "Buildings" sayfası)

### Birim detayları (11)
`farmer` Farmer's militia · `spear` Squire · `sword` Templar · `axe` Berserker · `bow` Long-bow ·
`spy` Spy · `light` Crusader · `heavy` Black knight · `ram` Battering ram · `kata` Trebuchet ·
`snob` Count

### Alt sekmeler
- `units`: `attack`, `support`, `espionage`, `conquer`, `battle`, `snob`
- `player`: `player`, `points`, `ranking`, `friends`, `messages`, `trade`
- `villages`: `resources`, `favorites`

---

## 3. Anahtar Eşleşmeleri (URL anahtarı → oyundaki isim)

> **Resmî Türkçe adlar** TR kaynaktan alınmıştır; tam sözlük: [`TERIMLER.md`](TERIMLER.md).

### Binalar
| Anahtar | İsim (EN) | **Resmî Türkçe** | Max Lv |
|---|---|---:|---:|
| `main` | Castle | **Kale** | 50 |
| `stone` | Quarry | **Taş ocağı** | 50 |
| `wood` | Sawmill | **Oduncu Kampı** | 50 |
| `iron` | Ore Mine | **Maden ocağı** | 50 |
| `storage` | Warehouse | **Depo** | 50 |
| `hide` | Hideout | **Gizli Depo** | 30 |
| `farm` | Miller | **Değirmen** | 50 |
| `barracks` | Barracks | **Kışla** | 30 |
| `wall` | Town Wall | **Sur** | 20 |
| `stable` | Donkey Stable | **Katır çiftliği** | 30 |
| `market` | Market | **Market** | 30 |
| `garage` | Alchemist | **Simyager** | 5 |
| `snob` | Residence | **Köşk** | 10 |
| `smith` | Goldsmith | **Kuyumcu** | 5 |
| `statue` | Memorial | **Anıt** | 1 |

### Birimler
| Anahtar | İsim (EN) | **Resmî Türkçe** | Sınıf |
|---|---|---|---|
| `farmer` | Farmer's militia | **Köy Koruyucusu** | Piyade |
| `spear` | Squire | **Silahtar** | Piyade |
| `sword` | Templar | **Muhafız** | Piyade |
| `axe` | Berserker | **Baltacı** | Piyade |
| `bow` | Long-bow | **Okçu** | Okçu |
| `spy` | Spy | **Casus** | Özel |
| `light` | Crusader | **Akıncı** | Süvari |
| `heavy` | Black knight | **Kara Şövalye** | Süvari |
| `ram` | Battering ram | **Şahmerdan** | Kuşatma |
| `kata` | Trebuchet | **Mancınık** | Kuşatma |
| `snob` | Count | **Kont** | Özel (fetih) |

---

## 4. Veri Toplama Yöntemi (tekrarlanabilir)

1. **İndirme:** `research/fetch-pages.ps1`
   - Sunucu, hızlı ardışık isteklerde **doğru sayfa yerine "Introduction" içeriğini döndürüyor**
     (rate-limit kaynaklı fallback). Bu yüzden betik:
     - kalıcı bir oturum (cookie) açar,
     - her isteğe `Referer` ekler,
     - yanıtın **fallback olup olmadığını doğrular** (Introduction metni var mı?),
     - hatalıysa bekleyip **yeniden dener** (5 sn aralıkla, 6 deneme).
2. **Metne çevirme:** `research/html2text.ps1` → `class="contentpane"` içeriğini ayıklar,
   tabloları Markdown'a çevirir → `research/text/*.txt`
3. **Yapısal veri + referans:** `research/make-docs.ps1` → `data/buildings.json`, `data/units.json`,
   `docs/reference/buildings/*.md`, `docs/reference/units/*.md`
4. **Puan tablosu:** `research/make-points.ps1` → `data/building-points.json`, `docs/reference/puan-tablosu.md`

### Kritik teknik detaylar
- **Kaynak ikonları:** `res1.png = Wood`, `res2.png = Stone`, `res3.png = Iron`.
  Tablo sütunları görselde **Stone, Wood, Iron** sırasıyla gelir; JSON'da **Wood/Stone/Iron**
  olarak normalize edildi.
- **Binler ayırıcı:** sayfada `1.160` = 1160. Parser noktayı temizler.
- **Tablo sütunları:** `Level | Demand(Wood,Stone,Iron) | Workers per level/Total | <bina özel sütun>`
  - Bina özel sütun: üretim binalarında **Production per hour**, depoda **Capacity**,
    değirmende **Maximum settlers**, pazarda **Amount of donkeys**, duvarda
    **Reinforcement for defence units**, kalelerde **Time factor**.
- **Birim tabloları:** Araştırma = `res2/res1/res3 + süre`; Eğitim = `res2/res1/res3 + işçi + süre`;
  Muharebe = `saldırı | sav.piade | sav.süvari | sav.okçu | hareketlilik | taşıma`.
- **Hız:** Detay sayfalarında **"X Minutes per field"** (kesin, ör. Silahtar 4.5).
  Genel tablodaki **Mobility** yuvarlanmış tamsayıdır (Silahtar 5). **Oyun için detay değeri esas.**

---

## 5. Doğrulama

- 54/54 sayfa "gerçek içerik" doğrulamasından geçti (fallback yok).
- Örnek doğrulama: Kışla Lv2 → Wood 218 / Stone 221 / Iron 146 (kaynak HTML ile birebir).
- Bina gereksinimleri ham HTML'deki `<a>` linklerinden yeniden çıkarıldı ve çapraz kontrol edildi.
