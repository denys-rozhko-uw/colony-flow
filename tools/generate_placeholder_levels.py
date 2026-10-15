"""Regenerate the deterministic placeholder campaign (levels 002–020).

The first level is authored separately. All generated art is original color blocks.
Run from the repository root with: python tools/generate_placeholder_levels.py
"""

import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "data" / "levels"
COLORS = [
    ("rose", "#E85A5A", "●"),
    ("gold", "#E7B453", "◆"),
    ("leaf", "#65BE78", "■"),
    ("sky", "#4F8FE8", "▲"),
    ("violet", "#AD7EE8", "★"),
    ("coral", "#EB8963", "⬟"),
    ("cyan", "#57CAD2", "✦"),
    ("mint", "#92D7AD", "◈"),
]


def row_colors(index: int, height: int) -> list[list[str]]:
    color_cursor = 0
    rows_from_bottom: list[list[str]] = []
    for row_index in range(height):
        if row_index == 0:
            count = 1
        elif index == 4:
            count = 5
        elif index == 5 and row_index == 2:
            count = 3
        elif index < 7:
            count = 1 if row_index % 2 == 0 else 2
        else:
            count = 2 if color_cursor < 6 and row_index % 2 == 1 else 1
        count = min(count, 8 - color_cursor)
        names = [COLORS[(index + color_cursor + step) % len(COLORS)][0] for step in range(count)]
        color_cursor += count
        rows_from_bottom.append(names)
    return rows_from_bottom


def make_level(index: int) -> dict:
    if index == 2:
        width, height = 3, 2
    elif index == 3:
        width, height = 4, 3
    elif index == 4:
        width, height = 5, 2
    elif index == 5:
        width, height = 6, 3
    else:
        width, height = 5 + (index % 4), min(5, 2 + (index - 4) // 4)
    bands = row_colors(index, height)
    rows_from_bottom = []
    for band_index, names in enumerate(bands):
        if len(names) == 1:
            row = [names[0]] * width
        elif index == 4:
            row = names[:]
        else:
            offset = (index + band_index) % len(names)
            row = [names[(x + offset) % len(names)] for x in range(width)]
        if index >= 6 and band_index == height - 1:
            edge = 1 if len(names) > 1 or index % 3 != 0 else min(2, width // 4)
            for x in range(edge):
                row[x] = None
                row[width - x - 1] = None
        elif index >= 12 and height >= 4 and band_index == height - 2 and index % 2 == 1:
            row[0] = None
        rows_from_bottom.append(row)
    cells = list(reversed(rows_from_bottom))
    counts = Counter(cell for row in cells for cell in row if cell is not None)
    palette = {name: {"hex": hex_color, "symbol": symbol} for name, hex_color, symbol in COLORS if name in counts}
    boxes = []
    order = []
    first_box_id_by_color = {}
    for band_index, names in enumerate(bands):
        for name in names:
            if counts[name] == 0:
                continue
            predecessor = []
            if index in (2, 3) and band_index > 0:
                predecessor = [first_box_id_by_color[bands[band_index - 1][0]]]
            elif index >= 10 and band_index > 0 and band_index % 2 == 0:
                predecessor = [first_box_id_by_color[bands[band_index - 1][0]]]
            split = index in (8, 12, 16, 20) and band_index == 1 and counts[name] >= 2
            parts = [("b_" + name, counts[name])]
            if split:
                parts = [("b_" + name + "_a", counts[name] // 2), ("b_" + name + "_b", counts[name] - counts[name] // 2)]
            for box_id, quota in parts:
                boxes.append({
                    "id": box_id,
                    "color_id": name,
                    "quota": quota,
                    "blocked_by": predecessor,
                    "ui_column": len(boxes) % 4,
                    "ui_row": len(boxes) // 4,
                })
                order.append(box_id)
            first_box_id_by_color[name] = parts[0][0]
    return {
        "schema_version": 1,
        "ruleset_id": "frontier_v1",
        "id": f"level_{index:03}",
        "revision": 1,
        "title": f"Цветной маршрут {index}",
        "width": width,
        "height": height,
        "slot_count": 5,
        "palette": palette,
        "cells": cells,
        "boxes": boxes,
        "solution_order": order,
        "tutorial_id": "first_steps" if index <= 3 else None,
    }


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    manifest = [{"id": "level_001", "path": "res://data/levels/level_001.json"}]
    for index in range(2, 21):
        level = make_level(index)
        path = ROOT / f"level_{index:03}.json"
        path.write_text(json.dumps(level, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        manifest.append({"id": level["id"], "path": "res://data/levels/" + path.name})
    (ROOT / "manifest.json").write_text(json.dumps({"schema_version": 1, "levels": manifest}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
