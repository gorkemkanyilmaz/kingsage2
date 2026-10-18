# 11 — Oyuncu, Puanlar, Sıralamalar ve Korumalar

Kaynak: `player*`, `intro`, `worldinfo`

## 1. Oyuncu Rolü

- Oyuncu **birden çok yerleşimi** yönetir; bina diker, asker eğitir.
- Kaynaklarını ve yerleşimlerini korur; **yağma** veya **fetih** için ordu kullanır.
- **Hiç yerleşimi kalmazsa** oyuna **baştan başlamak** zorundadır.

## 2. Ortak İnternet Bağlantısı (IP paylaşımı)

- **Çoklu hesap (multi-account)** engellemek için **IP paylaşımı yasaktır**.
- Kaçınılmaz durumlarda (internet kafe vb.) profilde **"Share internet connection"** kullanılır.
- Paylaşan oyuncular birbirine **kaynak veya destek gönderemez**.
- Kayıt **en az 3 gün** geçerlidir; sonra kaldırılabilir.

## 3. Hareketsizlik ve Silinme

| Durum | Sonuç |
|---|---|
| **Normal hesap, 35 gün** hareketsiz | **Silinir** |
| Uyarı e-postaları | **7., 15., 30.** günler |
| **Premium hesap aktif** | **Silinmez** |
| PA süresi bitti | Normal hesap kurallarına tabi |
| **Uyku modunda normal hesap (PA yok)** | Silinmez; **60 kesintisiz tatil günü** sonrası tatil biter, normal silinme süresi işler |

## 4. Uyku Modu (Sleep Mode — SM)

- Uzun süre oynamayacak oyuncu için **"duraklatma düğmesi"**.
- SM sırasında **oyuncu dünyayı etkilemez, dünya da oyuncuyu etkilemez.**
- **SM'de hiçbir aksiyon yapılamaz; başka oyuncular etkileşemez.**
- SM'den **önce başlatılan aksiyonlar devam eder**; uzun süren ve başka oyuncu içeren aksiyonlar
  mümkün olduğunca **duraklatılır/askıya alınır**.
- SM, **kullanıcı adının yanında** (ittifak listesi ve profil) ve **haritada gri** olarak gösterilir.

## 5. Tatil Vekilliği (Holiday Replacement — HR)

- **Premium özellik** (aktif PA gerektirir).
- Başka bir oyuncuya, **şifre vermeden** hesabınızı yönetme hakkı verir.
- **Haklar ayrıntılı atanabilir** (ör. mesaj okuma/yazma engellenebilir).
- **Birbirini temsil eden oyuncular birbirine saldıramaz.** Bu koruma, HR bittikten **7 gün sonra** da geçerlidir.

---

## 6. Puanlar

### Köy Puanı
- Her **bina seviyesi** belirli puan kazandırır; toplamı **Köy Puanı**'dır.
- Puan, **inşaat bittiğinde** eklenir; ancak **istatistiklerde hemen görünmez**
  (düşmanların bilgi edinmemesi için bir gecikme vardır).
- **Birlikler, muharebeler ve araştırma puana etki etmez.**

### Toplam puan
```
Toplam Puan = (tüm yerleşim puanları) + 2.500 × (yerleşim sayısı − 1)
```
> İlk yerleşim için bonus yok; **her ek yerleşim +2.500 puan**.

### Bina puanları
- **Tam gelişmiş bir yerleşim = 10.000 puan.**
- Tam tablo: [`reference/puan-tablosu.md`](reference/puan-tablosu.md) · veri: `data/building-points.json`

| Bina | Puan formülü | Maks. katkı |
|---|---|--:|
| Kale, Taş ocağı, Oduncu Kampı, Maden ocağı, Depo | `20 × seviye` | 1.000 |
| Değirmen | `10 × seviye` | 500 |
| Gizli Depo | `10 × seviye` | 300 |
| Kışla | `20 × seviye` | 600 |
| Sur | `20 × seviye` | 400 |
| Katır çiftliği | `10 × seviye` | 300 |
| Market | `20 × seviye` | 600 |
| Simyager | `20 × seviye` | 100 |
| Köşk | `100 × seviye` | 1.000 |
| Kuyumcu | `40 × seviye` | 200 |
| Anıt | 1.000 (sabit) | 1.000 |
| **TOPLAM** | | **10.000** |

### Güç Alanı
- `0` … Köy Puanı arasında dalgalanır; **maksimum 10.000**.
- Maksimumun altındaysa **saat başına maksimumun %1'i** kadar artar.
- Kont ile düşürülür; **0 olunca fetih** gerçekleşir. (Bkz. [`08-FETIH.md`](08-FETIH.md))

---

## 7. Sıralamalar (Rankings)

Her sunucunun **kendi sıralaması** vardır.

