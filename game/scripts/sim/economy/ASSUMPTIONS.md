# ASSUMPTIONS — Ekonomi Simülasyonu (A-EKONOMI)

> **Sahip:** A-EKONOMI · **Kapsam:** `game/scripts/sim/economy/**`, `game/scripts/core/GameLoop.gd`
> **Sözleşme:** `docs/19-MOTOR-API-SOZLESMESI.md` (§2 determinizm, §3 model alanları, §4 ekonomi,
> §5 puan/Güç Alanı, §7b sim modül protokolü).
> **Kural (docs/19 §2.5):** Bilinmeyen formüller **uydurulmaz**. Her bilinmeyen için **tek bir sabit**
> seçilir, kodda sabit tutulur ve burada gerekçesiyle belgelenir. Doğrulanınca yalnızca ilgili sabit
> değiştirilir.
>
> Süre/maliyet formüllerinin **bilinen** kısmı `RulesEngine`'dedir (bkz.
> `game/scripts/rules/ASSUMPTIONS.md`); bu dosya yalnızca **A-EKONOMI'ye özgü** bilinmeyenleri,
> seçilen modeli ve **karar noktalarını** belgeler.

İlgili kaynaklar: `research/text-tr/buildings.txt` (iptal iadesi — **kesin**; `docs/19` §3.2),
`docs/04-BINALAR.md` §3.7 (kuyruk ek maliyeti), `docs/04-BINALAR.md` (Yıkım / Simyager),
`docs/08-GUC-ALANI.md` §1–§2 (Güç Alanı), `time-factors.json#unresolved.construction_time_formula`.

---

## 1. İptal (cancel) iadesi — taban maliyet İADE, kuyruk ek maliyeti İADE DEĞİL

- **Kaynak (kesin, `research/text-tr/buildings.txt` → `docs/19` §3.2):**
  "İnşaat süreci devam eden herhangi bir anda iptal edilebilir ve böylece **kullanılmış kaynaklar
  iade edilecektir**." + "Komut girildikten sonra iptal edilmek istenirse **bu fazla maliyet geri
  iade edilmeyecektir**."
- **Uygulama:** Kuyruk öğesi iki ayrı maliyet alanı taşır (`docs/19` §3.2):
  `cost_paid` = **taban maliyet** (iptalde **İADE EDİLİR**), `extra_paid` = **kuyruk ek maliyeti**
  (iptalde **İADE EDİLMEZ**).
- `BuildQueue.cancel_build(..., refund := true, now_unix := 0, refund_extra := false)`:
  eski `refund` parametresi **taban iadeyi** denetler; **varsayılan davranış yukarıdaki kuraldır**.
  `refund=false` yalnızca eski/özel kullanım içindir. Dönüş:
  `{ ok, reason, item, refunded, refunded_base, refunded_extra, forfeited }`.
- `EconomyAPI.cancel_build(..., refund := true, refund_extra := false)` aynı kuralı kullanır.
- İptal sonrası kalan işler `reschedule` ile yeniden zincirlenir; **diğer komutların kimlik/hedef
  bilgisi bozulmaz**. (Test: taban iade, ek maliyet iade yok, kalan `(id, hedef)` çiftleri korunur.)
- **Bina yıkımında** (Kale Lv15 + Simyager) hammadde iadesi **yoktur** (§2) — bu ayrım korunur.
- **`AÇIK SORU:`** Kuyruğun **ortasından/başından** iptal edildiğinde sonraki komutların
  `target_level`'ı yeniden numaralanmalı mı? Şu an sipariş anındaki projeksiyon korunur (boşluk
  oluşabilir; ör. baş komut iptalinde kalan komut atlanan seviyeyi hedefler). Bu, §4'teki sıralı
  ilerleme modelinin bir uzantısıdır.

## 2. Bina yıkımı (tear down) — Simyager "teknik" kapısı

- Kural: bina yalnızca **Kale Lv15+** iken ve **Simyager** (teknik) araştırılmışsa yıkılabilir
  (`docs/04`). Teknik araştırma durumu **A-ORDU**'nun alanıdır (`Research`).
