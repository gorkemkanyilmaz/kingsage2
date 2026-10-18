extends RefCounted
## Palette — "Taht ve Kılıç" pastel renk sistemi (A-ARAYUZ).
##
## Kaynak: `game/assets/PALET.md` ve `docs/20-ARAYUZ-TASARIMI.md` §5.
## Renkler **tek yerde** tanımlanır; tema (`TahtVeKilic.tres`) ve arayüz kodları
## buradan beslenir. Saf siyah yoktur (gölgeler pasteldir).
##
## Kullanım (global sınıf adı YOK — `preload` ile):
##     const Palette := preload("res://themes/Palette.gd")
##     label.add_theme_color_override("font_color", Palette.c("murekkep"))

## Hex → isim eşlemesi. `.tres` ile aynı değerleri taşır.
const HEX := {
	# Marka / durum
	"safir": "#6E9BE8",
	"safir_hover": "#8FB4F0",
	"safir_pressed": "#4A72BE",
	"basari": "#7ED957",
	"basari_hover": "#9BE873",
	"basari_pressed": "#63B843",
	"uyari": "#F7C948",
	"uyari_pressed": "#C4951B",
	"hata": "#F2705D",
	"hata_pressed": "#CF5F49",
	"pasif": "#D9E0EA",
	"altin": "#FFD24A",
	# Yüzeyler
	"parsomen": "#FDF6E3",
	"parsomen_koyu": "#F2E4C8",
	"bulut": "#FBFBF7",
	"sis": "#D9E0EA",
	"duman": "#B9BFCC",
	"panel": "#FFFDF7",
	"panel_alt": "#F2E4C8",
	"panel_kenar": "#9A6437",
	"panel_kenar_tas": "#B0A18A",
	"panel_golge": "#6B432A",
	"perde": "#23222B",
	# Metin
	"murekkep": "#3B3630",
	"murekkep_soluk": "#7C7368",
	"tebesir": "#FFFDF7",
	# Malzeme / harita
	"cim_isik": "#D8F0A6",
	"cim": "#A9DC72",
	"cim_koyu": "#9FD167",
	"cim_golge": "#77B54A",
	"derin_yesil": "#4C8A38",
	"sig_su": "#B6EFE9",
	"su": "#7DD3E0",
	"su_golge": "#4EA6C6",
	"derin_su": "#2C7A9C",
	"kum_isik": "#F8E7B8",
	"kum": "#EDCE8F",
	"toprak": "#D6A469",
	"yol": "#E3C79A",
	"sur_isik": "#F1EADC",
	"tas": "#D7CCB8",
	"tas_golge": "#B0A18A",
	"tas_derin": "#877A66",
	"merser": "#F7F3E8",
	"ahsap_isik": "#EBC79C",
	"ahsap": "#C98F5B",
	"ahsap_golge": "#9A6437",
	"kiremit_isik": "#FFC2AC",
	"kiremit": "#F58A6E",
	"demir": "#9AA4B4",
	# Kaynak ikon renkleri
	"odun": "#C98F5B",
	"demir_ikon": "#9AA4B4",
	"tahil": "#E0B23A",
	"nufus": "#FF9E9E",
	"insaat": "#8FD4E6",
	"arastirma": "#B9A3F0",
	# Harita tarafları
	"dost": "#6EC1E4",
	"kendi": "#7ED957",
	"notr": "#C9C2B6",
	"dusman": "#F2705D",
	"destek": "#8FD4E6",
	"secili": "#FFD24A",
	"kilitli": "#B9BFCC",
	# Gündüz-gece
	"safak": "#FFD9A0",
	"sabah": "#FFF6E0",
	"altin_saat": "#FFB37A",
	"aksam": "#C79ACB",
	"gece": "#2B3A67",
}

static var _cache: Dictionary = {}


## İsimle renk döndürür (önbellekli). Bilinmeyen isim → beyaz.
static func c(name: String) -> Color:
	if _cache.has(name):
		return _cache[name]
	var value := Color(HEX.get(name, "#FFFFFF"))
	_cache[name] = value
	return value


## Hex dizesinden renk.
static func hex(code: String) -> Color:
	return Color(code)


## Renk + alfa.
static func ca(name: String, alpha: float) -> Color:
	var col := c(name)
	col.a = alpha
	return col


## Bir rengi `amount` oranında koyulaştırır (saf siyaha değil, tona çeker).
static func darken(col: Color, amount: float = 0.18) -> Color:
	return col.lerp(c("panel_golge"), clampf(amount, 0.0, 1.0))


## Bir rengi aydınlatır (pastel beyaza çeker).
static func lighten(col: Color, amount: float = 0.18) -> Color:
	return col.lerp(c("bulut"), clampf(amount, 0.0, 1.0))
