# ASSET-MANIFEST — "Taht ve Kılıç" Varlık Envanteri

> **Proje:** Taht ve Kılıç (King's Age mobil yeniden yapımı, Godot 4.7.2)
> **Hazırlayan:** A-VARLIK ajanı · **Tarih:** 2026-10-18 · **Kapsam:** `game/assets/**`
> **Amaç:** Oyun için **ücretsiz, izin verilen lisanslı** görsel + işitsel + tipografik
> varlık toplamak; her birinin **lisansını kaydetmek**.
>
> ⚠️ **Telif:** Bu envanterde **hiçbir Gameforge / KingsAge varlığı yoktur.**
> Tüm içerik **Kenney.nl (CC0-1.0)** ve **Google Fonts (OFL-1.1)** kaynaklıdır.
> Bkz. `docs/18-SANAT-VE-ISIMLENDIRME.md` telif kontrol listesi.

---

## 1. Özet

| Metrik | Değer |
|---|---|
| Toplam dosya | **4.914** |
| Toplam boyut | **46,20 MB** (hedef < ~200 MB ✅) |
| Paket sayısı | 18 Kenney paketi + 8 font ailesi (7 Google Fonts + 1 Kenney) |
| Lisanslar | **CC0-1.0** (tüm Kenney) · **OFL-1.1** (tüm fontlar) |
| İndirilebilir ticari içerik | **0** |
| Lisans dosyaları | `game/assets/licenses/**` (29 dosya) |

| Üst dizin | Dosya | Boyut |
|---|---|---|
| `sprites/` | 4.492 | 38,86 MB |
| `audio/` | 373 | 3,45 MB |
| `fonts/` | 20 | 3,85 MB |
| `licenses/` | 29 | 0,04 MB |

---

## 2. GÖRSEL VARLIKLAR — BİNALAR (`game/assets/sprites/buildings/`)

| Paket | İçerik | Kaynak (sayfa / doğrudan zip) | Lisans | Yerel yol | Önemli dosyalar |
|---|---|---|---|---|---|
| **Isometric Tiles Buildings** | 129 izometrik bina tile'ı (99×85 px) + spritesheet | [page](https://kenney.nl/assets/isometric-tiles-buildings) · `https://kenney.nl/media/pages/assets/isometric-tiles-buildings/cfcdb066e1-1677694983/kenney_isometric-buildings.zip` | **CC0-1.0** | `sprites/buildings/isometric-tiles-buildings/{png,spritesheet}` | `png/buildingTiles_000.png` … `_128.png`, `spritesheet/buildingTiles.png` + `.xml` |
| **Isometric Tiles City** | 128 izometrik şehir tile'ı (132×104 px) + 11 detay + spritesheet | [page](https://kenney.nl/assets/isometric-tiles-city) · `…/isometric-tiles-city/7026b2670a-1677695025/kenney_isometric-city.zip` | **CC0-1.0** | `sprites/buildings/isometric-tiles-city/{png,details,spritesheet}` | `png/cityTiles_000.png` … `_127.png`, `details/cityDetails_000.png` … `_010.png` |
| **Isometric Miniature Dungeon** | 72 öğe × 4 yön (N/E/S/W) × 2 render (isometric + 3/4 "angle") = 576 PNG. Props: varil, sandık, köprü, masa, taş duvar/kapı/kale/merdiven, ahşap destek | [page](https://kenney.nl/assets/isometric-miniature-dungeon) · `…/isometric-miniature-dungeon/bdcbf8d79d-1674932261/kenney_isometric-miniature-dungeon.zip` | **CC0-1.0** | `sprites/buildings/isometric-miniature-dungeon/{isometric,angle}` | `stoneWallGateClosed_E.png`, `stoneWallRoundWindow_N.png`, `chestClosed_S.png`, `woodenCrate_W.png`, `stairsSpiral_E.png` |
| **Isometric Miniature Farm** | 57 öğe × 4 yön × 2 render = 456 PNG. **Modüler köy yapı taşları:** çatı, ahşap duvar (kapı/pencere/geçit/slope varyantlı), çit, merdiven, çuval, saman, tarla, mısır | [page](https://kenney.nl/assets/isometric-miniature-farm) · `…/isometric-miniature-farm/abd0274182-1670690319/kenney_isometric-miniature-farm.zip` | **CC0-1.0** | `sprites/buildings/isometric-miniature-farm/{isometric,angle}` | `roof_E.png`, `roofCorner_S.png`, `woodWallDoorClosed_E.png`, `woodWallWindowGlass_N.png`, `woodWallGateway_W.png`, `fenceHigh_S.png`, `hayBalesStacked_E.png`, `cornDouble_N.png` |
| **Isometric Miniature Library** | 36 öğe × 4 yön × 2 render = 288 PNG. **İç mekân / "Pazar + Akademi" için ideal:** kitaplık varyantları (dolu/boş/yıkık/gizli), uzun masa, sandalye, mumluk, vitrin | [page](https://kenney.nl/assets/isometric-miniature-library) · `…/isometric-miniature-library/577e09ff09-1674932086/kenney_isometric-miniature-library.zip` | **CC0-1.0** | `sprites/buildings/isometric-miniature-library/{isometric,angle}` | `bookcaseWideBooks_E.png`, `bookcaseDestroyed_N.png`, `longTableDecorated_S.png`, `displayCaseSword_W.png`, `candleStandDouble_E.png` |
| **Medieval RTS** (bina kısmı) | 23 yapı (1× 64px + 2× 128px) — **kuş bakışı (izometrik DEĞİL)**, yedek/ikon amaçlı | [page](https://kenney.nl/assets/medieval-rts) · `…/medieval-rts/0863f2c62a-1677693589/kenney_medieval-rts.zip` | **CC0-1.0** | `sprites/buildings/medieval-rts-topdown/{1x,2x}` | `1x/medievalStructure_01.png` … `_23.png` |

> 📐 **İzometrik oran:** Kenney izometrik tile'ları **2:1** (ölçülen örnek tile
> 99×85 ve 132×104 → ≈ 1.27:1 görünür kutu; tile'ı 2:1 elmas alana yerleştir).
> Yükseklik için binaları **ayak noktasından (pivot = alt-orta)** hizala.

---

## 3. GÖRSEL VARLIKLAR — BİRİMLER (`game/assets/sprites/units/`)

| Paket | İçerik | Kaynak | Lisans | Yerel yol | Önemli dosyalar |
|---|---|---|---|---|---|
| **Isometric Miniature Dungeon — Characters** | 8 karakter × (Idle 1 + Run 10 + Pickup 10) = **168 PNG**, izometrik render | (yukarıdaki dungeon zip'i) | **CC0-1.0** | `sprites/units/miniature-dungeon-characters` | `Male_0_Idle0.png`, `Male_3_Run[0-9].png`, `Male_5_Pickup[0-9].png` — indeks = karakter varyantı |
| **Medieval RTS** (birim kısmı) | 24 birim (1× 64px + 2× 128px) — kuş bakışı, **yer tutucu/yedek** | (yukarıdaki medieval-rts zip'i) | **CC0-1.0** | `sprites/units/medieval-rts-topdown/{1x,2x}` | `1x/medievalUnit_01.png` … `_24.png` |

> ⚠️ **DİKKAT:** İki unit seti **stil olarak uyuşmaz** (biri izometrik, biri kuş
> bakışı). Üretimde **tek set** seç. İzometrik hedef için → `miniature-dungeon-characters`.

---

## 4. GÖRSEL VARLIKLAR — HARİTA / ARAZİ (`game/assets/sprites/map/`)

| Paket | İçerik | Kaynak | Lisans | Yerel yol | Önemli dosyalar |
|---|---|---|---|---|---|
| **Isometric Blocks** | 135 izometrik blok (32 abstract + 48 platformer + 55 voxel) + 8 spritesheet | [page](https://kenney.nl/assets/isometric-blocks) · `…/isometric-blocks/86a0152f5b-1677662261/kenney_isometric-blocks.zip` | **CC0-1.0** | `sprites/map/isometric-blocks/{abstract,platformer,voxel,spritesheet}` | `abstract/abstractTiles_00.png`, `voxel/voxelTiles_00.png`, `spritesheet/abstractTiles.png + .xml` |
| **Medieval RTS** (tile + environment) | 58 zemin tile'ı + 21 çevre öğesi (ağaç/kaya) × 1×/2× | (yukarıdaki medieval-rts zip'i) | **CC0-1.0** | `sprites/map/medieval-rts-topdown/{1x,2x}/{tile,environment}` | `1x/tile/medievalTile_01.png`, `1x/environment/medievalEnvironment_01.png` |
| **Cartography Pack** (dokular) | 5 parşömen dokusu (`parchment*`) — harita/arka plan zemini | [page](https://kenney.nl/assets/cartography-pack) · `…/cartography-pack/2055ba99c2-1677578192/kenney_cartography-pack.zip` | **CC0-1.0** | `sprites/map/cartography-textures` | `parchmentBasic.png`, `parchmentAncient.png`, `parchmentCrinkled.png`, `parchmentFolded.png`, `parchmentFoldedCrinkled.png` |

---

## 5. GÖRSEL VARLIKLAR — ARAYÜZ (`game/assets/sprites/ui/`)

| Paket | İçerik | Kaynak | Lisans | Yerel yol | Önemli dosyalar |
|---|---|---|---|---|---|
| **UI Pack** | 5 renk (grey/blue/green/yellow/red) × 82 öğe × 1×/2× + 24 "extra" öğe. Buton (10 stil), panel, ok, kaydırıcı, input, ayraç | [page](https://kenney.nl/assets/ui-pack) · `…/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip` | **CC0-1.0** | `sprites/ui/ui-pack/{grey,blue,green,yellow,red,extra}/{1x,2x}` | `grey/2x/button_rectangle_depth_gloss.png`, `grey/2x/panel_rectangle.png`, `extra/2x/input_outline_rectangle.png`, `extra/2x/icon_play_light.png` |
| **UI Pack: RPG Expansion** | 87 öğe: pastel **bej/kahve/gri/mavi** paneller, `buttonLong_*`, `buttonSquare_*`, `barBack/barRed/barGreen/…` ilerleme çubukları, `icon_*` | [page](https://kenney.nl/assets/ui-pack-rpg-expansion) · `…/ui-pack-rpg-expansion/7ec4a46657-1677661824/kenney_ui-pack-rpg-expansion.zip` | **CC0-1.0** | `sprites/ui/ui-pack-rpg-expansion/{png,spritesheet}` | `png/panelInset_brown.png`, `png/buttonLong_beige.png`, `png/barGreen_horizontalLeft.png`, `png/icon_badge1.png` |
| **Fantasy UI Borders** | 9-slice panel/kenar/ayraç seti: 6 alt tür × (border, divider, divider-fade, panel, transparent-border, transparent-center) × 1×/2× | [page](https://kenney.nl/assets/fantasy-ui-borders) · `…/fantasy-ui-borders/ab29cd0165-1701602367/kenney_fantasy-ui-borders.zip` | **CC0-1.0** | `sprites/ui/fantasy-ui-borders/{1x,2x}/{border,divider,divider-fade,panel,transparent-border,transparent-center}` | `2x/panel/panel-006.png`, `2x/border/panel-border-009.png` — **Godot `NinePatchRect` için ideal** |

> ✅ **Öneri:** Ana tema = **`ui-pack-rpg-expansion`** (pastel bej/kahve, Orta Çağ
> hissi) + **`fantasy-ui-borders`** (9-slice çerçeve). `ui-pack` (grey/blue/…)
> düz/renkli buton ve sistem diyalogları için yedek.

---

## 6. GÖRSEL VARLIKLAR — İKONLAR (`game/assets/sprites/icons/`)

| Paket | İçerik | Kaynak | Lisans | Yerel yol | Önemli dosyalar |
|---|---|---|---|---|---|
| **Board Game Icons** | 255 ikon × 64px / 128px. **Kaynak + bina + savaş ikonları doğrudan var:** `resource_wood/lumber/planks/iron/wheat/apple`, `structure_house/church/farm/tower/wall/gate/watchtower`, `crown_a/b`, `sword`, `shield`, `bow`, `campfire`, `pouch`, `hourglass`, `lock_closed/open`, `flag_square/triangle`, `chess_king/queen/knight/rook/bishop/pawn`, `award`, `skull`, `fire` | [page](https://kenney.nl/assets/board-game-icons) · `…/board-game-icons/19cae04050-1721645690/kenney_board-game-icons.zip` | **CC0-1.0** | `sprites/icons/board-game/{64px,128px}` | ⭐ `64px/resource_wood.png`, `64px/resource_iron.png`, `64px/resource_wheat.png`, `64px/structure_watchtower.png`, `64px/crown_a.png`, `64px/sword.png`, `64px/hourglass.png` |
| **Cartography Pack** (ikonlar) | 83 harita ikonu × 1×/2× (64px). **Minimap/dünya haritası için birebir:** `castle/castleWide/castleTall`, `tower/watchtower/lighthouse`, `church`, `mill`, `mine`, `well`, `stable`, `dock`, `ship`, `bridge`, `gate/wall`, `house*`, `treePine*`, `rocks*`, `rocksMountain`, `lake*`, `path*`/`arrow*` (yol & rota), `compass`, `flag`, `banner`, `tent`, `graveyard`, `skull`, `chest`, `vulcano`, `pyramid`, `ruins` | (yukarıdaki cartography zip'i) | **CC0-1.0** | `sprites/icons/cartography/{1x,2x}` | ⭐ `1x/castle.png`, `1x/mill.png`, `1x/mine.png`, `1x/watchtower.png`, `1x/compass.png`, `1x/pathStraight.png`, `1x/arrowSplit.png` |
| **Game Icons** | 104 sistem ikonu × {black,white} × {1×,2×}. Oyuncu kontrolü/UI: `arrow*`, `checkmark`, `cross`, `gear`, `home`, `menuList/menuGrid`, `locked/unlocked`, `trophy`, `medal1/2`, `star`, `trashcan`, `warning`, `question`, `exclamation`, `pause/play/stop/forward/rewind`, `plus/minus`, `target`, `save`, `wrench`, `zoom*`, `audioOn/Off`, `musicOn/Off`, `leaderboardsSimple/Complex`, `multiplayer/singleplayer` | [page](https://kenney.nl/assets/game-icons) · `…/game-icons/1ebf9c14af-1677661579/kenney_game-icons.zip` | **CC0-1.0** | `sprites/icons/game-icons/{black,white}/{1x,2x}` | `black/2x/gear.png`, `black/2x/trophy.png`, `white/2x/checkmark.png`, `black/2x/leaderboardsSimple.png`, `black/2x/locked.png` |

> 📝 **Not:** `game-icons/black/1x` 105 dosyadan 104'ü alındı — `information.png`
> (önizleme/örnek görsel) bilinçli olarak **hariç tutuldu**.

---

## 7. SES VARLIKLARI (`game/assets/audio/`)

Tümü **.ogg (Vorbis)** — Godot'ta yerel destek, mobilde küçük boyut. **CC0-1.0.**

| Paket | İçerik | Kaynak | Lisans | Yerel yol | Önemli dosyalar |
|---|---|---|---|---|---|
| **RPG Audio** | 51 Orta Çağ/RPG efekt: kılıç, kitap, kapı, deri, metal, adım, sandık | [page](https://kenney.nl/assets/rpg-audio) · `…/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip` | **CC0-1.0** | `audio/rpg` | `drawKnife1.ogg`, `knifeSlice1.ogg`, `handleCoins.ogg`, `bookOpen.ogg`, `doorOpen_1.ogg`, `metalLatch.ogg`, `chop.ogg` |
| **Interface Sounds** | 100 UI sesi: click, back, close, confirmation, error, drop, glass, glitch, … | [page](https://kenney.nl/assets/interface-sounds) · `…/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip` | **CC0-1.0** | `audio/interface` | `click_001.ogg`, `confirmation_001.ogg`, `error_001.ogg`, `back_001.ogg`, `close_001.ogg` |
| **UI Audio** | 51 UI sesi: click/mouseclick/rollover/switch — 5 varyantlık setler | [page](https://kenney.nl/assets/ui-audio) · `…/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip` | **CC0-1.0** | `audio/ui` | `click1.ogg`…`click5.ogg`, `rollover1.ogg`, `switch1.ogg` |
| **UI Pack** (ses kısmı) | 6 ek UI sesi + fontlar (aşağıya bak) | (yukarıdaki ui-pack zip'i) | **CC0-1.0** | `audio/ui/kenney-ui-pack` | `click1.ogg`, `click2.ogg`, `switch1.ogg`… |
| **Impact Sounds** | 130 darbe/adım sesi (carpet/concrete/grass/snow + hit) | [page](https://kenney.nl/assets/impact-sounds) · `…/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip` | **CC0-1.0** | `audio/impact` | `footstep_grass_00[0-4].ogg`, `footstep_concrete_00[0-4].ogg` |
| **Music Jingles** | Kısa müzik jingle'ları (zafer/ödül/kapanış) — **Steel** + **Pizzicato** setleri (17+17) | [page](https://kenney.nl/assets/music-jingles) · `…/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip` | **CC0-1.0** | `audio/music/{steel,pizzicato}` | `steel/jingles_STEEL00.ogg`…`_16.ogg`, `pizzicato/jingles_PIZZI00.ogg`…`_16.ogg` |

> 🎵 **Not:** Jingle setlerinden yalnızca **Steel** (metalik, Orta Çağ) ve
> **Pizzicato** (yaylı, hafif) alındı; `8-Bit`, `Sax`, `Hit` setleri **alınmadı**
> (stil uyumu). İstenirse tek komutla eklenebilir (bkz. §9b).
> **Arka plan müziği (loop) henüz yok** → bkz. `AÇIK SORU`.

---

## 8. FONTLAR (`game/assets/fonts/`) — hepsi **Türkçe tam destekli**

Tüm fontlar **SIL Open Font License 1.1 (OFL-1.1)** — ticari kullanım, gömme ve
değiştirme serbest (RFN kısıtlarına uyuldu, bkz. §8.3).
**Her font `ç ğ ı İ ö ş ü` (ve `â î û`) glifleriyle programatik olarak doğrulandı** (§8.4).

### 8.1 Kullanılabilir fontlar

| Aile | Dosya(lar) | Rol / Öneri | Kaynak | Lisans |
|---|---|---|---|---|
| **Cinzel** | `Cinzel-Regular.ttf`, `Cinzel-SemiBold.ttf`, `Cinzel-Bold.ttf` | **BAŞLIK / logo** — Roma–Orta Çağ kapital serif, güçlü ve okunur | [Google Fonts](https://fonts.google.com/specimen/Cinzel) · `ofl/cinzel/` | **OFL-1.1** |
| **Metamorphous** | `Metamorphous-Regular.ttf` | **Alternatif başlık / dekor** — Orta Çağ el yazması havası | [GF](https://fonts.google.com/specimen/Metamorphous) · `ofl/metamorphous/` | **OFL-1.1** |
| **MedievalSharp** | `MedievalSharp.ttf` | **Vurgu / etkinlik başlığı** — kaligrafik, el çizimi | [GF](https://fonts.google.com/specimen/MedievalSharp) · `ofl/medievalsharp/` | **OFL-1.1** |
| **Almendra** | `Almendra-Regular.ttf` | **Kitap/alıntı metni** — dar, kitapvari serif | [GF](https://fonts.google.com/specimen/Almendra) · `ofl/almendra/` | **OFL-1.1** |
| **EB Garamond** | `EBGaramond-Regular.ttf`, `-SemiBold.ttf`, `-Bold.ttf`, `-Italic.ttf` | **Uzun metin / yardım / sözleşme** — yüksek okunurluk | [GF](https://fonts.google.com/specimen/EB+Garamond) · `ofl/ebgaramond/` | **OFL-1.1** |
| **Nunito** | `Nunito-Regular.ttf`, `-SemiBold.ttf`, `-Bold.ttf`, `-Italic.ttf` | **ANA UI / gövde** — yuvarlak, dostane; pastel paletle çok uyumlu | [GF](https://fonts.google.com/specimen/Nunito) · `ofl/nunito/` | **OFL-1.1** |
| **Rubik** | `Rubik-Regular.ttf`, `-Medium.ttf`, `-Bold.ttf`, `-Italic.ttf` | **Alternatif UI** — geometrik, nötr, sayı/rakam tabloları için net | [GF](https://fonts.google.com/specimen/Rubik) · `ofl/rubik/` | **OFL-1.1** |
| **Marcellus** | `Marcellus-Regular.ttf` | **Başlık alternatifi** — zarif Roma serif | [GF](https://fonts.google.com/specimen/Marcellus) · `ofl/marcellus/` | **OFL-1.1** |

### 8.2 Önerilen yazı tipi eşlemesi (Godot tema)

| Kullanım | Font |
|---|---|
| Oyun adı / ekran başlığı | `Cinzel-Bold` |
| Panel başlığı / bina adı | `Cinzel-SemiBold` veya `Metamorphous-Regular` |
| Buton / etiket / sayı | `Nunito-Bold` / `Nunito-SemiBold` |
| Gövde metni (yardım, açıklama) | `Nunito-Regular` veya `EBGaramond-Regular` |
| Uzun okuma (sözleşme/rapor) | `EBGaramond-Regular` |
| Dekor / etkinlik başlığı | `MedievalSharp` / `Almendra-Regular` |
| Rakam tabloları (maliyet, süre) | `Rubik-Medium` |

### 8.3 Değiştirme (instance) notu — OFL uyumu
`Cinzel`, `EBGaramond`, `Nunito`, `Rubik` **değişken (variable) fonttur**;
Godot'ta tek tek ağırlık kullanılabilmesi için **statik örneklere** ayrıldı
(fontTools `varLib.instancer`). Bu ailelerin OFL metinlerinde **Reserved Font
Name yoktur** → değişiklik ve isim koruma serbesttir.
**Not:** `Metamorphous`, `Almendra`, `Marcellus`, `MedievalSharp` **RFN içerir** →
bu yüzden **hiç değiştirilmedi**, indirildiği gibi bırakıldı (yalnızca
`Almendra-Regular` alındı).

`Almendra`'nın **Bold/Italic/BoldItalic** kesimleri **`Ğ ğ İ Ş ş` gliflerini
içermediği için bilinçli olarak ALINMADI** (Türkçe bozuk görünürdü).

### 8.4 Türkçe glif doğrulaması (otomatik)
`fontTools` ile `cmap` tablosu taranarak her TTF'de şu kod noktaları arandı:
`U+00C7 U+00E7 U+011E U+011F U+0130 U+0131 U+00D6 U+00F6 U+015E U+015F U+00DC U+00FC`
(+ `U+00C2 U+00E2 U+00CE U+00EE U+00DB U+00FB`).

| Font | Temel Türkçe | Ek (â/î/û) |
|---|---|---|
| Cinzel-{Regular,SemiBold,Bold} | ✅ tam | ✅ |
| EBGaramond-{Regular,SemiBold,Bold,Italic} | ✅ tam | ✅ |
| Nunito-{Regular,SemiBold,Bold,Italic} | ✅ tam | ✅ |
| Rubik-{Regular,Medium,Bold,Italic} | ✅ tam | ✅ |
| Metamorphous-Regular | ✅ tam | ✅ |
| MedievalSharp | ✅ tam | ✅ |
| Almendra-Regular | ✅ tam | ✅ |
| Marcellus-Regular | ✅ tam | ✅ |

### 8.5 Lisans dosyaları
`game/assets/licenses/FONTS-OFL/OFL-<aile>.txt` (8 dosya: cinzel, ebgaramond,
nunito, rubik, metamorphous, almendra, marcellus, medievalsharp) — her fontun
**özgün OFL metni ve telif satırı**.

### 8.6 Alınmayan fontlar (ve nedenleri)

| Font | Neden alınmadı |
|---|---|
| **Kenney Future / Kenney Future Narrow** (ui-pack, CC0) | `Ğ ğ İ ı Ş ş` glifleri **yok** → Türkçe desteklenmiyor |
| **Cinzel Decorative** (OFL) | Yalnız `latin` alt kümesi → latin-ext/Türkçe yok |
| **IM Fell English / SC**, **Uncial Antiqua** (OFL) | Yalnız `latin` → Türkçe yok |
| **Almendra Bold/Italic/BoldItalic** (OFL) | `Ğ ğ İ Ş ş` eksik |

---

## 9. Kaynak ve Yeniden Üretilebilirlik

### 9a. Tüm doğrudan indirme URL'leri (Kenney, CC0)

```
https://kenney.nl/media/pages/assets/isometric-tiles-buildings/cfcdb066e1-1677694983/kenney_isometric-buildings.zip
https://kenney.nl/media/pages/assets/isometric-tiles-city/7026b2670a-1677695025/kenney_isometric-city.zip
https://kenney.nl/media/pages/assets/isometric-blocks/86a0152f5b-1677662261/kenney_isometric-blocks.zip
https://kenney.nl/media/pages/assets/isometric-miniature-dungeon/bdcbf8d79d-1674932261/kenney_isometric-miniature-dungeon.zip
https://kenney.nl/media/pages/assets/isometric-miniature-farm/abd0274182-1670690319/kenney_isometric-miniature-farm.zip
https://kenney.nl/media/pages/assets/isometric-miniature-library/577e09ff09-1674932086/kenney_isometric-miniature-library.zip
https://kenney.nl/media/pages/assets/cartography-pack/2055ba99c2-1677578192/kenney_cartography-pack.zip
https://kenney.nl/media/pages/assets/medieval-rts/0863f2c62a-1677693589/kenney_medieval-rts.zip
https://kenney.nl/media/pages/assets/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip
https://kenney.nl/media/pages/assets/ui-pack-rpg-expansion/7ec4a46657-1677661824/kenney_ui-pack-rpg-expansion.zip
https://kenney.nl/media/pages/assets/fantasy-ui-borders/ab29cd0165-1701602367/kenney_fantasy-ui-borders.zip
https://kenney.nl/media/pages/assets/game-icons/1ebf9c14af-1677661579/kenney_game-icons.zip
https://kenney.nl/media/pages/assets/board-game-icons/19cae04050-1721645690/kenney_board-game-icons.zip
https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip
https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip
https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip
https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip
https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip
```

### 9b. Alınmayan ama hazır duran Kenney paketleri (istenirse eklenir)

| Paket | Boyut | Neden alınmadı |
|---|---|---|
| `kenney_tiny-battle.zip`, `kenney_tiny-dungeon.zip` | ~0,2 MB | **16×16 piksel** stili → 2.5D pastel izometrik ile uyuşmuyor |
| `kenney_voiceover-pack-fighter.zip` | 1,2 MB | Dövüşçü vokalleri; Orta Çağ temasına uymuyor |
| `music-jingles` → `8-Bit`, `Sax`, `Hit` setleri | ~0,7 MB | Stil uyumu (Elektronik / caz / darbe) |

### 9c. Google Fonts ham kaynaklar (OFL, `main` dalı)

```
https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/ebgaramond/EBGaramond%5Bwght%5D.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/ebgaramond/EBGaramond-Italic%5Bwght%5D.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito-Italic%5Bwght%5D.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/rubik/Rubik%5Bwght%5D.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/rubik/Rubik-Italic%5Bwght%5D.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/metamorphous/Metamorphous-Regular.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/almendra/Almendra-Regular.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/marcellus/Marcellus-Regular.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/medievalsharp/MedievalSharp.ttf
# lisanslar
https://raw.githubusercontent.com/google/fonts/main/ofl/<aile>/OFL.txt
```

---

## 10. Atıf (isteğe bağlı, CC0 gerektirmez)

> Sanat & ses: **Kenney** (kenney.nl) — CC0.
> Yazı tipleri: Cinzel, EB Garamond, Nunito, Rubik, Metamorphous, Almendra,
> Marcellus, MedievalSharp — **SIL Open Font License 1.1**.

Kenney'e atıf **zorunlu değildir** ama oyunun *Hakkında* ekranında aşağıdaki
satır bulundurulmalı (kaynak şeffaflığı + OFL uyumu için font atıfları **iyi
uygulamadır**):

```
Bu oyundaki görsel ve işitsel varlıkların bir bölümü Kenney (kenney.nl) tarafından
CC0 lisansıyla sağlanmıştır. Yazı tipleri SIL Open Font License 1.1 kapsamındadır.
Tam liste: assets/ASSET-MANIFEST.md
```

---

## 11. Dizin Ağacı (yerel)

```
game/assets/
├─ ASSET-MANIFEST.md          ← bu dosya
├─ PALET.md                   ← pastel & canlı renk sistemi
├─ licenses/
│  ├─ KENNEY/                 ← 21 Kenney lisans metni (CC0-1.0)
│  └─ FONTS-OFL/              ← 8 OFL lisans metni (OFL-1.1)
├─ fonts/                     ← 19 .ttf (Türkçe doğrulanmış)
├─ audio/
│  ├─ rpg/  interface/  ui/ (ui/kenney-ui-pack)  impact/
│  └─ music/{steel,pizzicato}/
└─ sprites/
   ├─ buildings/  isometric-tiles-buildings/ · isometric-tiles-city/
   │              isometric-miniature-{dungeon,farm,library}/
   │              medieval-rts-topdown/
   ├─ units/      miniature-dungeon-characters/ · medieval-rts-topdown/
   ├─ map/        isometric-blocks/ · medieval-rts-topdown/ · cartography-textures/
   ├─ ui/         ui-pack/ · ui-pack-rpg-expansion/ · fantasy-ui-borders/
   └─ icons/      board-game/ · cartography/ · game-icons/
```

| Yol | Dosya | Boyut |
|---|---|---|
| `sprites/buildings/isometric-tiles-buildings` | 131 | 1,33 MB |
| `sprites/buildings/isometric-tiles-city` | 143 | 0,82 MB |
| `sprites/buildings/isometric-miniature-dungeon` | 576 | 12,07 MB |
| `sprites/buildings/isometric-miniature-farm` | 456 | 8,88 MB |
| `sprites/buildings/isometric-miniature-library` | 288 | 4,88 MB |
| `sprites/buildings/medieval-rts-topdown` | 46 | 0,10 MB |
| `sprites/units/miniature-dungeon-characters` | 168 | 0,71 MB |
| `sprites/units/medieval-rts-topdown` | 48 | 0,07 MB |
| `sprites/map/isometric-blocks` | 143 | 1,84 MB |
| `sprites/map/medieval-rts-topdown` | 158 | 0,35 MB |
| `sprites/map/cartography-textures` | 5 | 3,21 MB |
| `sprites/ui/ui-pack` | 868 | 0,61 MB |
| `sprites/ui/ui-pack-rpg-expansion` | 89 | 0,08 MB |
| `sprites/ui/fantasy-ui-borders` | 280 | 0,05 MB |
| `sprites/icons/board-game` | 510 | 0,36 MB |
| `sprites/icons/cartography` | 166 | 0,18 MB |
| `sprites/icons/game-icons` | 416 | 3,32 MB |
| `audio/rpg` | 51 | 0,69 MB |
| `audio/interface` | 100 | 0,92 MB |
| `audio/ui` | 57 (51 + 6 `kenney-ui-pack`) | 0,35 MB |
| `audio/impact` | 130 | 0,99 MB |
| `audio/music` | 34 | 0,50 MB |
| `fonts` | 20 | 3,85 MB |
| `licenses` | 29 | 0,04 MB |

---

## 12. Doğrulama Kontrolleri

- ✅ **Lisans:** 18/18 Kenney paketi CC0-1.0, 8/8 font OFL-1.1 — her birinin lisans
  metni `licenses/` altında saklı.
- ✅ **Türkçe karakter:** 19/19 TTF font programatik `cmap` testinden geçti.
- ✅ **Dosya bütünlüğü:** rastgele 400 PNG `System.Drawing` ile açıldı — **0 bozuk**.
- ✅ **Sıfır bayt:** yalnızca 3 adet `.gitkeep` (kasıtlı); 0 beklenmeyen boş dosya.
- ✅ **Yol hijyeni:** tüm dosya adları ASCII, boşluk/parantez/köşeli parantez yok
  (Godot `res://` yollarında sorunsuz).
- ✅ **Telif:** Gameforge / KingsAge kaynaklı **tek bir dosya bile yok**;
  `data/**`, `docs/**`, `research/**` altına **dokunulmadı**.
- ✅ **Boyut:** 46,20 MB (< 200 MB hedefi).
- ✅ **Kapsam:** yalnızca `game/assets/**` yazıldı.

---

## 13. AÇIK SORULAR

- `AÇIK SORU:` **İzometrik birim sprite'ı seti sınırlı.** Mevcut tek izometrik
  karakter seti `miniature-dungeon-characters` (8 karakter × Idle/Run/Pickup).
  **Asker tipi ayrımı yok** (mızrakçı/okçu/süvari/kılıçlı). 11 birim için ya
  (a) bu 8 karakter **renk/ekipman tint**'i ile çoğaltılacak, ya (b) **özgün
  izometrik sprite üretilecek** (AI/çizer), ya da (c) kuş bakışı `medieval-rts`
  birimleri stilleştirilecek. Karar **sanat yönetimi** onayı gerektiriyor.
- `AÇIK SORU:` **Bina sayısı ↔ mevcut sprite sayısı.** Gereken 15 bina + seviye
  aşamaları için hazır *vanilya* izometrik model **yok**; `miniature-farm`
  modüler parçaları (duvar/çatı/kapı/pencere) ile **özgün binalar
  birleştirilmeli**. Bu bir "kit-bash" iş akışıdır — sanat ekibi onayı gerekir.
- `AÇIK SORU:` **Arka plan müziği (loop) yok.** CC0 loop'lu Orta Çağ ambient
  müziği için OGA / FreePD / Kevin MacLeod (CC-BY) adayları var; **CC-BY atıf
  gerektirir**. CC0 alternatif bulunana kadar müzik **dışarıda bırakıldı**.
  Tercih: CC0 ambient bul ya da özgün sipariş et.
- `AÇIK SORU:` **Uygulama ikonu ve mağaza görselleri** bu envanterde **yok**
  (özgün olmalı; `docs/18` §3.1). `isometric-city` + `board-game/crown_a`
  ikonlarla taslak üretilebilir mi?
- `AÇIK SORU:` `cartography-pack` ikonları **düz (flat) 2D** — izometrik sahneyle
  karışınca stil kırılması olur mu? Yalnız **minimap/dünya haritası** katmanında
  kullanılması öneriliyor; onay gerekiyor.
- `AÇIK SORU:` Godot'ta izometrik tile'lar için **TileSet + Y-sort** kullanılacak
  (bkz. `docs/16`). Sprite'ların **pivot noktaları** standartlaştırılmalı
  (bina = alt-orta, birim = ayak tabanı). Bu bir kod tarafı kararı → `TASKS-CODE.md`.
- `AÇIK SORU:` `medieval-rts-topdown` seti **tamamen çıkarılsın mı?** (Stil
  uyuşmazlığı). Şu an "yedek/yer tutucu" olarak dahil edildi; kaldırılması
  veya kalması **sanat yönetimi** kararı.
