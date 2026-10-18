# ASSUMPTIONS — Hareket Sistemi (A-KESIF)

> Bu dosya, `docs/19-MOTOR-API-SOZLESMESI.md` §2.5 zorunluluğunca, hareket
> modülünde (`Movement.gd`, `Arrival.gd`, `ActionSimulator.gd`, `Protection.gd`)
> **dokümanda kesin değeri bulunmayan** kararlar için seçilen **tek** modeli ve
> gerekçesini belgeler.
>
> **Kural:** Bilinmeyen değer/formüller **uydurulmaz**; her biri kodda tek bir
> isimli sabit olarak tutulur, burada gerekçelenir ve `AÇIK SORU:` ile işaretlenir.
> Değer istemciden doğrulanınca yalnızca ilgili sabit değiştirilir.

İlgili girdiler:
- `docs/19` §3.3 (hareket şekli), §7 (savaş imzası), §7b (sim modül protokolü), §2 (determinizm).
- `docs/09` §6 (iptal süreleri), `docs/11` §10 (koruma / 10:1 / Kanun Kaçağı).
- `docs/14` §5–§6 (ticaret akışı ve bilinmeyenler).
- `game/data/rules/battle.json#attack_protection`, `game/autoload/GameConfig.gd`.
- Hazır modüller **kullanılır**, kopyalanmaz: `world/Travel.gd` (süre/iptal),
  `sim/battle/BattleSimulator.gd` (5 faz), `sim/battle/BattleReport.gd` (rapor metni),
  `rules/RulesEngine.gd` (min. saldırı birimi, birim hızı, köy puanı).

---

## 1. Kanun Kaçağı ne zaman işaretlenir? (`docs/11` §10.1)

**Seçilen davranış:** Oran ihlali (`saldıran_puanı > 10 × savunan_köy_puanı`)
**emir verilirken** (SEND anında) değerlendirilir; kural aşılırsa oyuncu **hemen**
Kanun Kaçağı olur ve saldırı **yine de yapılır** (iade edilmez).

- Saldıran puanı = `Protection.player_points(state, owner)` → **sahibin tüm
  köylerinin köy puanları toplamı** (`docs/06` §2: oran toplam puana göre).
- Savunan puanı = hedefin **köy puanı** (`movement.target_points`, verilmezse
  hedefin güncel `points` değeri).
- Ceza süresi `battle.json#attack_protection.outlawed_penalty_days = 60` gün (**2 ay**).
- İşaret **iki yere** yazılır: köye `outlaw_until` ve (varsa) `state.player` aynı
  sahibe aitse `state.player.outlaw_until`.

**Gerekçe:** Doküman "10:1 kuralını ihlal eden oyuncu Kanun Kaçağı olur" der ama
kontrolün gönderimde mi varışta mı yapıldığını belirtmez. Gönderimde işaretlemek
deterministik ve yan etkisizdir; varışta oran değişebileceğinden (kayıp/ganimet)
belirsizlik yaratırdı.

`AÇIK SORU:` Oran ihlalinin oyun istemcisinde tam olarak hangi anda uygulandığı
(gönderim / varış) ve puan oranının **toplam puan mı köy puanı mı** olduğu.

## 2. Min. saldırı birimi kontrolü — kapsam ve çift kontrol (`docs/06` §3, `worldinfo`)

**Kapsam (doğrulanmış):** `worldinfo` "**Saldırı** için gereken en az birim | 3 ×
Kışla kademesi" der → kural **yalnızca `attack` ve `raid`** için geçerlidir.
**Destek / ticaret / casusluk** bu eşiğe **takılmaz** (`Movement.can_send`'de
yalnızca `_validate_attack` uygular).

Gönderimde `RulesEngine.min_attack_units(3 × Kışla)` uygulanır. Aynı eşik
`BattleSimulator` içinde de vardır ve sonuç `min_attack_ok` ile döner. İki katman
**aynı sabiti** (`battle.json#min_attack_units.barracks_factor = 3`) kullanır;
çelişki oluşmaz.

## 3. Casus sağkalımı, rapor içeriği ve bilgi kademeleri (`docs/07` §3–§4)

- Sağkalım **A-SAVAS'ın casus fazından** alınır (`phases[key="spy_attack"].data`),
  burada **yeniden hesaplanmaz** (`spy_survivors`, `spy_losses`, `defence_spies`).