- **Karar:** `BuildQueue.tear_down(state, village, key, technique_researched := true)` — teknik
  **boolean** olarak dışarıdan verilir; ekonomi modülü araştırma durumunu **kendi tutmaz**. Kale
  seviyesi kapısı (`< 15` → `reason="castle_level"`) burada uygulanır.
- Yıkımda **hammadde iadesi yok**, **vatandaş geri gelir** (`workersTotal` serbest bırakılır; puan ve
  Güç Alanı tavanı güncellenir).
- **`AÇIK SORU:`** Simyager tekniğinin kesin araştırma maliyeti/süresi ve yıkımın Kale Lv15 dışında
  ek koşulu var mı? Ekonomi yalnızca `technique_researched` bayrağını tüketir.

## 3. Kuyruk ek maliyeti — indeks semantiği (1 tabanlı iş sırası)

- `time-factors.json#build_queue_extra_cost.index_note`:
  "`values_percent[i]` → `i+1` = kuyruktaki iş sırası (1 tabanlı)".
- **Uygulama:** `extra_cost_percent = queue_extra_cost_percent(pending_count)`. İlk 3 iş (pending 0,1,2)
  → %0; 4. iş (pending 3) → %25; 5.+ sırayla `[56, 95, 144, 205, 281, 376]`.
- **Yan etki:** `extra_cost_percent` **her zaman bir sonraki** işin yüzdesini döndürür; kuyrukta N iş
  varken değer `values_percent[N]`'dir. Testler bu semantiğe göre yazıldı (5 iş → sıradaki = %95).
- Premium ("kuyruk sınırsız, ek maliyet yok") **henüz bağlanmadı** (`AÇIK SORU:` premium bayrağı
  `GameState.player.premium` ile entegrasyon noktası; şu an gözetilmez).
- **`AÇIK SORU:`** Premium hesapta kuyruk üst sınırı/ek maliyet davranışının bağlanacağı yer.

## 4. Sıralı ilerleme (sequential) tanımı

- Bir binanın **hedef seviyesi** = o binanın **projeksiyondaki (mevcut + kuyrukta bekleyen en yüksek
  hedef) seviyesi + 1** (`BuildQueue.next_target_level`). Yani aynı bina için **sıçrama olmaz**;
  işler kuyruğa sırayla L+1, L+2, … eklenir.
- `RulesEngine.can_upgrade_now` **projeksiyon** sözlüğü üzerinden ikinci kez doğrulanır
  (`reason="locked"` kapısı).
- **İptal sonrası:** kalan işlerin `target_level`'ı **sipariş anındaki projeksiyon olarak korunur**
  (yeniden numaralanmaz) — bkz. §1'deki `AÇIK SORU`. Böylece ödenen maliyet ile hedef tutarlı kalır;
  kuyruk `reschedule` ile yeniden zincirlenir.
- **`AÇIK SORU:`** KingsAge'de aynı binaya paralel/atlamalı yükseltme kuyruğu var mı? Sıralı model
  seçildi.

## 5. İnşa süresi — `RulesEngine` taban süresi yeniden kullanımı

- Süre `RulesEngine.build_seconds(key, level)` üzerinden gelir (inşa faktörü tablosu,
  `time-factors.json`). **Bilinmeyen** kısım `time-factors.json#unresolved.construction_time_formula`
  olup **A-MOTOR/RulesEngine** varsayımına **devredilmiştir**; burada **yeniden uydurulmaz**.
- Kuyrukta `finish_unix = now_unix + ceil(süre)` (en az 1 sn) saklanır (bkz. §6).
- **`AÇIK SORU:`** İnşa süresinin bina seviyesiyle kesin birleşimi (`construction_time_formula`).

## 6. Simülasyon saati (offline hızlı-ileri uyumu)

