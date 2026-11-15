extends Node
## EventBus — global sinyal veri yolu (Taht ve Kılıç).
##
## Servisler birbirini doğrudan tanımaz; durum değişimlerini buradan yayınlar.
## Sinyal adları ve parametreleri **sözleşmedir**: diğer ajanlar (A-EKONOMI,
## A-ORDU, A-SAVAS, A-ARAYUZ …) bu isimlere göre bağlanır. Değiştirilmesi
## gerekirse başka ajanlara haber verilmelidir.

# --- Genel durum ------------------------------------------------------------

## Herhangi bir kök durum değişiminde yayınlanır (kaydet/arayüz tazeleme için).
signal state_changed()

## Bir köyün hammaddeleri / vatandaşı değişti.
signal resources_changed(village_id: int)

## Sunucu ayarları (GameConfig) yüklendi veya değişti.
signal config_changed()

# --- Binalar ve inşaat ------------------------------------------------------

signal building_started(village_id: int, key: String, level: int)
signal building_completed(village_id: int, key: String, level: int)
signal building_torn_down(village_id: int, key: String)

# --- Araştırma ve eğitim (Ordu) --------------------------------------------

signal research_started(village_id: int, unit_key: String)
signal research_completed(village_id: int, unit_key: String)
signal unit_training_started(village_id: int, unit_key: String, count: int)
signal unit_trained(village_id: int, unit_key: String, count: int)
signal unit_dismissed(village_id: int, unit_key: String, count: int)

# --- Emirler / hareketler (ordu, destek, ticaret) --------------------------

signal army_sent(movement)
signal army_arrived(movement)
signal army_returned(movement)
signal trade_sent(movement)
signal movement_cancelled(movement)

# --- Savaş / casusluk / fetih ----------------------------------------------

signal battle_resolved(report)
signal spy_mission_resolved(report)
signal village_conquered(village_id: int, new_owner_name: String)
signal player_conquered(world_id: int, player_name: String)
signal realm_of_power_changed(village_id: int, value: int)

# --- Rapor / mesaj ----------------------------------------------------------

signal report_created(report)
signal message_created(message)

# --- Zaman ve oturum --------------------------------------------------------

## GameClock her oyun-içi tick adımında yayınlar.
signal tick(delta_seconds: float)

## Offline telafi (hızlı-ileri) tamamlandığında yayınlanır.
signal fast_forward_finished(elapsed_seconds: float)

signal game_loaded()
signal game_saved()

# --- Hata -------------------------------------------------------------------

signal error_occurred(code: String, message: String)
