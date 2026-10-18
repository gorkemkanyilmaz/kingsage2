# 18 — Sanat, İsimlendirme ve Telif Kontrol Listesi

> Amaç: **mekanikler birebir**, fakat **isim ve görseller tamamen özgün**.

---

## 1. Telif Değerlendirmesi (özet)

| Öğe | Kopyalanabilir mi? | Not |
|---|---|---|
| **Oyun mekanikleri / kurallar / sayısal tablolar** | ✅ Genel olarak | Fikir–ifade ayrımı: kurallar ve formüller genelde korunmaz |
| **Kaynak kod** | ❌ | Gameforge kodu **asla** kullanılmaz |
| **Marka adı "King's Age" / logo** | ❌ | **Kullanılamaz** → özgün isim şart |
| **Grafikler / sprite'lar / bina görselleri** | ❌ | **Özgün sanat** şart |
| **Ses / müzik** | ❌ | Özgün ses tasarımı |
| **Yardım metinleri** | ⚠️ | **Kendi metnimizi yazacağız**, birebir çeviri değil |
| **Arayüz düzeni benzerliği** | ⚠️ | İşlevsel düzen serbest; görsel stil özgün olmalı |
| **Sunucu verileri / kullanıcı verisi** | ❌ | Erişilmez, kullanılmaz |

> ⚠️ **Önemli:** Telif hukuku ülkeye göre değişir; **yayın öncesi bir hukukçuya danışılmalıdır.**
> Mekaniklerin kopyalanması geniş ölçüde serbest olsa da, **marka ve görsel/ses varlıkları**
> açık ihlal oluşturur. Bu proje **hiçbir Gameforge varlığı içermeyecektir.**

### 1.1 Uyulacak kurallar
1. **Hiç** Gameforge dosyası (görsel, ses, kod, metin) depoya **girmez**.
2. Yardım sitesinden topladığımız metinler **yalnızca analiz amaçlı** `research/` altındadır;
   **ürüne girmez**. Ürün metinleri **sıfırdan yazılır**.
3. Terimler (Kale, Kışla, Kont …) **genel Türkçe kelimelerdir**; marka değildir → kullanılabilir.
4. İsim, logo, ikon, font, ses **tamamen özgün** olacaktır.

---

## 2. Özgün İsim Önerileri

> Karar kullanıcıya aittir. Aşağıdakiler **öneri**dir (hepsi özgün, "King's Age" ile karışmayacak).

### 2.1 Ana oyun adı
| # | Öneri | Gerekçe |
|---|---|---|
| 1 | **Beylikler Çağı** | "Çağ" teması + Orta Çağ; TR'de akılda kalıcı |
| 2 | **Taht ve Kılıç** | Güç/fetih teması |
| 3 | **Sınır Beyleri** | Fetih ve genişleme vurgusu |
| 4 | **Çağın Hükümdarı** | Strateji/çağ hissi |
| 5 | **Kale ve Kılıç** | Bina + savaş |
| 6 | (EN) **Age of Realms** | Uluslararası, jenerik ama özgün |

### 2.2 Terim politikası
- **Bina/birim adları** (Kale, Kışla, Kont …) genel kelimeler olduğundan **olduğu gibi** kullanılır —
  bu isimler **bizim değil**, evrensel Orta Çağ kavramları.
- **Oyun adı, logo, dünya adları, özel karakterler** tamamen **bizim** olacaktır.

---

## 3. Görsel Stil Rehberi (2.5D)

| Öğe | Yön |
|---|---|
| Perspektif | İzometrik (≈ 2:1), hafif yükseklik |
| Palet | Orta Çağ: taş grisi, ahşap kahve, çim yeşili, demir grisi, altın vurgu |
| Çizim | Yarı-gerçekçi, temiz çizgi, mobil için okunur silüet |
| Işık | Sıcak gündüz / soğuk gece; gün-gece döngüsü |
| Animasyon | İnşaat iskeleti → tam bina; duman, kıvılcım, üretim hareketi |
| UI | Ahşap/taş çerçeveli paneller, net tipografi |
| Ses | Özgün; davul/boru temalı, üretim ve savaş geri bildirimi |

### 3.1 Varlık listesi (üretilecek)
- **Binalar:** 15 bina × seviye varyantları (en az 3 görsel aşama: erken/orta/geç)
- **Birimler:** 11 birim × (idle, yürüyüş, saldırı, ölüm)
- **Harita:** zemin tile'ları (ova, orman, dağ, su, yol), köy işaretleri
- **UI:** ikon seti (kaynaklar, binalar, birimler, eylemler), panel çerçeveleri
- **Efektler:** toz, duman, ateş, taş kırılması, kaynak uçuşu, zafer
- **Simgeler:** uygulama ikonu, mağaza görselleri

---

## 4. Yerelleştirme Planı

- **Birincil dil:** Türkçe (**resmî KingsAge TR terimleri** — [`TERIMLER.md`](TERIMLER.md)).
- Sonraki diller: EN, DE, … (Godot çeviri (`.po`) altyapısı).
- **Dikkat:** İngilizce terimlerin **kendi uydurma çevirileri yasak** — TR oyunda **resmî TR adlar** kullanılır.

---

## 5. Yayın Öncesi Telif Kontrol Listesi

- [ ] Depoda **hiçbir** Gameforge dosyası yok (görsel/ses/kod/metin).
- [ ] `research/` klasörü **ürün paketine dahil edilmez** (yalnızca analiz).
- [ ] Oyun adı ve logosu **özgün**, marka aramasında çakışma yok.
- [ ] Tüm görseller/sesler **kendi üretimimiz** veya lisanslı.
- [ ] Ürün içi metinler **sıfırdan yazılmış** (birebir çeviri değil).
- [ ] Yasal danışman onayı alındı.
- [ ] Mağaza (App Store / Google Play) telif beyanları doğru.