- `GameLoop` kendi sim saatini (`_now_unix`) her tick `delta_seconds` kadar ilerletir ve
  `state.world.sim_now_unix`'e **yazar**. Kuyruk `start_unix`/`finish_unix` bu **sim saati**
  alanındadır.
- Böylece `GameClock.fast_forward()` (offline telafi) **aynı `tick` yolunu** kullandığından, gerçek
  zaman damgası donmuş olsa bile inşaat süreleri doğru ilerler. Test 30 günlük (2.592.000 s) tek
  dev adımda ve 10.000 mikro adımda **aynı** sonucu doğrular (determinizm + tutarlılık).
- **`AÇIK SORU:`** Kalıcı kayıtta `world.sim_now_unix`'in hangi dünya saatiyle (UTC/yerel) hizalandığı.

## 7. Türetilmiş (şemaya ek) yardımcı alanlar

- **`_prod_frac`** (`Production.FRAC_KEY`): üretim kayan-nokta artığı. Küçük tick'lerde yuvarlama
  kaybını önlemek için ham üretim `float` birikir, `floor`'u depoya eklenir, artık köyde saklanır.
- **`_realm_frac`** (`RealmOfPower.FRAC_KEY`): Güç Alanı saatlik %1 yenilenme artığı (aynı gerekçe).
- Bu alanlar **türetilmiştir** ve `VillageModel`/`GameState` şemasının **parçası değildir**; köy
  sözlüğü serbest şema olduğundan `GameState.to_dict()/from_dict()` bunları **sorunsuz** taşır.
  Determinizm için tüm değerler int'e indirgenir; **global `randi()` kullanılmaz**.
- **`AÇIK SORU:`** Kalıcı kayıt formatında bu ara alanların tutulup tutulmayacağı (öneri: tutulmalı,
  yoksa kayıt/yükleme sınırında < 1 birim üretim kaybı oluşur).

## 8. Vatandaş muhasebesi — yalnızca bina çalışanları

- Bu modül yalnızca **bina** vatandaşını sayar: `Population.used_citizens = VillageModel.population_used`
  (Σ `workersTotal`). Maksimum `RulesEngine.max_population(Değirmen)`.
- **Ordu** vatandaşı ve eğitim rezervi **A-ORDU**'nun alanıdır (`sim/army/ASSUMPTIONS.md` §6). Ekonomi
  tick'i yalnızca bina vatandaşını bağlar/serbest bırakır (yükseltme → `workersLevel` bağlanır; yıkım
  → serbest kalır; vatandaş **tükenmez**).
- Kuyruk ile birlikte kapasite kontrolü `used + pending + need ≤ max` (`Population.can_afford_citizens`);
  yetersizse `reason="citizens"`.
- **`AÇIK SORU:`** Vatandaşın yükseltme **başında mı** yoksa **tamamlanınca mı** bağlandığı — burada
  **tamamlanınca** bağlanır (kuyrukta rezerve edilmez, yalnızca kapasite kontrolünde hesaba katılır).

## 9. Güç Alanı (Realm of Power) modeli

- **Tavan = Köy Puanı** (`RealmOfPower.cap`), asla 10.000'i geçmez. Yenilenme tavanın **%1/saat**
  (`GameConfig.realm_power_hourly_percent`, TR varsayılanı `1.0`). Değer `[0, tavan]`'a kırpılır.
- Kont düşüşü **miktarı** A-SAVAS'tan gelir (şans/seed orada); ekonomi yalnızca **uygular** ve
  **0'a inince fethi işaretler**. Kapak: saldırı başına düşüş ≤ **tavanın yarısı** (`docs/08` §2).
- Fetih sonrası yeni sahibin alanı **maksimumun %30'u**. Rastgelelik **yok**; aralık seçimi
  (`loss_range`) determinizm gereği A-SAVAS'ın `RNG`'sine bırakılır.
- **`AÇIK SORU:`** Güç Alanı yenilenmesinin **tam saat sınırında** (tik başına) mı yoksa **sürekli**
  mı işlediği — burada **sürekli oran** + kayan-nokta artığı modeli seçildi (§7).

