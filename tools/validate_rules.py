# -*- coding: utf-8 -*-
"""
Taht ve Kılıç — Kural Doğrulayıcı (A-KURAL / T-3.7)
====================================================

Ne yapar?
---------
`data/buildings.json` (bina seviye tabloları, kaynak) ile `game/data/rules/*.json`
(kural seti) dosyalarını yükler ve şunları doğrular:

  * JSON'lar geçerli mi, zorunlu alanlar var mı?
  * Gereksinim DAG'ı **asiklik** mi (cycle yok)?
  * Her referans edilen bina anahtarı gerçek mi ve istenen seviye o binanın
    maksimum seviyesi içinde mi?
  * Bildirilen büyüme faktörleri bina maliyet tablolarını **toleransla** üretiyor mu?
  * Maliyet / üretim / kapasite tabloları **monoton** mu?
  * Üretim, kapasite, sur bonusu, market katır ve zaman faktörü tabloları kaynakla
    birebir aynı mı?
  * Birim araştırma/eğitim gereksinimleri (Kışla seviyeleri) tutarlı mı?
  * `known: false` işaretli her alanın bir `assumption` açıklaması var mı?

Çıktı: okunabilir rapor. **Başarıda exit code 0, aksi halde 1.**

Kullanım
--------
    python tools/validate_rules.py

Not: Proje kökü, bu dosyanın konumundan türetilir (tools/validate_rules.py -> kök).
"""

from __future__ import annotations

import codecs
import json
import math
import os
import sys


# --------------------------------------------------------------------------- I/O
def _setup_console() -> None:
    """Türkçe karakterler için stdout'u UTF-8'e ayarla (Windows dostu)."""
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    if os.name == "nt":
        try:
            import ctypes

            ctypes.windll.kernel32.SetConsoleOutputCP(65001)
        except Exception:
            pass


HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_BUILDINGS = os.path.join(ROOT, "data", "buildings.json")
DATA_UNITS = os.path.join(ROOT, "game", "data", "units.json")
RULES_DIR = os.path.join(ROOT, "game", "data", "rules")

RULES_FILES = {
    "requirements": "requirements.json",
    "costs": "costs.json",
    "production": "production.json",
    "time_factors": "time-factors.json",
    "battle": "battle.json",
    "units": "units.json",
}

RESOURCES = ("wood", "stone", "iron")

# Beklenen gereksinim zinciri (görev tanımı + docs/04-BINALAR.md)
FREE_START = ["main", "stone", "wood", "iron", "farm", "storage"]
EXPECTED_CHAIN = {
    "hide": [("farm", 3)],
    "barracks": [("storage", 3), ("farm", 3)],
    "wall": [("barracks", 1)],
    "market": [("storage", 5)],
    "stable": [("market", 1)],
    "garage": [("barracks", 5)],
    "snob": [("garage", 5)],
    "smith": [("snob", 1)],
}
EXPECTED_BARRACKS_LEVELS = {
    "farmer": 1, "spear": 1, "sword": 1, "axe": 2, "spy": 4,
    "bow": 5, "light": 7, "heavy": 16, "ram": 20, "kata": 25,
}
EXPECTED_NOT_RESEARCHED = ["snob"]
EXPECTED_QUEUE_PERCENT = [0, 0, 0, 25, 56, 95, 144, 205, 281, 376]


# ------------------------------------------------------------------- yardımcılar
def read_json(path: str):
    """BOM toleranslı UTF-8 JSON okur."""
    with open(path, "rb") as fh:
        raw = fh.read()
    if raw.startswith(codecs.BOM_UTF8):
        raw = raw[len(codecs.BOM_UTF8):]
    return json.loads(raw.decode("utf-8"))


def parse_num(value) -> float:
    """'1.020' -> 1020.0, '105%' -> 105.0, 12 -> 12.0 (TR binlik ayırıcı)."""
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace("\u00a0", "")
    text = text.replace("%", "").replace(".", "").replace(",", ".")
    if text == "":
        return float("nan")
    return float(text)


def round_half_up(x: float) -> int:
    return int(math.floor(x + 0.5))


class Validator:
    def __init__(self) -> None:
        self.results: list[tuple[str, bool, str, str]] = []
        self.warnings: list[tuple[str, str]] = []
        self.errors = 0
        self.section = "-"

    def sec(self, name: str) -> None:
        self.section = name

    def ok(self, label: str, detail: str = "") -> None:
        self.results.append((self.section, True, label, detail))

    def fail(self, label: str, detail: str = "") -> None:
        self.results.append((self.section, False, label, detail))
        self.errors += 1

    def expect(self, cond, label: str, detail: str = "") -> None:
        if cond:
            self.ok(label, detail)
        else:
            self.fail(label, detail)

    def warn(self, label: str, detail: str = "") -> None:
        self.warnings.append((self.section, label + ((" — " + detail) if detail else "")))


