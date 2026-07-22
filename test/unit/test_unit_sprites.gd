extends GutTest
## 맵 토큰 스프라이트 세트 매핑(UnitSprites.set_key) — 아키타입 → 스프라이트 세트 키.
## 순수 매핑(파일시스템 무관). idle SpriteFrames 캐시·AnimatedSprite2D 생성은 실행으로 확인.

const UnitSprites = preload("res://scenes/party/unit_sprites.gd")

func test_set_key_hero_is_sword() -> void:
	assert_eq(UnitSprites.set_key("hero"), "sword", "영웅 → sword 세트")

func test_set_key_light_infantry_is_soldier() -> void:
	assert_eq(UnitSprites.set_key("light_infantry"), "soldier", "경보병 → soldier 세트")

func test_set_key_light_archer_is_archer_a() -> void:
	assert_eq(UnitSprites.set_key("light_archer"), "archer_a", "경궁병 → archer_a 세트")

func test_set_key_empty_falls_back_to_soldier() -> void:
	assert_eq(UnitSprites.set_key(""), "soldier", "빈 아키타입은 근접 기본(soldier)으로 대체")

func test_set_key_unknown_falls_back_to_soldier() -> void:
	assert_eq(UnitSprites.set_key("dragon"), "soldier", "미지원 아키타입은 soldier로 대체")

# --- idle SpriteFrames (에셋 경로 회귀 방지) ---

func test_idle_frames_loads_six_frames() -> void:
	# 세트 idle 시트(soldier/archer_a/sword)가 실제로 로드되고 6프레임이 담기는지 — 에셋 경로 오타 방지.
	for arche in ["hero", "light_infantry", "light_archer"]:
		var sf: SpriteFrames = UnitSprites.idle_frames(arche)
		assert_eq(sf.get_frame_count("default"), UnitSprites.IDLE_COUNT,
			"%s idle → default 애니 %d프레임" % [arche, UnitSprites.IDLE_COUNT])
		assert_true(sf.get_animation_loop("default"), "%s idle는 루프" % arche)

func test_idle_frames_cached_shared_instance() -> void:
	# 같은 세트는 캐시된 동일 인스턴스를 돌려준다(64부대 공유 — 매번 새로 만들지 않음).
	assert_same(UnitSprites.idle_frames("light_infantry"), UnitSprites.idle_frames("light_infantry"),
		"같은 세트 idle_frames는 동일 캐시 인스턴스")
