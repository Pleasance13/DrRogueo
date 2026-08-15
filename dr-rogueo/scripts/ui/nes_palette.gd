@tool
class_name NESPalette
extends RefCounted


# Dr. Rogueo palette
const COLORS: Array[Color] = [
	# Row 1
	Color("#6A6D6A"),
	Color("#002A88"),
	Color("#1E008A"),
	Color("#39007A"),
	Color("#550056"),
	Color("#6E0040"),
	Color("#4F1000"),
	Color("#3D1C00"),
	Color("#253200"),
	Color("#003D00"),
	Color("#004000"),
	Color("#003924"),
	Color("#002E55"),
	Color("#000000"),

	# Row 2
	Color("#B9BCB9"),
	Color("#1850C7"),
	Color("#4B30E3"),
	Color("#7322D6"),
	Color("#951FA9"),
	Color("#9D285C"),
	Color("#983700"),
	Color("#7F4C00"),
	Color("#5E6400"),
	Color("#227700"),
	Color("#027E02"),
	Color("#007645"),
	Color("#006E8A"),
	Color("#000000"),

	# Row 3
	Color("#FFFFFF"),
	Color("#60A0FF"),
	Color("#8C9CFF"),
	Color("#B586FF"),
	Color("#D975FD"),
	Color("#D84060"),
	Color("#E58D68"),
	Color("#D49D29"),
	Color("#E8d020"),
	Color("#7BC211"),
	Color("#55CA47"),
	Color("#46CB81"),
	Color("#47C1C5"),
	Color("#4A4D4A"),

	# Row 4
	Color("#FFFFFF"),
	Color("#CCEAFF"),
	Color("#DDDEFF"),
	Color("#ECDAFF"),
	Color("#F8D7FE"),
	Color("#FCD6F5"),
	Color("#FDDBCF"),
	Color("#F9E7B5"),
	Color("#F1F0AA"),
	Color("#DAFAA9"),
	Color("#C9FFBC"),
	Color("#C3FBD7"),
	Color("#C4F6F6"),
	Color("#BEC1BE"),
]


static func nearest_color(color: Color) -> Color:
	var best_color := COLORS[0]
	var best_distance := INF

	for palette_color in COLORS:
		var distance := color_distance(color, palette_color)

		if distance < best_distance:
			best_distance = distance
			best_color = palette_color

	return best_color


static func color_distance(a: Color, b: Color) -> float:
	var difference := a - b

	return (
		difference.r * difference.r +
		difference.g * difference.g +
		difference.b * difference.b
	)
