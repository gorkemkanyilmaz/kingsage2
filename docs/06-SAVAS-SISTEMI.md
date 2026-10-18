# 06 — Muharebe Sistemi (Battles)

Kaynak: `units_battle`, `units_attack`, `intro`, `worldinfo`

## 1. Muharebe Akışı (fazlar)

Bir yerleşime saldırıldığında muharebe **5 fazda** çözülür:

```
1) Duvar hasarı        (Şahmerdan / Battering ram)
2) Casus muharebesi    (varsa casuslar)
3) Normal birlik muharebesi  (saldırı ↔ savunma değerleri)
4) Bina hasarı         (Mancınık / Trebuchet; savunanın kaybına bağlı)
5) Fetih ve Yağma      (Kont / taşıma kapasitesi)
```

> Birimler **bir taraf tamamen yok edilene kadar** savaşır. Bu sırada yerleşimde
> **kalıcı hasar** oluşabilir (duvar ve diğer binalar).

### Faz 1 — Duvar hasarı
- Muharebe başlamadan **önce** şehir duvarının değeri düşürülür.
- Bunun için saldıran orduda **Şahmerdan (battering ram)** olmalıdır.
- Duvarın seviyesi, **taşınan koçbaşı sayısına göre** düşer.

### Faz 2 — Casus muharebesi
- Saldıran orduda **casus** varsa, muharebe başlamadan **casusluk normal şekilde hesaplanır**.
  (Bkz. [`07-CASUSLUK.md`](07-CASUSLUK.md))

### Faz 3 — Normal birlik muharebesi
- Birimlerin **saldırı değerleri** ile savunanın **savunma değerleri** karşılaştırılır.
- Değerler **dış etkenlerle değiştirilebilir** (aşağıya bakınız).
- Karşılaştırma sonrası **kayıplar** belirlenir.

### Faz 4 — Bina hasarı
- Saldırı sonunda diğer binaların yıkımı **tam olarak hesaplanır**.
- Formül: **savunanın kayıpları** + **saldıranın mancınık sayısına** bağlıdır.

### Faz 5 — Fetih ve Yağma
- Saldıran **kazandıysa**:
  - Hayatta kalan birlikler **taşıma kapasitesi** kadar **yağma** yapar ve ganimeti **ana yerleşime** götürür.
  - Hayatta kalan **Kont** varsa **fetih** başlar → **realm of power** düşürülür.
- Yağmadan sonra **realm of power yeniden hesaplanır**; yıkılan bina varsa bu hesabı etkiler.

---

## 2. Saldıran Tarafın Değiştiricileri (modifiers)

| Etken | Etki | Aralık |
|---|---|---|
| **Moral (Morale)** | Güçlü saldıranın birim etkinliğini düşürür | **%30 – %100** |
| **Şans (Luck)** | Her muharebede rastgele seçilir | **−%25 … +%25** |

### Moral
- **Saldıranın tüm yerleşimlerinin toplam puanı**, **savunanın toplam puanıyla** karşılaştırılır.
- Saldıran daha güçlüyse → **saldıranın birim etkinliği (morali) düşer**.
- Moral her zaman **%100 ile %30 arasında** kalır.
- Amaç: **aşırı güçlü oyuncuların küçük oyuncuları ezmesini engellemek.**

### Şans
- Her muharebede **rastgele** belirlenir; muharebe gücünü **−%25 ile +%25** arasında etkiler.

---

## 3. Savunan Tarafın Değiştiricileri (bonuslar)

| Etken | Etki | Aralık |
|---|---|---|
| **Duvar bonusu (Sur)** | Tüm savunma değerlerini artırır | **%105 (Lv1) → %220 (Lv20)** |
| **Gece bonusu (Night bonus)** | Gece penceresinde **tüm birimlerin savunma gücü ×2** (sunucu ayarı) | ×2 |
| **Anıt (Memorial)** | Tahkimatı **%50** artırır | +%50 |
| **Destek birlikleri** | Yerleşimde bulunan destek birimleri **yerel duvar/anıt bonusundan yararlanır** | — |

### Duvar bonusu — tam değerler
| Lv | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| Bonus | 100% | 105% | 109% | 114% | 118% | 123% | 128% | 133% | 138% | 143% | 149% |

| Lv | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| Bonus | 155% | 161% | 168% | 174% | 181% | 188% | 196% | 204% | 212% | 220% |

### Gece bonusu — sunucuya göre
- Yardım metni: **00:00–08:00 arası savunma gücü iki katına çıkar**.
- ⚠️ **World 59 ayarlarında gece bonusu "inactive"** olarak listeleniyor →
  bu **sunucu bazlı bir ayardır**; oyunumuzda ayarlanabilir olmalı.
- Gece bonusu dışında başka savunma bonusu **yoktur**.

---

## 4. Kayıplar ve Kont'un Ölüm Koşulu

- Kayıplar, (modifiye edilmiş) saldırı ve savunma değerlerinin karşılaştırılmasıyla belirlenir.
- **Kont'un ölüm koşulu:**
  - ordudan **başka birlik kalmamışsa** ve muharebe gerçekleştiyse, **veya**
  - saldıranın birimlerinin **%50'si öldüyse**
  → **Kont ölür.**

---

## 5. Talan (Yağma)

- Saldıran **kazandıysa**, hayatta kalan birimlerin **taşıma kapasitesi toplanır**.
- Bu toplam kadar kaynak **üç tipe bölünerek** (wood/stone/iron) ana yerleşime taşınır.
- **Köyde kalan hammadde asla gizli depo (Hideout) kapasitesinden az olmaz.**
- Ganimet, birlikler **ana yerleşime döndüğünde** hesaba eklenir.

---

## 6. Muharebe Sonuçları

| Sonuç | Açıklama |
|---|---|
| **Kayıplar** | İki tarafta da birim kaybı; kaybedilen birimlerin nüfusu serbest kalır |
| **Duvar hasarı** | Şahmerdan ile duvar seviyesi düşer |
| **Bina hasarı** | Mancınık ile binalar zarar görür (kalıcı) |
| **Talan** | Kazanan hammadde götürür (gizli depo korur) |
| **Fetih** | Kont ile realm of power düşer → 0 olunca yerleşim el değiştirir |

---

## 7. Muharebe Raporları

- **Battle report (muharebe raporu):** muharebeden sonra saldırana/savunana gönderilir.
- **Spy report (casus raporu):** casusluk tamamlandığında oluşur.
- Rapor saklama süreleri: [`11-OYUNCU-PUAN-KORUMA.md`](11-OYUNCU-PUAN-KORUMA.md)
  ve `reference` altındaki mesaj kurallarına bakınız.
