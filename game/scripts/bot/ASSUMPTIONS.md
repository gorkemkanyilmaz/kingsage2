# Bot / AI Varsayımları ve Kararları (Taht ve Kılıç / A-BOT)

> Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §7b, `TASKS-CODE.md` FAZ 11.

---

## 1. Temel İlkeler ve Kısıtlar
1. **API Bütünlüğü:** Botlar kuralları, hammadde maliyetlerini, süreleri ve kısıtlamaları asla atlatamaz (`bypass: false`). Tüm eylemler `EconomyAPI`, `ArmyAPI` ve `Movement` üzerinden yürütülür.
2. **Determinizm:** Hiçbir global `randi()` veya determinizmi bozan çağrı yapılmaz. Tohum determinizmi `(world_seed, village_id)` çifti üzerinden yürütülür.
3. **Oyuncuya Saygı:** Botlar başlangıçta oyuncu köylerini yağmalamaz/saldırmaz; gelir kaynağı olarak soyguncu (terkedilmiş) köylerini hedefler.

---

## 2. Kişilikler ve Ağırlıklar
| Kişilik | İnşaat Önceliği | Asker Hedefi | Talan Saldırganlığı |
|---|---|---|---|
| `builder` | Hammadde, Kale, Depo, Değirmen | 15 (savunma ağırlıklı) | %50 ordu ile nadir talan |
| `trader` | Hammadde, Market, Gizli Depo | 30 (dengeli) | %50 ordu ile orta talan |
| `warlord` | Kışla, Sur, Çiftlik, Maden | 120 (saldırı ağırlıklı) | %85 ordu ile agresif talan |

---

## 3. Karar Aralıkları (Think Intervals)
| Zorluk | Karar Aralığı (Saniye) | Maksimum Ücretsiz Kuyruk Kullanımı |
|---|---|---|
| `easy` | 300 saniye (5 dk) | 2 iş |
| `normal` | 120 saniye (2 dk) | 2 iş |
| `hard` | 60 saniye (1 dk) | 3 iş |

---

## 4. Talan Menzili ve Min. Birlik Kapısı
- **Talan Hedefi:** 40 alan menzilindeki en yakın sahipsiz/soyguncu köyü.
- **Asgari Birlik:** `3 × Kışla seviyesi` şartı `Movement.can_send()` tarafından zorunlu tutulur; bot bu sayının altında sefere çıkamaz.
