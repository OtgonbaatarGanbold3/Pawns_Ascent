extends RefCounted
class_name PawnUITheme

static func make_panel_style(bg_color: Color, border_color: Color, content_margin: int = 12, radius: int = 6, border_width: int = 2) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_content_margin_all(content_margin)
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    return style