# ------------------------------------------------------------------- yükleme
def load_all(rep: Validator):
    """Kaynak ve kural dosyalarını yükler. Kritik hata olursa (None, ...) döner."""
    rep.sec("Yükleme")
    if not os.path.isfile(DATA_BUILDINGS):
        rep.fail("Kaynak bulunamadı: %s" % os.path.relpath(DATA_BUILDINGS, ROOT))
        return None
    try:
        buildings_list = read_json(DATA_BUILDINGS)
    except Exception as exc:  # noqa: BLE001
        rep.fail("data/buildings.json okunamadı", str(exc))
        return None
    rep.ok("data/buildings.json geçerli JSON", "%d bina" % len(buildings_list))

    buildings = {b["key"]: b for b in buildings_list}
    max_level = {k: int(b["maxLevel"]) for k, b in buildings.items()}
    name_tr = {k: b["name"] for k, b in buildings.items()}

    rules = {}
    missing = []
    for key, fname in RULES_FILES.items():
        path = os.path.join(RULES_DIR, fname)
        if not os.path.isfile(path):
            missing.append(fname)
            continue
        try:
            rules[key] = read_json(path)
            rep.ok("game/data/rules/%s yüklendi" % fname)
        except Exception as exc:  # noqa: BLE001
            rep.fail("game/data/rules/%s okunamadı" % fname, str(exc))
    if missing:
        rep.fail("Eksik kural dosyaları", ", ".join(missing))
        return None

    try:
        units_data = read_json(DATA_UNITS)
    except Exception as exc:  # noqa: BLE001
        rep.fail("game/data/units.json okunamadı", str(exc))
        return None
    rep.ok("game/data/units.json geçerli JSON", "%d birim" % len(units_data["units"]))

    return buildings, max_level, name_tr, rules, units_data


