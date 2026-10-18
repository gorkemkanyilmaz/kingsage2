# QA RAPORU — Entegrasyon, Kaydet/Yükle ve Değişmezler Doğrulaması

> **Ajan:** A-QA  
> **Motor:** Godot 4.7.2-stable (headless console)  
> **Tarih:** 2026-10-18  

---

## 1. Test Suite Çıktıları ve Kanıtlar

| Test Dosyası | Kapsam | Assertion | Sonuç | Çıkış Kodu |
|---|---|---|---|---|
| `test_rules.gd` | 15 bina × 461 seviye maliyet/süre/önkoşul | 159 | ✅ PASS | 0 |
| `test_world.gd` | 200×200 dünya, 4 kıta, 6 bonus türü, soyguncular | 152 | ✅ PASS | 0 |
| `test_battle.gd` | 5 fazlı savaş simülasyonu, sur/moral/gece/talan | 50 | ✅ PASS | 0 |
| `test_army.gd` | Araştırma, eğitim, Altın Zırh, Kont, dismiss | 66 | ✅ PASS | 0 |
| `test_economy.gd` | Üretim, depo tavanı, kuyruk ek maliyeti, iade kuralı | 126 | ✅ PASS | 0 |
| `test_actions.gd` | Hareketler, casusluk, gizli depo semantiği, 10:1 Kanun Kaçağı | 105 | ✅ PASS | 0 |
| `test_bot.gd` | 100 bot × 30 gün, kişilikler, kurallara tam bağlılık | 20 | ✅ PASS | 0 |
| `test_save.gd` | Kaydet/Yükle roundtrip, kanonik hash, 30 gün offline, bozuk dosya | 18 | ✅ PASS | 0 |
| `test_integration.gd` | Uçtan uca senaryo: ekonomi, kışla zinciri, ordu, talan, iptal, determinizm | 26 | ✅ PASS | 0 |
| **TOPLAM** | **Tüm Oyun Motoru Doğrulaması** | **722** | **%100 PASS (0 HATA)** | **0** |

---

## 2. Doğrulanan Sistem Değişmezleri (Invariants)
1. **Kaynak Bütünlüğü:**
   - Hiçbir koşulda (üretim, inşaat, araştırma, eğitim, talan, iptal iadesi) hammadde negatif olamaz (`kaynak >= 0`).
   - Depo kapasitesi aşımı engellenir (`kaynak <= depo_tavanı`).
2. **Nüfus Sınırı:**
   - Köyün çalışan vatandaş sayısı Değirmen tavanını aşamaz (`used_citizens <= max_citizens`).
   - Askerler ve binalar Değirmen kapasitesi yetersizken başlatılamaz.
3. **Güç Alanı:**
   - Her zaman `0 <= realm_of_power <= village_points`.
   - Fetih korumasında Güç Alanı düşürülemez.
4. **Gereksinim Zinciri:**
   - Önkoşullar (`requirements.json`) tam sıralı olarak sağlanmadıkça hiçbir bina/birim başlatılamaz (Kışla için Depo 3 + Değirmen 3 şarttır).
5. **İptal İadesi Muhasebesi:**
   - Kuyruk ek maliyeti (`extra_paid`) iade EDİLMEZ.
   - Yalnızca taban maliyet (`cost_paid`) iade edilir.
6. **Determinizm ve Kayıt Sürekliliği:**
   - İki bağımsız çalıştırmada aynı tohum ve tick dizisi birebir aynı MD5 durum hash'ini üretir.
   - Bir simülasyonun ortasında serileştirilip geri yüklenmesi (split simulation) kesintisiz tek parça simülasyonla bit-seviyesinde aynı sonucu verir.

---

## 3. Bulgular ve Düzeltmeler (Bug Listesi)
1. **`sim_now_unix` zaman senkronizasyonu:**
   - `EconomyAPI` ve `BuildQueue` simülasyon saati için `state.world.sim_now_unix` alanına bakar. Bu alan simülasyon adımlarında her tick güncellenmelidir; aksi halde gerçek sistem saatine düşer. Entegrasyon döngüsünde bu kural doğrulandı.
2. **Kuyruk dönüş nesnesi anahtar adı:**
   - `EconomyAPI.start_build` dönüşünde kuyruk öğesi `"item"` anahtarında saklanır (`"queue"` değil). Dokümantasyonla hizalandı.
3. **Terkedilmiş köy hedef kontrolü:**
   - `Protection.is_unprotected_kind()` yanı sıra hedef köyün `is_barbarian: true` veya `owner: "Soyguncular"` durumu da korumasız sayılmalıdır. `BotWar` içerisinde bu kapsayıcı kontrol eklendi.
