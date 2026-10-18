# 02 — Çekirdek Oyun Döngüsü ve Terimler

> 🇹🇷 **Türkçe terimler resmî TR kaynaktan alınmıştır.** Tam sözlük: [`TERIMLER.md`](TERIMLER.md)
> ⚠️ Bu dosyada İngilizce terimler **yalnızca kaynak eşleştirmesi** için parantez içinde verilir.

---

## 1. Oyuncu ve Köy

- Oyuncu, **birden fazla köyü** yöneten bir kraldır.
- Her **köyün** (yerleşim biriminin) haritada **kendine ait bir pozisyonu (koordinatı)** ve **adı** vardır.
- Bir köyün sahibi yoksa → **terkedilmiş köy**; bu köyleri **soyguncular** kontrol eder;
  onlar da bina inşa eder, askerî birlik oluşturur ve **köyün puanını artırırlar**.
- Köy geliştikçe **puanı** ve **güç alanı** artar → daha güçlü ve **fethedilmesi daha zor** olur.

### Başlangıç
- Oyuncu **yön seçimi (oryantasyon)** yapar; köy o yöne göre **haritada rastgele** yerleştirilir.
- Oyuncu **Kale menüsünden** hangi binayı inşa edeceğine/geliştireceğine karar verir.
- Bazı **bina seviyeleri ve kombinasyonları** daha fazla **bina seçeneğini** aktif eder (bkz. `04-BINALAR.md`).

---

## 2. Çekirdek Oyun Döngüsü

```
        ┌──────────────────────────────────────────────────────────────┐
        │                                                              │
        ▼                                                              │
  [Hammadde Üret] ─► [İnşa Et / Geliştir] ─► [Araştır] ─► [Eğit]
   odun/taş/demir        binalar              kışlada       kışlada
        ▲                                                      │
        │                                                      ▼
  [Talan ganimeti]  ◄──────────────────────────────────  [Saldırı]
        ▲                                                      │
        │                                                      ▼
  [Yeni Köy]  ◄──── [Kont + Altın zırh] ◄──── [Fethetmek] ◄──────┘
        │
        └──► (döngü baştan: daha çok hammadde, daha çok bina, daha çok asker)
```

### Adım adım
1. **İnşa et:** Kale menüsünden bina inşa/geliştir. **Hammaddeler** harcanır, **vatandaş** bağlanır.
2. **Hammaddeler:** Odun / Taş / Demir ilgili binalarda **sürekli** üretilir, **Depo**'da saklanır.
   Depo dolduğunda fazlası kaybolur. **Gizli Depo** kaynağı **talandan** korur.
3. **Vatandaşlar:** Toplam nüfus **yalnızca Değirmen geliştirilince** artar; sürekli üretilmez.
   Binalar ve birlikler vatandaş **bağlar**. Boş vatandaş yoksa hiçbir şey yapılamaz.
4. **Ticaret:** **Market** + **katırlar** ile hammaddeler takas edilir.
5. **Eğit:** İlk genişleme safhasından sonra **Kışla** açılır → birlik **araştırılır** ve **eğitilir**.
   Birliklerin **bakım maliyeti yoktur**; sayıları **nüfusla** sınırlıdır.
6. **Saldırı:** Düşman köyüne saldırı → **savaş** → **talan** (yağma) veya **fetih**.
7. **Fethetmek:** **Kont** ile köyün **güç alanını** 0'a düşür → köy sana geçer → **yeni köy** (döngü büyür).

---

## 3. Terimler Sözlüğü

> Tam ve ayrıntılı tablo: [`TERIMLER.md`](TERIMLER.md). Aşağıda en kritik kavramlar özetlenmiştir.