# --------------------------------------------------------------- requirements
def check_requirements(rep: Validator, buildings, max_level, name_tr, rules):
    rep.sec("requirements.json")
    req = rules["requirements"]
    keys = list(max_level.keys())
    key_order = req.get("key_order", [])
    entries = {b["key"]: b for b in req.get("buildings", [])}

    rep.expect(set(key_order) == set(keys),
               "key_order = data bina anahtarları",
               "eksik/fazla: %s" % ((set(key_order) ^ set(keys)) or "yok"))
    rep.expect(len(key_order) == len(set(key_order)), "key_order tekrarsız")
    rep.expect(set(entries) == set(keys),
               "buildings[] tüm binaları içeriyor",
               "eksik/fazla: %s" % ((set(entries) ^ set(keys)) or "yok"))

    # maks seviye / isim tutarlılığı
    bad = []
    for k, e in entries.items():
        if k in max_level and int(e.get("max_level", -1)) != max_level[k]:
            bad.append("%s: %s != %s" % (k, e.get("max_level"), max_level[k]))
        if k in name_tr and e.get("name_tr") != name_tr[k]:
            bad.append("%s ad: %r != %r" % (k, e.get("name_tr"), name_tr[k]))
    rep.expect(not bad, "max_level ve name_tr data ile aynı", "; ".join(bad))

    # referans geçerliliği
    bad_ref = []
    too_high = []
    for k, e in entries.items():
        for r in e.get("requires", []):
            bk = r.get("building")
            lv = r.get("level")
            if bk not in max_level:
                bad_ref.append("%s -> bilinmeyen '%s'" % (k, bk))
                continue
            if not isinstance(lv, int) or lv < 1:
                bad_ref.append("%s -> %s seviye=%r" % (k, bk, lv))
            elif lv > max_level[bk]:
                too_high.append("%s -> %s Lv%s > maks %s" % (k, bk, lv, max_level[bk]))
            if bk == k:
                bad_ref.append("%s kendine bağımlı" % k)
    rep.expect(not bad_ref, "Tüm gereksinim referansları gerçek anahtar", "; ".join(bad_ref))
    rep.expect(not too_high, "İstenen seviyeler bina maks. seviyesi içinde", "; ".join(too_high))

    # operatör
    ops = {e.get("requires_operator") for e in entries.values()}
    rep.expect(ops <= {"all"}, "requires_operator yalnızca 'all'", str(sorted(ops)))

    # serbest başlangıç
    empty = sorted(k for k, e in entries.items() if not e.get("requires"))
    rep.expect(empty == sorted(FREE_START),
               "Serbest başlangıç binaları doğru",
               "bulunan: %s" % empty)

    # beklenen zincir
    chain_bad = []
    for k, expected in EXPECTED_CHAIN.items():
        got = sorted((r["building"], int(r["level"])) for r in entries.get(k, {}).get("requires", []))
        if got != sorted(expected):
            chain_bad.append("%s: %s != %s" % (k, got, sorted(expected)))
    rep.expect(not chain_bad, "Gereksinim zinciri görev tanımıyla birebir", "; ".join(chain_bad))

    # Anıt özel kuralı
    statue = entries.get("statue", {})
    if statue.get("requires_special") == "all_buildings_at_max_level":
        expected = {(k, max_level[k]) for k in keys if k != "statue"}
        got = {(r["building"], int(r["level"])) for r in statue.get("requires", [])}
        rep.expect(got == expected,
                   "Anıt: TÜM diğer binalar maks. seviyede",
                   "eksik/fazla: %s" % (sorted(got ^ expected) or "yok"))
    else:
        rep.warn("Anıt (statue) requires_special tanımlı değil")

    # ---------------- DAG asiklik
    graph = {k: [r["building"] for r in entries[k].get("requires", [])] for k in entries}
    order, cycle = _topo(graph)
    rep.expect(cycle is None, "Gereksinim DAG'ı asiklik",
               ("döngü: " + " -> ".join(cycle)) if cycle else "")

    # kök erişilebilirliği: serbest binalardan tüm binalar açılabiliyor mu?
    if cycle is None:
        reach = set(FREE_START)
        changed = True
        while changed:
            changed = False
            for k in keys:
                if k not in reach and all(p in reach for p in graph.get(k, [])):
                    reach.add(k)
                    changed = True
        rep.expect(reach == set(keys),
                   "Serbest binalardan tüm binalara erişilebiliyor",
                   "erişilemeyen: %s" % sorted(set(keys) - reach))
        rep.ok("Topolojik sıra", " -> ".join(order))

    # ---------------- birim araştırma özeti
    ur = req.get("unit_research", {})
    rep.expect(ur.get("barracks_levels") == EXPECTED_BARRACKS_LEVELS,
               "requirements.unit_research.barracks_levels doğru",
               str(ur.get("barracks_levels")))
    rep.expect(sorted(ur.get("not_researched", [])) == EXPECTED_NOT_RESEARCHED,
               "Araştırılmayan birim yalnızca Kont")


def _topo(graph):
    """Kahn topolojik sıralama. Döngü varsa (order, cycle_path) döner."""
    indeg = {n: 0 for n in graph}
    children = {n: [] for n in graph}
    for n, deps in graph.items():
        for d in deps:
            indeg[n] += 1
            children.setdefault(d, []).append(n)
    ready = sorted(n for n, d in indeg.items() if d == 0)
    order = []
    while ready:
        n = ready.pop(0)
        order.append(n)
        for c in children.get(n, []):
            indeg[c] -= 1
            if indeg[c] == 0:
                ready.append(c)
        ready.sort()
    if len(order) != len(graph):
        # döngü izini bul
        remaining = [n for n in graph if n not in order]
        path = _find_cycle(graph, set(remaining))
        return order, path or remaining
    return order, None


def _find_cycle(graph, nodes, start=None):
    WHITE, GREY, BLACK = 0, 1, 2
    color = {n: WHITE for n in nodes}
    stack = []

    def dfs(n):
        color[n] = GREY
        stack.append(n)
        for d in graph.get(n, []):
            if d not in color:
                continue
            if color[d] == GREY:
                return stack[stack.index(d):] + [d]
            if color[d] == WHITE:
                res = dfs(d)
                if res:
                    return res
        color[n] = BLACK
        stack.pop()
        return None

    for n in list(nodes):
        if color[n] == WHITE:
            res = dfs(n)
            if res:
                return res
    return None


