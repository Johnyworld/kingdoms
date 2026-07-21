extends GutTest
## 타일 보기 배선 검증(런타임 열거 방식): 타일셋 로드·게임 지형 PAINT 레이어 매핑·건물 타입.
## 실제 스와치/스프라이트 렌더는 육안 확인.

const GALLERY := preload("res://scenes/tile_gallery/tile_gallery.gd")

func test_all_tilesets_load_and_have_terrains() -> void:
	assert_gt(GALLERY.ALL_TILESETS.size(), 0, "열거할 타일셋이 있다")
	for n in GALLERY.ALL_TILESETS:
		var ts: TileSet = load(GALLERY.TS_DIR + n + ".tres")
		assert_not_null(ts, "타일셋 로드: %s" % n)
		if ts != null:
			assert_gt(ts.get_terrain_sets_count(), 0, "%s에 terrain_set 있음" % n)

func test_game_terrain_paint_keys_are_mapped() -> void:
	# 게임 지형이 쓰는 모든 PAINT 레이어 키가 타일셋에 매핑돼야 그려진다.
	for t in GALLERY.GAME_TERRAINS:
		assert_true(TerrainRenderer.PAINT.has(t), "게임 지형 PAINT 정의: %d" % t)
		for op in TerrainRenderer.PAINT[t]:
			assert_true(GALLERY.PAINT_KEY_TS.has(op[0]), "PAINT 키 매핑됨: %s" % op[0])

func test_paint_key_tilesets_are_enumerated() -> void:
	for key in GALLERY.PAINT_KEY_TS:
		assert_true(GALLERY.PAINT_KEY_TS[key] in GALLERY.ALL_TILESETS, "매핑 타일셋이 열거 목록에: %s" % key)

func test_game_buildings_valid() -> void:
	for b in GALLERY.GAME_BUILDINGS:
		assert_true(BuildingRenderer.terrain_index(b, "푸른 왕국") >= 0, "건물 타입 유효: %s" % b)

func test_sprite_folders_listed() -> void:
	# 스프라이트 폴더 중 최소 하나는 png를 갖는다(반입 확인).
	var found := 0
	for folder in GALLERY.SPRITE_FOLDERS:
		var d := DirAccess.open(GALLERY.SPRITE_ROOT + folder)
		if d != null:
			for f in d.get_files():
				if f.ends_with(".png"):
					found += 1
	assert_gt(found, 0, "스프라이트 png가 반입돼 열거됨")