- Savunan casus **kaybetmez** (A-SAVAS modeli). Bu modül savunan birimlere
  dokunmaz.
- **Rapor** yalnızca `spy_survivors > 0` ise üretilir ve hedefin **kaynaklarını +
  birliklerini + binalarını** içerir; **(hiçbir) açığa çıkarma (exposure)
  gösterilmez** — görev şartı.
- **Gizli Depo casuslara karşı da korur** (kaynak: `buildings.txt`: "hırsızların
  elinden **ve casusların gözlerinden** uzak yerlerdir"). Korunan miktar **üç
  hammaddenin toplamından** düşülür (`production.json` → `hideout_capacity.unit =
  "resource_total"`), yani **toplam havuz** semantiği: `görünür_toplam = toplam −
  min(kapasite, toplam)`; kalan, **en büyük kalan yöntemiyle** kaynaklara oransal
  dağıtılır. `toplam ≤ kapasite` ise üç kaynak da **0** görünür. Bu, yağma
  katmanıyla (`BattleSimulator._compute_loot`) **birebir aynı** semantiktir.
  - **Kod tekrarı notu:** Dağıtım algoritması (`Arrival._visible_resources`)
    `BattleSimulator`'ın gizli modül API'sine bağımlı olmamak için yeniden
    yazılmıştır; **aynı çıktıyı** verdiği test ile (yağma `_compute_loot` çıktısıyla
    birebir karşılaştırma) doğrulanır.
- **Bilgi kademeleri** (kaynak: `units_espionage.txt`):
  - **Normal casusluk:** askerî birlikler + moral + hammaddeler + binalar/kademeleri
    + **dışarıdaki birlikler** (`outside_units`).
  - **Gizli casusluk:** askerî birlikler + hammaddeler + binalar/kademeleri —
    **dışarıdaki birlikler YOK** (`outside_units` alanı eklenmez).
- **Görünürlük** (kaynak: `units_espionage.txt`):
  - **Normal** casusluk **savunana görünür** (`visible_to_defender = true`) ve
    **savunan da rapor alır** (`type = "spy_incoming"`, `defender_notified = true`).
  - **Gizli** casusluk **savunana görünmez** (`visible_to_defender = false`),
    savunan **rapor ALMAZ**; saldıran kendi raporunu yine alır; hız **×3 yavaş**.

## 4. Katır (ticaret) yolculuk hızı (`docs/14` §6.3, bilinmeyen #3)

**Seçilen sabit** (`Movement.DONKEY_MINUTES_PER_FIELD = 2.0`): katır, alan başına
**2.0 dakika** hızındadır (yani "hızlı süvari" ≈ Akıncı 2.5'ten hızlı, en hızlı
birimden yavaş).

```
katır_süresi = mesafe(alan) × 2.0 × 60 / GameConfig.unit_speed
```

**Gerekçe:** `docs/14` §6.3 katır yolculuk süresinin formülünü **bilinmeyen** olarak
listeler ("birim hızına benzer olması beklenir"). Sabit bir alan/dakika değeri,
`Travel.seconds_for_fields` yolunu kullanır (birimlerle aynı ölçek) ve tek noktadan
ayarlanabilir.

`AÇIK SORU:` Katırın gerçek alan/dakika hızı (veya birim hızına oranı).

## 5. Ticaret için Market zorunluluğu (`docs/14` §1)

**Seçilen davranış** (`Movement.REQUIRE_MARKET_FOR_TRADE = true`): kaynak köyde
`market >= 1` değilse ticaret **reddedilir** (`code = "market_required"`).

**Gerekçe:** `docs/14` §1 "**Market** binası **zorunludur**" der. Katır çiftliği
(`stable`) **zorunlu değildir** (§2), bu yüzden yalnızca Market kontrol edilir.

`AÇIK SORU:` Market zorunluluğunun **gönderim** anında mı yoksa arayüz tarafında mı
zorlandığı.

## 6. Gece bonusu penceresi (`docs/06`, `GameConfig.night_bonus_*`)

Savaş çözümünde `night` bayrağı, `now_unix`'in **UTC saatine** göre
`GameConfig.is_night_bonus_time(hour)` ile belirlenir.

**Gerekçe:** Sunucu saat dilimi oyun katmanının kararıdır; sim katmanı
`GameConfig`'e devreder ve deterministik kalır (aynı `now_unix` → aynı bayrak).
`GameConfig` yoksa **kapalı** kabul edilir.

`AÇIK SORU:` Sunucu saat dilimi (yerel/UTC) ve gece penceresi sınırları.

## 7. Dönüş süresi = gidiş süresi (`docs/19` §6 kararı — doğrulanmış)

Dönüş hareketinin süresi, gidiş hareketinin süresinden **birebir kopyalanır**
(`Arrival._make_return`: `arrive_return = gidiş_arrive + gidiş_süresi`). Hayatta
kalan ordunun kompozisyonu (dolayısıyla "en yavaş birimi") değişse bile süre
sabit tutulur.

**Gerekçe:** `docs/19` §6 "dönüş süresi = gidiş süresi (yağma yavaşlatmaz)" kararı.
Ayrıca ganimet `carry` alanında **dönüşte** taşınır ve dönüş tamamlanınca kaynak
köye eklenir (`docs/09` §5).

## 8. Destek ve ticaret geri dönmez (`docs/09` §4, `docs/14` §5)

- **Destek:** birlikler hedefte **savunma** olarak konuşlanır; hedefin
  `units`'ine eklenir **ve** `target.support[]` kaydına yazılır (kaynak köy + sahip
  bilgisiyle). Geri dönüş hareketi üretilmez.