# ---------------------------------------------------------------------- costs
def check_costs(rep: Validator, buildings, max_level, rules):
    rep.sec("costs.json")
    costs = rules["costs"]
    groups = costs.get("growth_factor_groups", {})
    bgroup = costs.get("building_group", {})
    base1 = costs.get("base_level1_cost", {})
    tol_abs = float(costs.get("validation", {}).get("abs_tolerance", 0))
    tol_rel = float(costs.get("validation", {}).get("rel_tolerance", 0))

    rep.expect(costs.get("rounding") == "round_half_up", "rounding = round_half_up")
    rep.expect(isinstance(costs.get("formula"), str) and costs["formula"],
               "Maliyet formülü tanımlı")
    rep.expect(set(bgroup) == set(max_level), "building_group tüm binaları kapsıyor",
               "eksik/fazla: %s" % ((set(bgroup) ^ set(max_level)) or "yok"))
    rep.expect(set(bgroup.values()) <= set(groups), "building_group yalnızca tanımlı grup kullanıyor")
    for gname, g in groups.items():
        rep.expect(set(g) == set(RESOURCES), "Grup '%s' 3 kaynağı içeriyor" % gname)

    # seviye-1 temel maliyetler birebir
    base_bad = []
    for k, b in buildings.items():
        lv1 = b["levels"][0]
        for r in RESOURCES:
            if int(base1.get(k, {}).get(r, -1)) != int(lv1[r]):
                base_bad.append("%s/%s: %s != %s" % (k, r, base1.get(k, {}).get(r), lv1[r]))
    rep.expect(not base_bad, "base_level1_cost data ile birebir", "; ".join(base_bad))

    # faktörler tabloları üretiyor mu + monotonluk
    max_abs_err = 0
    max_rel_err = 0.0
    worst = ""
    non_mono = []
    violations = []
    for k, b in buildings.items():
        g = groups.get(bgroup.get(k), {})
        levels = b["levels"]
        for r in RESOURCES:
            base = int(levels[0][r])
            factor = g.get(r)
            if factor is None:
                rep.fail("%s/%s için faktör yok" % (k, r))
                continue
            # monotonluk (data)
            seq = [int(lv[r]) for lv in levels]
            for i in range(1, len(seq)):
                if seq[i] < seq[i - 1]:
                    non_mono.append("%s/%s lv%d->%d azalıyor" % (k, r, i, i + 1))
            if len(seq) > 1 and seq[0] > 0:
                # faktör üretimi
                bad_levels = []
                for lv in levels:
                    actual = int(lv[r])
                    comp = round_half_up(base * (factor ** (int(lv["level"]) - 1)))
                    abs_err = abs(comp - actual)
                    rel_err = abs_err / max(1, actual)
                    if abs_err > max_abs_err:
                        max_abs_err = abs_err
                        worst = "%s/%s Lv%s: %s != %s" % (k, r, lv["level"], actual, comp)
                    max_rel_err = max(max_rel_err, rel_err)
                    limit = max(tol_abs, tol_rel * actual)
                    if abs_err > limit:
                        bad_levels.append("Lv%s gerçek=%s hesap=%s (hata %s > tolerans %s)"
                                          % (lv["level"], actual, comp, abs_err, round(limit, 2)))
                if bad_levels:
                    shown = "; ".join(bad_levels[:3])
                    if len(bad_levels) > 3:
                        shown += "; ... (+%d seviye daha)" % (len(bad_levels) - 3)
                    violations.append("%s/%s: %s" % (k, r, shown))
    rep.expect(not non_mono, "Bina maliyet tabloları monoton artıyor", "; ".join(non_mono))
    rep.expect(not violations, "Büyüme faktörleri maliyet tablolarını toleransla üretiyor",
               " | ".join(violations))
    rep.ok("Büyüme faktörü üretimi özeti",
           "maks mutlak hata=%s, maks bağıl hata=%.4f%% %s"
           % (max_abs_err, max_rel_err * 100, ("(%s)" % worst) if worst else ""))


