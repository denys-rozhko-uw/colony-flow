"""Regenerate content fixtures used by the Godot test runner."""

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tests" / "fixtures"
BASE = json.loads((ROOT / "data" / "levels" / "level_001.json").read_text(encoding="utf-8"))


def write(name: str, data: dict) -> None:
    (OUT / (name + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write("valid_2x2", BASE)
    holes = copy.deepcopy(BASE)
    holes.update(id="holes", width=3, cells=[[None, "blue", None], ["red", "red", "red"]])
    holes["boxes"][0]["quota"] = 3
    holes["boxes"][1]["quota"] = 1
    write("valid_holes", holes)
    split = copy.deepcopy(BASE)
    split["id"] = "split"
    split["boxes"][0]["quota"] = 1
    split["boxes"][1]["blocked_by"] = ["b_red", "b_red_2"]
    split["boxes"].insert(1, {"id": "b_red_2", "color_id": "red", "quota": 1, "blocked_by": [], "ui_column": 1, "ui_row": 0})
    split["solution_order"] = ["b_red", "b_red_2", "b_blue"]
    write("valid_split_color", split)
    branches = copy.deepcopy(BASE)
    branches.update(id="branches", width=3, height=3, cells=[["green"] * 3, ["blue"] * 3, ["red"] * 3])
    branches["palette"]["green"] = {"hex": "#65BE78", "symbol": "■"}
    branches["boxes"][0]["quota"] = 3
    branches["boxes"][1]["quota"] = 3
    branches["boxes"].append({"id": "b_green", "color_id": "green", "quota": 3, "blocked_by": ["b_red"], "ui_column": 2, "ui_row": 0})
    branches["solution_order"].append("b_green")
    write("valid_branches", branches)

    cases = {}
    case = copy.deepcopy(BASE); case["width"] = 2.5; cases["fractional_width"] = case
    case = copy.deepcopy(BASE); case["boxes"][0]["quota"] = 1.5; cases["fractional_quota"] = case
    case = copy.deepcopy(BASE); case["cells"][0][0] = "unknown"; cases["unknown_color"] = case
    case = copy.deepcopy(BASE); case["cells"][0].pop(); cases["wrong_width"] = case
    case = copy.deepcopy(BASE); case["cells"] = [[None, None], [None, None]]; cases["empty_board"] = case
    case = copy.deepcopy(BASE); case["typo_quota"] = 3; cases["extra_field"] = case
    case = copy.deepcopy(BASE); case["boxes"][1]["id"] = "b_red"; cases["duplicate_box"] = case
    case = copy.deepcopy(BASE); case["boxes"][1]["blocked_by"] = ["missing"]; cases["missing_reference"] = case
    case = copy.deepcopy(BASE); case["boxes"][0]["blocked_by"] = ["b_blue"]; cases["cycle"] = case
    case = copy.deepcopy(BASE); case["boxes"][0]["quota"] = 1; cases["quota_mismatch"] = case
    case = copy.deepcopy(BASE); case["schema_version"] = 9; cases["future_schema"] = case
    case = copy.deepcopy(BASE); case["ruleset_id"] = "unknown"; cases["wrong_ruleset"] = case
    case = copy.deepcopy(BASE); case["boxes"][1]["ui_column"] = 0; case["boxes"][1]["ui_row"] = 0; cases["duplicate_position"] = case
    for name, data in cases.items():
        write("invalid_" + name, data)
    (OUT / "invalid_json.txt").write_text("{broken", encoding="utf-8")


if __name__ == "__main__":
    main()
