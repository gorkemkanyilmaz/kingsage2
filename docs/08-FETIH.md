# 08 — Fetih (Conquer) ve Realm of Power

Kaynak: `units_conquer`, `player_points`, `worldinfo`, `units_snob`

## 1. Temel Kavram: Realm of Power (Etki Alanı)

- **Realm of Power**, bir yerleşim üzerindeki **etkinin soyut göstergesi**dir.
- **Aralık:** `0` … **yerleşimin maksimum puanı**.
- **Köy Puanı** **asla 10.000'i geçemez** → güç alanı da **en fazla 10.000** olabilir.
- **Yenilenme (regeneration):** Değer maksimumun altındaysa **saat başına maksimumun %1'i kadar** artar.
- **Fetih:** Realm of Power **0'a düşerse** yerleşim fethedilir ve **saldıranın malı olur**.

## 2. Fetih Süreci

1. **Kont (Count)** ile saldırılır. Saldıran orduda Kont olmalıdır.
2. Muharebe kazanılır ve **Kont hayatta kalırsa** → yerleşimin **realm of power'ı düşürülür**.
3. **Güç Alanı** **0'a inerse** → yerleşim, **son hasarı veren Kont'un sahibine** geçer.

### Realm of Power düşüşü (hasar başına)
| Durum | Düşüş (rastgele) |
|---|---|
| Normal | **2.250 – 2.750** |
| Yerleşimde **Anıt (Memorial)** varsa | **1.750 – 2.250** |

### Önemli kurallar
- **Kapak (cap):** Gerçek sayı ne olursa olsun, bir Kont realm of power'ı **en fazla maksimumun yarısı kadar**
  azaltabilir. *(Bu yüzden düşük puanlı yerleşimlerde tek Kont yetmez.)*
- **Saldırı başına yalnızca 1 Kont etkilidir** (*"Only one count can be effective per attack"*).
- **Her yerleşim için en az 2 Kont, 2 ayrı saldırıda** gerekir.
- **Tam gelişmiş (10.000 puanlı) + Anıtlı** bir yerleşim için **en az 5–6 Kont** (yani 5–6 saldırı) gerekir.

### Fetih sonrası
- Yeni sahibinin realm of power'ı **hemen maksimumun %30'una** yükselir.

## 3. Kont (Count) Gereksinimleri

- Kont **araştırılmaz**, doğrudan **Köşk'ta** eğitilir.
- Eğitim için **Altın Zırh** gerekir → **Kuyumcu (Goldsmith)**'te üretilir.
- Her yeni Altın Zırh setinde **maliyet artar**.
- Kont **eğitim maliyeti:** 120.000 wood / 100.000 stone / 80.000 iron + **100 nüfus**.
- Kont **eğitim süresi:** 2:30:00 (Köşk seviyesine bağlı).
- **Kont'un ölüm koşulu:** Orduda başka birlik kalmamışsa (ve muharebe olduysa) **veya**
  saldıranın birimlerinin **%50'si ölmüşse** → **Kont ölür**.

## 4. Sunucu Ayarları (World 59)

| Ayar | Değer |
|---|---|
| **Kont'un maksimum seyahat mesafesi** | **100 alan (fields)** |
| Realm of Power düşüşü | 2.250–2.750 (Anıtlı: 1.750–2.250) |
| Saatlik güç alanı artışı | Köy Puanının **%1'i** |
| Fetih koruması (yeni oyuncu, faz 2) | **7 gün** |
| **Anıt (Memorial) şartı** | **Tüm binalar maksimum seviyede** |

> ⚠️ **Kont mesafesi 100 alan:** Bu, oyuncuyu coğrafi olarak sınırlar; hedef yerleşim
> Kont'un bulunduğu yerleşimden **100 alandan uzakta olamaz**.

## 5. Fetih ve Yerleşim Sayısı

- Fetih, oyuncunun **yeni bir yerleşim** kazanmasının yoludur.
- **Toplam puan** hesabında, **ilk yerleşim hariç** her yerleşim için **+2.500 bonus puan** eklenir:
  ```
  Toplam Puan = (tüm yerleşim puanları) + 2.500 × (yerleşim sayısı − 1)
  ```
- Yerleşim **terk edilmişse (abandoned)** hiçbir koruması yoktur; **1:10 puan farkı olan oyuncular**
  bile saldırıp fethedebilir.

## 6. İlgili Kurallar

- Fetih koruması detayları: [`11-OYUNCU-PUAN-KORUMA.md`](11-OYUNCU-PUAN-KORUMA.md)
- Altın Zırh / Kuyumcu: [`04-BINALAR.md`](04-BINALAR.md)
- Yağma: [`09-KOMUTLAR-DESTEK-VE-YAGMA.md`](09-KOMUTLAR-DESTEK-VE-YAGMA.md)