# ----------------------------------------------------------------- production
def check_production(rep: Validator, buildings, max_level, rules):
    rep.sec("production.json")
    prod = rules["production"]
    curves = prod.get("curves", {})
    tables = prod.get("tables", {})
    rep.expect(prod.get("rounding") == "round_half_up", "rounding = round_half_up")
    _check_assumptions(rep, prod.get("unresolved", {}), "production.json")

    for cname, c in curves.items():
        src = c.get("source_building")
        if src not in buildings:
            rep.fail("Eğri '%s' geçersiz source_building" % cname, str(src))
            continue
        data_vals = [int(parse_num(lv["lastColumn"])) for lv in buildings[src]["levels"]]
        vals = c.get("values", [])
        rep.expect(vals == data_vals,
                   "Eğri '%s' (%s) data ile birebir" % (cname, src),
                   "ilk fark: %s" % _first_diff(vals, data_vals))
        rep.expect(len(vals) == max_level[src] and c.get("level_max") == max_level[src],
                   "Eğri '%s' seviye aralığı doğru" % cname)
        rep.expect(_is_monotonic(vals), "Eğri '%s' monoton artıyor" % cname)

        base = c.get("base")
        factor = c.get("growth_factor")
        tol = float(c.get("tolerance_rel", 0.0))
        if base and factor:
            worst = 0.0
            for i, actual in enumerate(vals):
                if actual == 0:
                    continue
                comp = round_half_up(base * (factor ** i))
                rel = abs(comp - actual) / max(1, actual)
                worst = max(worst, rel)
            rep.expect(worst <= tol + 1e-12,
                       "Formül '%s' tabloyu toleransla üretiyor" % cname,
                       "maks bağıl hata=%.4f%% (tolerans %.2f%%)" % (worst * 100, tol * 100))
        else:
            rep.warn("Eğri '%s' için base/growth_factor eksik" % cname)

    # sur bonusu
    wall = tables.get("wall_defence_bonus_percent", {})
    if wall.get("source_building") == "wall":
        data_vals = [int(parse_num(lv["lastColumn"])) for lv in buildings["wall"]["levels"]]
        vals = wall.get("values_percent", [])
        rep.expect(vals == [100] + data_vals,
                   "Sur bonusu tablosu data ile birebir (indeks 0 = sur yok)",
                   "ilk fark: %s" % _first_diff(vals, [100] + data_vals))
        rep.expect(_is_monotonic(vals), "Sur bonusu monoton artıyor")
        rep.expect(vals and vals[0] == 100 and vals[-1] == 220,
                   "Sur bonusu %100 -> %220", "%s -> %s" % (vals[:1], vals[-1:]))
    else:
        rep.fail("wall_defence_bonus_percent.source_building eksik/yanlış")

    # market katır tablosu
    market = tables.get("market_donkey_capacity", {})
    if market.get("source_building") == "market":
        data_vals = [int(parse_num(lv["lastColumn"])) for lv in buildings["market"]["levels"]]
        vals = market.get("values", [])
        rep.expect(vals == data_vals,
                   "Market katır tablosu data ile birebir",
                   "ilk fark: %s" % _first_diff(vals, data_vals))
        rep.expect(_is_monotonic(vals), "Market katır kapasitesi monoton artıyor")
        rep.expect(vals and vals[0] == 1 and vals[-1] == 600,
                   "Market katır kapasitesi 1 -> 600", "%s -> %s" % (vals[:1], vals[-1:]))
    else:
        rep.fail("market_donkey_capacity.source_building eksik/yanlış")


# --------------------------------------------------------------- time factors
def check_time_factors(rep: Validator, buildings, max_level, rules):
    rep.sec("time-factors.json")
    tf = rules["time_factors"]
    cols = tf.get("time_factor_column", {})

    for key, c in cols.items():
        src = c.get("source_building", key)
        if src not in buildings:
            rep.fail("Zaman faktörü '%s' geçersiz source_building" % key, str(src))
            continue
        data_vals = [int(parse_num(lv["lastColumn"])) for lv in buildings[src]["levels"]]
        vals = c.get("values_percent", [])
        rep.expect(vals == data_vals,
                   "Zaman faktörü '%s' data ile birebir" % key,
                   "ilk fark: %s" % _first_diff(vals, data_vals))
        rep.expect(len(vals) == max_level[src],
                   "Zaman faktörü '%s' uzunluğu doğru" % key)
        if not c.get("known", True):
            rep.expect(bool(c.get("assumption")),
                       "Zaman faktörü '%s' known=false -> assumption var" % key)
        elif _is_monotonic(vals, non_increasing=True) is False and any(vals):
            rep.warn("Zaman faktörü '%s' azalmıyor" % key,
                     "kaynak seri beklenmedik")

    queue = tf.get("build_queue_extra_cost", {})
    rep.expect(queue.get("values_percent") == EXPECTED_QUEUE_PERCENT,
               "İnşaat kuyruğu ek maliyeti doğru",
               str(queue.get("values_percent")))
    rep.expect(queue.get("free_jobs") == 3, "Kuyrukta 3 iş ücretsiz")
    rep.expect(len(queue.get("values_percent", [])) == 10, "Kuyruk tablosu 10 iş içeriyor")

    # known:false -> assumption (tüm dosya)
    _check_assumptions(rep, tf, "time-factors.json")


