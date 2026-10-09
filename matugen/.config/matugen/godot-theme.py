#!/usr/bin/env python3
"""Generates a Godot text editor theme (.tet) from matugen colors."""

import re
import os

colors_file = os.path.expanduser("~/.config/nvim/lua/config/matugen_colors.lua")
colors = {}

with open(colors_file) as f:
    for line in f:
        m = re.match(r'\s+(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', line)
        if m:
            name, h = m.groups()
            colors[name] = (int(h[1:3], 16) / 255, int(h[3:5], 16) / 255, int(h[5:7], 16) / 255)


def member(name, color_key, alpha=1.0):
    r, g, b = colors[color_key]
    return (
        f"[member {name}]\n"
        f"r = {r:.6f}\n"
        f"g = {g:.6f}\n"
        f"b = {b:.6f}\n"
        f"a = {alpha:.6f}"
    )


theme = "\n\n".join([
    "[color_regions]",
    member("background_color",          "surface"),
    member("font_color",                "on_surface"),
    member("caret_color",               "on_surface"),
    member("caret_background_color",    "surface"),
    member("line_number_color",         "outline"),
    member("safe_line_number_color",    "primary"),
    member("code_folding_color",        "outline"),
    member("fold_marker_color",         "outline"),
    member("current_line_color",        "surface_variant", 0.3),
    member("selection_color",           "surface_variant", 0.5),
    member("word_highlighted_color",    "primary_container", 0.4),
    member("search_result_color",       "primary_container", 0.5),
    member("search_result_border_color","primary"),
    member("brace_mismatch_color",      "error"),
    member("mark_color",                "error_container", 0.3),
    member("breakpoint_color",          "error"),
    member("executing_line_color",      "tertiary"),
    member("bookmark_color",            "secondary"),
    member("completion_background_color","surface_variant"),
    member("completion_selected_color", "primary_container", 0.7),
    member("completion_existing_color", "primary", 0.3),
    member("completion_font_color",     "on_surface"),
    member("symbol_color",              "on_primary_container"),
    member("keyword_color",             "primary"),
    member("control_flow_keyword_color","primary"),
    member("base_type_color",           "tertiary"),
    member("engine_type_color",         "tertiary"),
    member("user_type_color",           "secondary"),
    member("comment_color",             "on_surface_variant"),
    member("doc_comment_color",         "on_surface_variant"),
    member("comment_markers_color",     "outline"),
    member("string_color",              "secondary"),
    member("number_color",              "tertiary"),
    member("function_color",            "primary"),
    member("function_definition_color", "on_primary_container"),
    member("built_in_variable_color",   "tertiary"),
    member("member_variable_color",     "on_primary_container"),
])

output = os.path.expanduser(
    "~/.var/app/org.godotengine.Godot/config/godot/text_editor_themes/matugen.tet"
)
os.makedirs(os.path.dirname(output), exist_ok=True)

with open(output, "w") as f:
    f.write(theme + "\n")

print(f"Godot theme -> {output}")