- **Ticaret:** hammadde teslim edilir, **katır kaybolur** (`docs/14` §5);
  geri dönüş yoktur. Hedef yoksa hammadde **kaynak köye iade** edilir (katır yine kayıp).

`AÇIK SORU:` Destek birliklerinin ne zaman geri çağrılacağı/otomatik döneceği
(bu modül yalnızca konuşlandırır; geri çağırma ayrı komut).

## 9. Koruma kuralları ve köy türleri (`docs/11` §10)

- **Yeni oyuncu koruması 5 gün** (`new_player_protection_days`), sonrasında
  **fetih koruması +7 gün** (`conquest_protection_days`). `Protection.apply_new_player_protection`
  faz 1 bitişini `protection_until`, faz 2 bitişini `conquest_protection_until`'a yazar.
- **Korumalı köye saldırı/casusluk reddedilir** (`target_protected`); **destek ve
  ticaret serbesttir** (savunma/ekonomik emirler).
- **Terkedilmiş (soyguncu, `is_barbarian`) ve bonus (`bonus_type` dolu) köylerde
  koruma YOKTUR**; `protection_until` dolu olsa bile yok sayılır.
- **Fetih koruması** saldırıyı engellemez; yalnızca fetihi bloklar
  (`conquest_blocked`) ve **Güç Alanı düşmez** (`docs/11` §10.4).
- Oyuncu **kendisi saldırınca** faz 1 biter, faz 2 başlar (`on_attack_sent`).

`AÇIK SORU:` Bonus köylerde korumanın hiç mi (bizim seçimimiz) yoksa yalnızca
fetih korumasının mı uygulandığı.

## 10. Kont mesafesi (`docs/08` §4, `docs/10` §5)

Orduda `snob` (Kont) varsa hedef, `GameConfig.count_max_distance` (TR **80 alan**,
EN 100) mesafesinden uzak olamaz; aşılırsa `count_too_far`. Ölçüm
`Travel.within_max_fields` = **Öklid alan mesafesi** (yuvarlama yok).

`AÇIK SORU:` Kont mesafesinin **alan** mı yoksa **kıta** bazlı mı olduğu
(doküman "80 alan" der; biz alan kabul ettik).

## 11. İptal kuralları (`docs/09` §6 — doğrulanmış)

- Saldırı (`attack`/`raid`/`support`/`spy`) iptali: **30 dk**
  (`GameConfig.attack_cancel_minutes`).
- Katır (`trade`) iptali: **15 dk** (`GameConfig.donkey_cancel_minutes`).
- Pencere `Travel.can_cancel(depart_unix, now_unix, is_trade)` ile ölçülür.
- İptal yalnızca `state == "outgoing"` ve **dönüş olmayan** hareketlerde geçerlidir;
  birlikler **veya** hammadde kaynak köye **iade** edilir, hareket listeden çıkar.