# --------------------------------------------------------------------- battle
def check_battle(rep: Validator, rules):
    rep.sec("battle.json")
    bt = rules["battle"]

    morale = bt.get("morale", {})
    rep.expect(0 <= morale.get("min", 2) < morale.get("max", -1) <= 1,
               "Moral aralığı %30-%100",
               "%s - %s" % (morale.get("min"), morale.get("max")))
    rep.expect(abs(morale.get("min", 1) - 0.30) < 1e-9 and abs(morale.get("max", 0) - 1.0) < 1e-9,
               "Moral min=0.30 max=1.00")

    luck = bt.get("luck", {})
    rep.expect(abs(luck.get("min", 0) + luck.get("max", 1)) < 1e-9,
               "Şans simetrik ±%25",
               "%s / %s" % (luck.get("min"), luck.get("max")))
    rep.expect(abs(luck.get("max", 0) - 0.25) < 1e-9, "Şans sınırı %25")

    rep.expect(abs(bt.get("night_bonus", {}).get("multiplier", 0) - 2.0) < 1e-9,
               "Gece bonusu ×2")
    rep.expect(abs(bt.get("memorial", {}).get("fortification_bonus", 0) - 0.50) < 1e-9,
               "Anıt tahkimat bonusu +%50")
    rep.expect(bt.get("min_attack_units", {}).get("barracks_factor") == 3,
               "Min. saldırı birimi = 3 × Kışla")

    ap = bt.get("attack_protection", {})
    rep.expect(ap.get("new_player_attack_protection_days") == 5, "Yeni oyuncu koruması 5 gün")
    rep.expect(ap.get("conquest_protection_days") == 7, "Fetih koruması 7 gün")
    rep.expect(abs(ap.get("max_ratio_attacker_defender", 0) - 10.0) < 1e-9, "Maks. oran 10:1")
    rep.expect(ap.get("outlawed_penalty_days") == 60, "Kanun kaçağı cezası 60 gün")

    cancel = bt.get("cancellation", {})
    rep.expect(cancel.get("attack_cancel_minutes") == 30, "Saldırı iptali 30 dk")
    rep.expect(cancel.get("donkey_cancel_minutes") == 15, "Katır iptali 15 dk")

    rop = bt.get("realm_of_power", {})
    n_loss = rop.get("loss_foreign_count", {})
    m_loss = rop.get("loss_foreign_count_memorial", {})
    rep.expect(n_loss.get("min") == 2250 and n_loss.get("max") == 2750,
               "Yabancı Kont düşüşü 2250-2750", str(n_loss))
    rep.expect(m_loss.get("min") == 1750 and m_loss.get("max") == 2250,
               "Anıtlı Kont düşüşü 1750-2250", str(m_loss))
    rep.expect(m_loss.get("min", 0) < n_loss.get("min", 0),
               "Anıt düşüşü daha düşük")
    rep.expect(abs(rop.get("hourly_increase_percent", 0) - 1.0) < 1e-9,
               "Güç alanı saatlik artışı %1")
    rep.expect(rop.get("effective_counts_per_attack") == 1, "Saldırı başına 1 Kont etkili")

    cnt = bt.get("count", {})
    rep.expect(cnt.get("max_distance_fields", {}).get("en") == 100, "Kont mesafesi EN = 100")
    rep.expect(cnt.get("max_distance_fields", {}).get("tr") == 80, "Kont mesafesi TR = 80")
    rep.expect(cnt.get("researched") is False, "Kont araştırılmaz")
    rep.expect(cnt.get("training_building") == "snob", "Kont Köşk'te eğitilir")
    rep.expect(cnt.get("requires_gold_armor") is True, "Kont Altın Zırh ister")

    phases = bt.get("phases", [])
    rep.expect(len(phases) == 5, "5 savaş fazı tanımlı", "bulunan: %d" % len(phases))
    rep.expect([p.get("order") for p in phases] == [1, 2, 3, 4, 5],
               "Faz sırası 1..5")
    rep.expect(len({p.get("key") for p in phases}) == len(phases), "Faz anahtarları tekil")
    rep.expect(all(p.get("name_tr") for p in phases), "Her fazın Türkçe adı var")

    cfg = bt.get("config_defaults", {})
    rep.expect(cfg.get("count_max_distance_fields") == cnt.get("max_distance_fields"),
               "config_defaults Kont mesafesi ile tutarlı")

    _check_assumptions(rep, bt, "battle.json")


