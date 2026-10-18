# 09 — Komutlar, Destek ve Yağma

Kaynak: `units_attack`, `units_support`, `intro`

## 1. Saldırı Emirleri (Kışla üzerinden)

Birlikler **Kışla** üzerinden gönderilir. "Saldırı" (attack) mutlaka askerî bir saldırı olmak
zorunda değildir; kendi birliklerinizi yönlendirme komutudur.

| Komut | Hedef | Açıklama |
|---|---|---|
| **Attack (Saldırı)** | Düşman yerleşimi | Hedefe varınca **muharebe** başlar. Kazanılırsa **yağma** yapılır |
| **Conquer (Fetih)** | Düşman yerleşimi | **Kont** ile yerleşimi **kalıcı olarak** ele geçirme |
| **Espionage (Casusluk)** | Düşman yerleşimi | Casuslarla bilgi toplama (bkz. `07`) |
| **Support (Destek)** | Kendi / dost yerleşim | Savunma için birlik gönderme |

> Kısıtlar:
> - **Kendi yerleşimlerine saldırılamaz.**
> - **İttifak üyelerine saldırılamaz.**

---

## 2. Saldırı Koruması (özet)

> Tam detay: [`11-OYUNCU-PUAN-KORUMA.md`](11-OYUNCU-PUAN-KORUMA.md)

Oyuncular yerleşimlerini saldırıya karşı koruyabilir:

| Koruma | İçerik |
|---|---|
| **5 gün tam koruma** | İlk yerleşimden sonraki **5 gün** saldırılamaz. **Saldırı yaparsanız koruma biter.** |
| **Outlawed (kanun kaçağı)** | Tüm yerleşimler kalıcı korumada: **puanınızın 10 katından fazla** olan oyuncular saldıramaz |
| **Uyku modu (Sleep mode)** | Uyku modundaki oyunculara **saldırılamaz** |

> ⚠️ Zayıf oyuncular güçlerini birleştirip bir saldırı yaparsa **kanun kaçağı olur** ve
> **10:1 korumasını 2 ay boyunca kaybeder**.

---

## 3. Saldırı Uyarıları (Attack Warning)

Arayüzde **iki bayrak** bulunur:

| Bayrak durumu | Anlam |
|---|---|
| **İki bayrak da açık** | **Doğrudan siz** saldırıya uğruyorsunuz |
| **Yalnızca sağdaki açık** | **İttifak üyeleri** saldırıya uğruyor |

- Açık bayrağa tıklanınca **ilgili saldırıların özeti** açılır.

---

## 4. Destek (Support)

- Kendi birliklerinizi **dost/kendi yerleşimlere** gönderebilirsiniz.
- Vardıklarında **orada konuşlanır** ve yerleşimi savunur.
- Muharebede **yerel birlik gibi** işlem görürler → **yerel duvar ve anıt bonuslarından yararlanırlar**.
- Destekteki birlikler **ana yerleşimlerinde nüfus bağlamaya devam eder**;
  ölürlerse nüfus serbest kalır.
- Destek birlikleri başka yere kullanmak için **geri çağrılıp** yeni hedefe gönderilmelidir.
- **Bir yerleşimi destekleyen birlik sayısında sınır YOKTUR.**

---

## 5. Talan (Yağma)

1. Saldıran **muharebeyi kazanır**.
2. Hayatta kalan birimlerin **taşıma kapasiteleri toplanır**.
3. Bu toplam kadar kaynak **wood / stone / iron** olarak toplanır.
4. **Köyde kalan hammadde asla gizli depo (Hideout) kapasitesinden az olmaz.**
5. Birlikler **ana yerleşime döndüğünde** kaynaklar hesaba eklenir.

> Taşıma kapasiteleri: [`05-ASKERLER.md`](05-ASKERLER.md) (Taşıma sütunu)
> Gizli Depo kapasiteleri: [`reference/buildings/hide.md`](reference/buildings/hide.md)

---

## 6. İptal Süreleri (World ayarları)

| İşlem | İptal süresi |
|---|---|
| **Saldırı iptali** | **30 dakika** |
| **Katır (ticaret) iptali** | **15 dakika** |

> Kaynak: `worldinfo` → **Saldırı iptal zamanı**, **Katır - iptal zamanı** (Attack/Donkey cancellation time).
> Saldırılar hedefe varana kadar iptal edilebilir; iptal penceresi sunucuya göre değişir.