## 10. Puan ve "tam gelişmiş köy"

- Köy puanı = Σ `RulesEngine.points_for(bina, seviye)`. **Tam gelişmiş köy** (tüm binalar maksimum)
  puanı = **10.000** (test ile doğrulandı; `docs/19` §5).
- Başlangıç (6 ücretsiz bina L1) puanı = **110**.
- Güç Alanı **tavanı** puanla birlikte büyür; **anlık** `realm_of_power` değeri yenilenmeyle
  doldurulana kadar eski değerinde kalır (tavan değişimi **arka-doldurma yapmaz**).

## 11. Bonus köy çarpanları

`docs/02` §4 ve `docs/19` §3.1'e göre uygulanır:
- `bonus_type == "wood"|"stone"|"iron"` → ilgili hammadde üretimi **×1.10**.
- `bonus_type == "production"` → **tüm** hammaddeler **×1.03**.
- `bonus_type == "citizen"` → maksimum vatandaş **×1.10**.
- Köyde açık bir `bonus` sözlüğü varsa (`VillageModel`) değerleri ondan okunur (öncelikli).
- **`AÇIK SORU:`** "production" bonusunun **gece bonusu / hız** ile çarpım sırası ve sınır durumları.

## 12. GameLoop (§7b) — Node, autoload değil; erken yükleme

- `GameLoop` **autoload değildir**; ana sahne bir kez `add_child` eder (autoload alanı A-HALKA).
  Aynı anda **iki örnek** eklenirse tick iki kez işlenir → kaçınılmalı.
- Modüller `MODULES` listesinden **yol ile** yüklenir (`ResourceLoader.exists()` → yoksa **sessizce
  atlanır**). Headless `--script` modunda `_ready()` gecikebildiği için modüller **`_init()`'te de**
  yüklenir; `simulate()`/sorgular modül listesi boşsa **lazy** yeniden yükler.
- Headless modda autoload global kimlikleri (`EventBus`, `GameState`) **çözülemez**; bu yüzden
  `root.get_node_or_null("...")` ile erişilir ve tüm modüller `preload("res://...")` kullanır
  (global sınıf önbelleği yok).
- **`AÇIK SORU:`** `GameLoop`'un kalıcı olarak ana sahneye ekleme noktası (Boot mu, ana sahne mi?)
  — A-ARAYUZ/Boot ile netleştirilmeli; bu modül yalnızca sözleşmeyi sağlar.

---

## Tüm AÇIK SORULAR (özet)

1. `AÇIK SORU:` Kuyruğun ortasından/başından iptalde sonraki komutların `target_level`'ı yeniden
   numaralanmalı mı? (§1 — şu an sipariş anındaki projeksiyon korunur).
2. `AÇIK SORU:` Simyager tekniğinin kesin maliyeti/süresi ve yıkımın ek koşulları (§2).
3. `AÇIK SORU:` Premium hesapta kuyruk sınırı ve ek maliyet muafiyetinin bağlanacağı yer (§3).
4. `AÇIK SORU:` Aynı binaya paralel/atlamalı yükseltme mümkün mü? (§4 — sıralı seçildi).
5. `AÇIK SORU:` İnşa süresinin bina seviyesiyle kesin birleşimi (`construction_time_formula`) (§5).
6. `AÇIK SORU:` `world.sim_now_unix` ile dünya saati hizalaması (§6).
7. `AÇIK SORU:` `_prod_frac` / `_realm_frac` ara alanlarının kalıcı kayıtta tutulması (§7).
8. `AÇIK SORU:` Vatandaşın yükseltme başında mı tamamlanınca mı bağlandığı (§8 — tamamlanınca).
9. `AÇIK SORU:` Güç Alanı yenilenmesinin sürekli mi tam-saat mi işlediği (§9 — sürekli).
10. `AÇIK SORU:` "production" bonusunun diğer çarpanlarla sırası (§11).
11. `AÇIK SORU:` `GameLoop` örneğinin kalıcı ekleme noktası (Boot / ana sahne) (§12).