# ---------------------------------------------------------------------- units
def check_units(rep: Validator, buildings, max_level, rules, units_data):
    rep.sec("units.json")
    ru = rules["units"]
    data_units = {u["key"]: u for u in units_data["units"]}
    data_research = {r["key"]: r for r in units_data["research"]}
    data_training = {t["key"]: t for t in units_data["training"]}
    data_combat = {c["key"]: c for c in units_data["combat"]}
    entries = {u["key"]: u for u in ru.get("units", [])}

    rep.expect(ru.get("research_requirements_barracks") == EXPECTED_BARRACKS_LEVELS,
               "research_requirements_barracks doğru",
               str(ru.get("research_requirements_barracks")))
    rep.expect(sorted(ru.get("not_researched_units", [])) == EXPECTED_NOT_RESEARCHED,
               "not_researched_units = ['snob']")
    rep.expect(set(entries) == set(data_units),
               "units[] tüm birimleri içeriyor",
               "eksik/fazla: %s" % ((set(entries) ^ set(data_units)) or "yok"))
    rep.expect(set(ru.get("unit_keys", [])) == set(data_units), "unit_keys data ile aynı")

    # sınıf bölüntüsü
    classes = ru.get("classes", {})
    flat = [k for vs in classes.values() for k in vs]
    rep.expect(sorted(flat) == sorted(set(flat)), "Sınıflarda tekrar yok")
    rep.expect(set(flat) == set(data_units), "Sınıflar birimleri tam bölüyor",
               "fark: %s" % (set(flat) ^ set(data_units)))

    # Kışla referansı
    rep.expect(ru.get("research_building") == "barracks", "research_building = barracks")
    rep.expect("barracks" in max_level, "Kışla anahtarı data'da var")

    bad = []
    for key, e in entries.items():
        du = data_units.get(key)
        if du is None:
            continue
        # temel istatistikler
        if e.get("cost") != {"wood": int(du["costWood"]), "stone": int(du["costStone"]),
                             "iron": int(du["costIron"])}:
            bad.append("%s maliyet" % key)
        if int(e.get("settlers", -1)) != int(du["settlers"]):
            bad.append("%s vatandaş" % key)
        if int(e.get("carry_capacity", -1)) != int(du["carryBooty"]):
            bad.append("%s taşıma" % key)
        dc = data_combat.get(key, {})
        ec = e.get("combat", {})
        if (int(ec.get("attack", -1)) != int(dc.get("attack", -2))
                or int(ec.get("defence_infantry", -1)) != int(dc.get("defenceInf", -2))
                or int(ec.get("defence_cavalry", -1)) != int(dc.get("defenceCav", -2))
                or int(ec.get("defence_archer", -1)) != int(dc.get("defenceArch", -2))):
            bad.append("%s muharebe" % key)
        # araştırma
        res = e.get("research", {})
        if key == "snob":
            if res.get("required") is not False or e.get("training", {}).get("building") != "snob":
                bad.append("%s (snob) araştırma/eğitim" % key)
            if e.get("training", {}).get("requires_gold_armor") is not True:
                bad.append("%s Altın Zırh bayrağı" % key)
        else:
            exp_lv = EXPECTED_BARRACKS_LEVELS.get(key)
            if res.get("required") is not True:
                bad.append("%s research.required" % key)
            if res.get("building") != "barracks":
                bad.append("%s research.building" % key)
            if int(res.get("level", -1)) != exp_lv:
                bad.append("%s research.level=%s (!=%s)" % (key, res.get("level"), exp_lv))
            if exp_lv is not None and exp_lv > max_level.get("barracks", 0):
                bad.append("%s Kışla Lv%s > maks" % (key, exp_lv))
            if res.get("cost") is None:
                bad.append("%s research.cost yok" % key)
        # temel süreler
        dr = data_research.get(key)
        if dr is not None and res.get("base_time_seconds") is not None:
            if int(res["base_time_seconds"]) != _hms(dr["time"]):
                bad.append("%s araştırma süresi" % key)
        dt = data_training.get(key)
        if dt is not None:
            tr = e.get("training", {})
            if int(tr.get("base_time_seconds", -1)) != _hms(dt["time"]):
                bad.append("%s eğitim süresi" % key)
            if (int(tr.get("cost", {}).get("wood", -1)) != int(dt["wood"])
                    or int(tr.get("cost", {}).get("stone", -1)) != int(dt["stone"])
                    or int(tr.get("cost", {}).get("iron", -1)) != int(dt["iron"])):
                bad.append("%s eğitim maliyeti" % key)
    rep.expect(not bad, "Birim maliyet/istatistik/süreleri data ile birebir", "; ".join(bad))

    # süreler > 0
    bad_time = []
    for key, e in entries.items():
        tr = e.get("training", {})
        if not (isinstance(tr.get("base_time_seconds"), (int, float))
                and int(tr["base_time_seconds"]) > 0):
            bad_time.append("%s eğitim" % key)
        res = e.get("research", {})
        if res.get("required") is True and not (
                isinstance(res.get("base_time_seconds"), (int, float))
                and int(res["base_time_seconds"]) > 0):
            bad_time.append("%s araştırma" % key)
    rep.expect(not bad_time, "Eğitim/araştırma temel süreleri pozitif", "; ".join(bad_time))

    _check_assumptions(rep, ru, "units.json")