## 12. Gönderimde yapılmayan kontroller (başka ajanlara devredilir)

- **Birim araştırma (`researched`)**: `send_*` bunu kontrol **etmez**; birim
  eğitim/araştırma sahipliği **A-ORDU**'nundur (`RulesEngine.is_researched`).
  Gönderim yalnızca **mevcut birim stokunu** (`village.units`) doğrular.
- **Eğitim kuyruğu / katır üretimi / Market kapasitesi**: ekonomi/askeri modüllerin işi.
- **Yüksek skor penceresi (200 oyunculu koruma)**: bu modülün kapsamı dışındadır.

`AÇIK SORU:` `send_*` çağrılarının araştırma kontrolünü de yapıp yapmayacağı
(istemci katmanı kararı).

---

## 13. Determinizm ve tamsayı kuralları (`docs/19` §2)

- Her harekette `battle_seed` **saklanır**. Seed:
  - `options.seed >= 0` ise **aynen** kullanılır; aksi halde
    `Movement.derive_seed(from_id, to_id, now_unix, movement_id)` ile **tamamen
    tamsayı** matematiğiyle türetilir.
  - **Global `randi()` YASAK.** Rastgelelik yalnızca `BattleSimulator` içinde,
    `movement.battle_seed` ile tohumlanan `RandomNumberGenerator`'dan gelir.
- Süreler `Travel.arrive_unix` ile `round_half_up` (`int(floor(x + 0.5))`) yuvarlanır.
- Sözlük döngüleri determinizm için **sıralı anahtar** üzerinden yürütülür.
- `ActionSimulator.process_tick(state, now_unix, delta_seconds) -> Array` imzası
  `docs/19` §7b ile **birebir** aynıdır.

---

## 14. Tüm AÇIK SORULAR (özet)

1. `AÇIK SORU:` Kanun Kaçağı işaretlemesi gönderimde mi varışta mı; puan türü (köy/toplam).
2. `AÇIK SORU:` Katır (ticaret) yolculuk hızı (alan/dakika).
3. `AÇIK SORU:` Ticaret için Market zorunluluğunun uygulama noktası.
4. `AÇIK SORU:` Sunucu saat dilimi ve gece bonusu penceresi.
5. `AÇIK SORU:` Destek birliklerinin geri çağrılma/otomatik dönüş davranışı.
6. `AÇIK SORU:` Bonus köylerde korumanın kapsamı.
7. `AÇIK SORU:` Kont mesafesinin alan/kıta ölçeği.
8. `AÇIK SORU:` `send_*` araştırma kontrolü yapmalı mı.

> **Kapanan sorular (resmî kaynakla çözüldü):**
> - Min. saldırı birimi kapsamı → yalnızca saldırı/talan (§2).
> - Casusluk raporunda Gizli Depo koruması → **toplam havuz**, yağma ile aynı (§3).
> - Normal/gizli casusluk görünürlüğü ve bilgi kademeleri (§3).

---

## 15. Doğrulanmış (bilinen) değerler — varsayım değil

`game/data` / `game/autoload` / dokümanlardan **okunan** değerler:

- Saldırı iptali 30 dk, katır iptali 15 dk (`GameConfig`, `docs/09` §6).
- Yeni oyuncu koruması 5 gün, fetih koruması 7 gün (`GameConfig`, `docs/11` §10).
- Maks. oran 10:1, Kanun Kaçağı cezası 60 gün (`GameConfig`, `battle.json`).
- Kont max mesafesi 80 alan (`GameConfig.count_max_distance`, `docs/08` §4).
- Min. saldırı birimi 3 × Kışla, **yalnızca saldırı/talan** (`RulesEngine.min_attack_units`, `worldinfo`).
- Gizli Depo casuslara karşı da korur (`buildings.txt`); kapasite `RulesEngine.hideout_capacity(sv)`, korunan miktar **toplam havuz** (`production.json` → `hideout_capacity.unit = "resource_total"`).
- Normal casusluk görünür + savunan rapor alır; gizli casusluk görünmez + savunan rapor almaz (`units_espionage.txt`).
- Dönüş süresi = gidiş süresi (`docs/19` §6).
- Katır hedefe ulaşınca kaybolur (`docs/14` §5).
- Terkedilmiş/bonus köyler korumasız (`docs/11` §10.5).
