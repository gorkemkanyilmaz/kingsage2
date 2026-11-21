import subprocess
import sys
import os

tests = [
    "test_all_scenes.gd",
    "test_village_ui_flow.gd",
    "test_village_pan_zoom.gd",
    "test_building_upgrades.gd",
    "test_player_agent.gd",
    "test_settings_nav.gd",
    "test_save.gd",
    "test_rules.gd",
    "test_economy.gd",
    "test_army.gd",
    "test_battle.gd",
    "test_bot.gd",
    "test_actions.gd",
    "test_integration.gd",
    "test_world.gd",
    "test_tutorial.gd",
    "test_quest_system.gd",
    "test_three_players_full_playthrough.gd",
    "test_two_players_conquest_100x.gd",
    "test_village_isolation_and_restart.gd",
    "test_v3_parity_fixes.gd",
    "test_store_and_speedups.gd",
    "test_reports_and_persistence.gd"
]

godot = os.path.abspath(r"tools/godot/Godot_v4.7.2-stable_win64_console.exe")
failed = []

print(f"=== RUNNING ALL {len(tests)} GODOT TEST SUITES ===")

for t in tests:
    # Ensure test save file from previous run is cleaned up
    save_file = os.path.expanduser(r"~\AppData\Roaming\Godot\app_userdata\Taht ve Kılıç\taht_ve_kilic_save.json")
    if os.path.exists(save_file):
        try:
            os.remove(save_file)
        except Exception:
            pass

    cmd = [godot, "--headless", "--path", "./game", "-s", f"tests/{t}"]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode == 0:
        print(f"  [PASS] {t}")
    else:
        out = p.stdout.decode("utf-8", errors="replace")
        err = p.stderr.decode("utf-8", errors="replace")
        print(f"  [FAIL] {t} (exit code: {p.returncode})")
        print(out[-400:])
        print(err[-400:])
        failed.append(t)

print("\n" + "=" * 50)
if not failed:
    print(f"  SONUÇ: {len(tests)} / {len(tests)} TEST PAKETİ EKSİKSİZ BAŞARILI (PASS)!")
    print("=" * 50)
    sys.exit(0)
else:
    print(f"  SONUÇ: {len(failed)} TEST BAŞARISIZ: {failed}")
    print("=" * 50)
    sys.exit(1)