# ------------------------------------------------------------------ yardımcılar
def _hms(text: str) -> int:
    h, m, s = (int(x) for x in str(text).split(":"))
    return h * 3600 + m * 60 + s


def _is_monotonic(seq, non_increasing: bool = False) -> bool:
    if non_increasing:
        return all(seq[i] <= seq[i - 1] for i in range(1, len(seq)))
    return all(seq[i] >= seq[i - 1] for i in range(1, len(seq)))


def _first_diff(a, b):
    for i in range(max(len(a), len(b))):
        x = a[i] if i < len(a) else "<yok>"
        y = b[i] if i < len(b) else "<yok>"
        if x != y:
            return "indeks %d: %s != %s" % (i, x, y)
    return "yok"


def _check_assumptions(rep: Validator, node, path: str) -> None:
    """known:false olan her düğümün assumption'ı olmalı (özyinelemeli)."""
    if isinstance(node, dict):
        if node.get("known") is False:
            if not node.get("assumption"):
                rep.fail("%s: known=false ama assumption yok" % path)
        for k, v in node.items():
            _check_assumptions(rep, v, "%s.%s" % (path, k))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            _check_assumptions(rep, v, "%s[%d]" % (path, i))


# ------------------------------------------------------------------------ main
def main() -> int:
    _setup_console()
    rep = Validator()

    print("=" * 72)
    print("Taht ve Kılıç — Kural Doğrulayıcı (A-KURAL / T-3.7)")
    print("Kök: %s" % ROOT)
    print("=" * 72)

    loaded = load_all(rep)
    if loaded is None:
        _print_report(rep)
        return 1
    buildings, max_level, name_tr, rules, units_data = loaded

    # şema sürümü tutarlılığı
    rep.sec("Genel")
    versions = {k: v.get("schema_version") for k, v in rules.items()}
    rep.expect(len(set(versions.values())) == 1,
               "schema_version tüm kural dosyalarında aynı", str(versions))

    check_requirements(rep, buildings, max_level, name_tr, rules)
    check_costs(rep, buildings, max_level, rules)
    check_production(rep, buildings, max_level, rules)
    check_time_factors(rep, buildings, max_level, rules)
    check_battle(rep, rules)
    check_units(rep, buildings, max_level, rules, units_data)

    # çapraz dosya: requirements.unit_research == units.json
    rep.sec("Çapraz kontrol")
    req_levels = rules["requirements"].get("unit_research", {}).get("barracks_levels", {})
    unit_levels = rules["units"].get("research_requirements_barracks", {})
    same = req_levels == unit_levels
    rep.expect(same,
               "requirements.unit_research = units.research_requirements_barracks",
               "" if same else "%s != %s" % (req_levels, unit_levels))
    bmax = max_level.get("barracks", 0)
    rep.expect(all(v <= bmax for v in unit_levels.values()),
               "Tüm birim araştırma seviyeleri <= Kışla maks (%s)" % bmax)

    _print_report(rep)
    return 0 if rep.errors == 0 else 1


def _print_report(rep: Validator) -> None:
    print()
    current = None
    for section, good, label, detail in rep.results:
        if section != current:
            current = section
            print("\n[%s]" % section)
        mark = "OK  " if good else "FAIL"
        line = "  %s %s" % (mark, label)
        if detail:
            line += "  —  %s" % detail
        print(line)

    if rep.warnings:
        print("\n[Uyarılar]")
        for section, text in rep.warnings:
            print("  !  (%s) %s" % (section, text))

    total = len(rep.results)
    failed = [r for r in rep.results if not r[1]]
    print("\n" + "=" * 72)
    print("Kontrol: %d   Başarılı: %d   Başarısız: %d" % (total, total - len(failed), len(failed)))
    if failed:
        print("SONUÇ: BAŞARISIZ")
        for section, _, label, detail in failed:
            print("  - [%s] %s %s" % (section, label, ("— " + detail) if detail else ""))
    else:
        print("SONUÇ: BAŞARILI (exit 0)")
    print("=" * 72)


if __name__ == "__main__":
    sys.exit(main())
