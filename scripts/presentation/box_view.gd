class_name BoxView
extends Button

var box_id: String = ""

func configure(definition: BoxDefinition, palette: Dictionary, show_symbols: bool) -> void:
	box_id = definition.id
	var color: Color = Color.html(palette[definition.color_id].hex)
	var prefix: String = str(palette[definition.color_id].symbol) + " " if show_symbols else ""
	text = prefix + str(definition.quota)
	custom_minimum_size = Vector2(70, 48)
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_disabled_color", color.darkened(0.18))
	add_theme_stylebox_override("normal", _style(Color("#394b68")))
	add_theme_stylebox_override("hover", _style(Color("#4d6388")))
	add_theme_stylebox_override("pressed", _style(Color("#2f4059")))
	add_theme_stylebox_override("disabled", _style(Color("#283349")))

func _style(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	return style