| Sıralama | Ölçüt |
|---|---|
| **Players** | Tüm yerleşimlerin toplam puanı |
| **Alliances** | İttifakların toplam puanı |
| **Defeated opponents** | Oyuncunun yok ettiği toplam birim (`As attacker`, `As defender`, `Total`) |
| **Defeated opponents in the alliance** | İttifak bazlı yok edilen birimler |
| **Battles** | Oyuncunun kazandığı toplam muharebe (yeniden başlasa bile) |
| **Alliance battles** | İttifakın kazandığı toplam muharebe |
| **Pillory** | Geçici/kalıcı **ban** yiyen oyuncular |

---

## 8. Arkadaşlar (Friends)

- Önemli oyuncular **favorilere** eklenir → profillere hızlı erişim.
- **Arkadaş olmak için:** favoriye ekle → **Friend** düğmesiyle istek gönder → karşı taraf onaylar.
- Avantajlar:
  - Arayüzden **daha hızlı mesajlaşma**.
  - Arkadaşın **çevrimiçi durumu** görünür:
    - 🟢 aktif
    - 🟡 son 2 gündür hareketsiz
    - 🔴 bir haftadır hareketsiz

---

## 9. Mesajlar ve Raporlar

- Oyuncular birbirine **mesaj** gönderebilir.
- Oyun otomatik mesajları → **rapor (report)**:
  - **Battle report:** muharebeden sonra
  - **Spy report:** casusluktan sonra

### Saklama süreleri
| | Premium gelen kutusu | Okunmuş | Okunmamış |
|---|--:|--:|--:|
| **Normal sunucu** | 90 gün | 5 gün | 7 gün |
| **Hız sunucusu** | 90 gün | 3 gün | 3 gün |

- Premium'da **klasör (folder)** oluşturulabilir → klasördeki mesajlar otomatik silinmez, **3 ay** saklanır.

---

## 10. Saldırı Koruması (tam)

Kaynak: `intro` (Attack protection), `units_attack`, `worldinfo`

### 10.1 Genel koruma (1:10 kuralı)
- **Maksimum puan farkı 1:10**.
- Bir oyuncuya, **puanının 10 katından fazla** olan biri saldırırsa **uyarı** görünür.
- Saldırı yine yapılırsa, **zayıf taraf (saldıran)** 1:10 korumasını **7 gün** kaybeder.
- **Saldırının başlangıç anı** belirleyicidir: sınırda olan saldırılar, hedef saldırı sırasında
  limitin altına düşse bile **yine çalışır**. Saldırı, hedef yerleşim **el değiştirse de devam eder**.

### 10.2 Highscore saldırı penceresi
- Her oyuncu, highscore'da **kendisinin altındaki ilk 200 oyuncuya**, genel korumadan bağımsız
  **saldırabilir**.
- **İttifak üyeleri bu pencereye dahil değildir.**

### 10.3 Yeni oyuncu koruması — Faz 1
- İlk **5 gün**: oyuncunun **ana yerleşimine saldırılamaz**.
- Oyuncu kendisi bir oyuncuya saldırırsa koruma **biter**; bu durumda **faz 2 otomatik başlar**.

### 10.4 Yeni oyuncu koruması — Faz 2
- **7 gün** daha: ana yerleşim **fethedilemez** (Kont saldırabilir ama realm of power düşürmez).
- Faz 2'deyken **terk edilmiş bir yerleşim fethedilse bile** fetih koruması korunur
  (ancak koruma yalnızca **ana yerleşim** için geçerlidir; yeni yerleşim normal şekilde fethedilebilir).
- Faz 2'deyken **Kont ile bir oyuncuya saldırılırsa**, faz 2 **erken biter** ve fetih koruması **kaybedilir**.

### 10.5 Terk edilmiş yerleşim (Abandoned)
- **Hiçbir koruması yoktur**; **1:10 puan farkı** olan oyuncular bile saldırıp fetheder.

### 10.6 Outlawed (kanun kaçağı) — özet
- Saldırı yapan zayıf oyuncu, 10:1 korumasını **2 ay** boyunca kaybeder.
- **Uyku modundaki oyunculara saldırılamaz.**

### Özet tablo
| Koruma | Süre | Etki |
|---|---|---|
| Yeni oyuncu faz 1 | 5 gün | Ana yerleşime **saldırı** yok |
| Yeni oyuncu faz 2 | +7 gün | Ana yerleşim **fethedilemez** |
| Genel 1:10 | kalıcı | 10× puan farkı üstünü **kısıtlar** |
| Highscore penceresi | kalıcı | Alttaki **200 oyuncuya** serbest saldırı |
| Uyku modu | SM süresince | **Hiç** etkileşim yok |
| Terk edilmiş | — | **Koruma yok** |
