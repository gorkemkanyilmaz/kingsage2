# 12 — İttifaklar (Alliances)

Kaynak: `ally` (EN + TR)

> ❌ **KAPSAM DIŞI:** **İttifak forumu ve tüm forum özellikleri (alt forumlar, moderasyon, gizli
> forumlar, konu taşıma/kapatma) oyunumuza HİÇ ALINMAYACAK.** (Kullanıcı kararı)
> Bu doküman yalnızca ittifakın **mekanik** kısmını kapsar.

## 1. Tanım ve Üyelik

- İttifak, oyuncuların **ortak bir organizasyonda** birleşmesidir.
- Her oyuncu **kendi üyeliğini** kontrol eder; ittifak da **üyeleri üzerinde** kontrol sahibidir.
- **Üye olmak için:** mevcut bir üyeden **davet** gelmelidir. Oyuncu kabul ederse üye olur.
  Davet, kabul edilmeden **geri çekilebilir**.
- **İttifak değiştirme:** Yabancı ittifakın davetini kabul ederek geçilebilir.
- **Ayrılma:** Oyuncu istediği an ayrılabilir. **İttifak da üyeyi atabilir.**

## 2. Avantajlar (forum hariç)

- İttifak sayfalarında ve **Saldırı Uyarısı** bayraklarında saldırı özetleri
- **Üye listesi** (puan, rütbe, sıra, köy sayısı, aktivite durumu)
- **Tüm ittifak köyleri haritada yeşil** işaretlenir
- **İttifak üye unvanları** serbestçe tanımlanabilir (oyuncu adının yanında görünür)
- Mekanik olmayan faydalar: karşılıklı destek, organizasyon, diplomasi

---

## 3. İttifak Kurma

- Kurmak için **hiçbir ittifakta üye olunmamalıdır**.
- **İttifak** bağlantısına tıklanır, **isim** ve **etiket (tag)** girilir.
- Her ikisi de **benzersiz** olmalıdır; **etiket en fazla 6 karakter**.
- Kuran oyuncu **"council of elders"** unvanını alır ve tek üye olur.

## 4. Bilgileri Değiştir

| Alan | Kim değiştirir | Not |
|---|---|---|
| **Description (Açıklama)** | Diplomacy hakkı olan | Herkes görebilir; **BB-Kodları** destekler |
| **Name** | Yetkili | Kurulumdaki kısıtlar geçerli |
| **Tag** | Yetkili | Serbestçe değiştirilebilir |
| **Emblem (Amblem)** | Yetkili | **JPG/GIF/PNG**, **max 256 kB** |
| **Homepage** | Yetkili | Herkese açık |
| **IRC channel** | Yetkili | **Yalnızca üyeler** görür |
| **External forum link** | Yetkili | ⚠️ Forum kapsam dışı olduğu için **alınmayacak** |
| **Internal messages (İç duyurular)** | **Yalnızca ittifak lideri** | Biçimlendirilebilir metin; yalnızca üyeler görür |

## 5. Üyeleri Yönet

- Üye **atma**
- Üyeye **doğrudan rütbe atama** (en az bir üye "council of elders" olmalı).
  Doğrudan atanan rütbe, puan eşiğinden bağımsız aktif olur.
  Rütbeyi iptal etmek için oyuncuya **rütbe verilmez** → sistem otomatik puan rütbesi atar.
- Üye olmayanlara **davet** gönderme
- Bekleyen **davetleri geri çekme**

## 6. Yetkileri Yönet (Rütbeler)

Rütbeler ittifak kurulunca **otomatik oluşturulur**, sonra değiştirilebilir.

| Özellik | Açıklama |
|---|---|
| **Rank type** | **Point ranking** (puana göre otomatik) veya **Special ranking** (doğrudan atanır) |
| **Points** | Yalnızca puan rütbelerinde; rütbeyi almak için gereken **minimum puan** |
| **Name** | Rütbe adı |
| **Rights** | Aşağıdaki yetkilerin evet/hayır seti |

### Yetkiler (rights)
| Yetki | İzin verdiği |
|---|---|
| ~~Alliance forum~~ | ❌ **Kapsam dışı** |
| **Circular mail** | Tüm üyelere toplu mesaj |
| **Hidden forums** | ❌ **Kapsam dışı** |
| **Moderator** | ❌ **Kapsam dışı** (forum moderasyonu) |
| **Diplomacy** | Konfederasyon kurma/bitirme ve **iç duyuruları** düzenleme |
| **Invitations** | Davet gönderme/geri çekme |
| **Alliance leader** | İttifak lideri yetkisi |
| **Board of elders** | Elders konseyi |

### Rütbe yönetimi
- **Silme:** Son **"Board of elders"** yetkili rütbe silinemez. **Special ranking** yalnızca
  **hiçbir üyeye dağıtılmamışsa** silinebilir.
- **Ekleme:** Yeni rütbe, isteğe bağlı tanımlanır.
- **Değiştirme:** Değişiklik **anında** o rütbedeki tüm üyelere yansır.

## 7. Diplomasi (Konfederasyonlar)

| Konfederasyon | Haritada renk | Etki |
|---|---|---|
| **Müttefikler (Allies)** | **Sarı** | Müttefik ittifakın köyüne saldırmak için **açıkça onay** gerekir |
| **Saldırmazlık paktı (NAP)** | **Turuncu** | NAP ittifakına saldırmak için **açıkça onay** gerekir |
| **Düşmanlar (Enemies)** | **Kırmızı** | **Teknik etkisi yok** (yalnızca işaretleme) |

- Yeni konfederasyon: **hedef ittifakın etiketi** + konfederasyon tipi girilir.
- **Hedef ittifak bunu onaylamaz** ve **bilgilendirilmez**; kendi tarafında müttefik görünmez.
- Mevcut konfederasyon **basitçe sonlandırılabilir**.

---

## 8. Oyunumuza Uyarlama Notu

- **Forum yok.** İttifak iletişimi bunun yerine:
  - **İç duyurular (internal messages)** — lider tarafından yazılır,
  - **Toplu mesaj (circular mail)** — yetkisi olanlar tarafından,
  - **Birebir mesajlaşma** ile sağlanır.
- İttifak mekanikleri (rütbe, yetki, diplomasi, harita işaretleme) **birebir** korunur.