| Kavram (TR, resmî) | İngilizce (kaynak) | Anlam |
|---|---|---|
| **Köy** (yerleşim birimi) | Settlement | Koordinatı ve adı olan, binaları barındıran birim |
| **Terkedilmiş köy** | Abandoned settlement | Sahipsiz; soyguncuların yönettiği köy |
| **Bonus köy** | Bonus settlement | Başında **'Usta'** olan, tek bonus veren köy |
| **Vatandaş / Vatandaşlar** | Settler(s) | Bina/birlikleri "bağlayan" kısıtlı kaynak |
| **Boş vatandaş** | Free settlers | Kullanılmayan nüfus |
| **Çalışan vatandaş** | Employed settlers | Bina/birliğe bağlanmış nüfus |
| **Hammaddeler** | Resources | **Odun**, **Taş**, **Demir** |
| **Depo** | Warehouse | Hammadde saklama üst sınırı |
| **Gizli Depo** | Hideout | Talandan ve casus gözlerinden korunan miktar |
| **Değirmen** | Miller | Maksimum vatandaş sayısını belirler |
| **Katır** | Donkey | Ticaret taşıma aracı; **Katır çiftliği**'nde üretilir |
| **Köy Puanı** | Settlement points | Bina seviyelerinden gelen puan toplamı |
| **Toplam Puan** | Total points | Tüm köy puanları + köy başına 2.500 (ilki hariç) |
| **Güç Alanı** | Realm of power | 0…köy puanı arası değer; 0 olunca köy **fethedilir** |
| **Moral** | Morale | Güçlü saldıranın etkinliğini düşüren mekanizma (%30–%100) |
| **Şans** | Luck | Her savaşta rastgele −%25…+%25 |
| **Duvar bonusu** | Wall bonus | **Sur**'un savunmaya katkısı (%100–%220) |
| **Gece bonusu** | Night bonus | Gece saatlerinde savunma **×2** (sunucuya göre açık/kapalı) |
| **Casusluk** | Espionage | **Normal casus saldırısı** / **gizli casus saldırısı** |
| **Fethetmek** | Conquer | **Kont** ile köyü kalıcı ele geçirme |
| **Kont** | Count | Fetih birimi; **Altın zırh** gerektirir |
| **Altın zırh** | Golden armour | **Kuyumcu**'da üretilir; her üretimde maliyet artar |
| **Şahmerdan** | Battering ram | Savaş öncesi **sura zarar** verir |
| **Mancınık** | Trebuchet | Savaş sonrası **binalara zarar** verir |
| **Talan** | Pillage | Kazanan birliklerin taşıma kapasitesi kadar hammadde götürmesi |
| **Destek** | Support | Kendi/dost köye savunma için birlik gönderme |
| **Saldırı koruması** | Attack protection | Koruma türleri (bkz. `11-OYUNCU-PUAN-KORUMA.md`) |
| **Kanun Kaçağı** | Outlawed | 10:1 korumasını kaybetme durumu |
| **Uyku Modu** | Sleep mode | Oyunu duraklatma; etkileşim tamamen kapanır |
| **Tatil bakıcısı** | Holiday replacement | Premium özellik; başka oyuncunun hesabı yönetmesi |
| **Premium-hesap** | Premium account | Kron/kutsal emanetlerle açılan avantaj paketi |
| **Kron** | Crowns | Premium para birimi (gerçek parayla alınır) |
| **Kutsal Emanetler** | Relics | Kron ile alınan yardımcı eşyalar |
| **Simyager** | Alchemist | Kalıcı teknik/bonus araştırmaları |
| **İttifak** | Alliance | Oyuncu birliği (rütbeler, diplomasi) |
| **Konfederasyon** | Confederation | **Müttefikler** (sarı) / **Saldırmazlık paktı** (turuncu) / **Düşmanlar** (kırmızı) |
| **Teknoloji Ağacı** | Techtree | Binaların birbirini açma ilişkisi |
| **İnşa listesi** | Building queue | Aynı anda 3 iş; 3'ten sonra **ek maliyet** |
| **Binayı yık** | Tear down | Binayı yıkma (Kale Lv15 + Simyager tekniği) |

---

## 4. Bonus Köyler

Bonus köylerin başında **'Usta'** bulunur ve köye **tek bir bonus** verir:

| Bonus |
|---|
| %10 daha fazla **odun** |
| %10 daha fazla **taş** |
| %10 daha fazla **demir** |
| %10 daha fazla **vatandaş** |
| %10 daha hızlı **birlik eğitimi** |
| %3 daha fazla **hammadde üretimi** |

Haritada bonus köyler **parıltılı altın** görünümündedir. (Bkz. `10-HARITA-VE-DUNYA.md`)
