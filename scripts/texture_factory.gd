extends RefCounted
class_name TextureFactory

static var _cache: Dictionary = {}
static var _palette: Array[Color] = []

static func _ensure_palette() -> void:
	if not _palette.is_empty():
		return
	for i in range(70):
		var hue := float(i) / 70.0
		_palette.append(Color.from_hsv(hue, 0.28 + float(i % 5) * 0.09, 0.48 + float(i % 7) * 0.065))

static func _make_texture(family: int, style: int) -> Texture2D:
	var cache_key := "%d:%d" % [family, style]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var rng := RandomNumberGenerator.new()
	rng.seed = family * 7919 + style * 104729 + 31
	var base: Color = _palette[family]
	var accent := base.lightened(0.16 + float(style % 3) * 0.07)
	var dark := base.darkened(0.12 + float(style % 4) * 0.045)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var noise := rng.randf()
			var pixel := base
			match style % 5:
				0:
					if noise > 0.78: pixel = accent
					elif noise < 0.16: pixel = dark
				1:
					if (x + y + style) % 5 == 0: pixel = accent
					elif noise < 0.18: pixel = dark
				2:
					if x % 4 == style % 4 or y % 5 == style % 5: pixel = dark
					elif noise > 0.72: pixel = accent
				3:
					if (x * 3 + y * 7 + family) % 13 < 3: pixel = accent
					elif noise < 0.25: pixel = dark
				4:
					if noise > 0.84: pixel = accent
					elif noise < 0.30: pixel = dark
			image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture

static func get_texture(material_key: String, variant: int = 0) -> Texture2D:
	_ensure_palette()
	var family := abs(hash(material_key)) % 70
	return _make_texture(family, posmod(variant, 10))

static func preload_all() -> int:
	_ensure_palette()
	for family in range(70):
		for style in range(10):
			_make_texture(family, style)
	return _cache.size()
