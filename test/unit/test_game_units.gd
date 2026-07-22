extends GutTest
## GameUnits — 게임 아키타입 → 랑그릿사 클래스 매핑 카탈로그.
## HP·시야·원거리는 카탈로그 값, 이동력·지휘범위·AT/DF는 LangData(class_stats.csv) 위임을 검증.

func test_archetype_specs() -> void:
	assert_eq(GameUnits.class_id("hero"), 4, "영웅 = 지휘관 클래스 4")
	assert_eq(GameUnits.class_id("light_infantry"), 1, "경보병 = 클래스 1")
	assert_eq(GameUnits.class_id("light_archer"), 1, "경궁병 = 클래스 1(경보병과 동일 base)")
	assert_eq(GameUnits.max_hp("light_infantry"), 10, "병력(HP) 10")
	assert_true(GameUnits.is_ranged("light_archer"), "경궁병은 원거리")
	assert_false(GameUnits.is_ranged("light_infantry"), "경보병은 근접")
	assert_false(GameUnits.is_ranged("hero"), "영웅은 근접")

func test_display_name() -> void:
	assert_eq(GameUnits.display_name("light_infantry"), "경보병", "병종 표시명")
	assert_eq(GameUnits.display_name("light_archer"), "경궁병", "병종 표시명")
	assert_eq(GameUnits.display_name("hero"), "", "영웅은 표시명 없음(hero_name 사용)")
	assert_eq(GameUnits.display_name("없음"), "", "미지 아키타입 → 빈 문자열")

func test_lang_kind_mapping() -> void:
	assert_eq(GameUnits.lang_kind("light_infantry"), "infantry", "근접 = infantry 병종")
	assert_eq(GameUnits.lang_kind("light_archer"), "archer", "원거리 = archer 병종(근접 상성 페널티)")
	assert_eq(GameUnits.lang_kind("hero"), "", "영웅 = 병종 중립")

func test_map_stats_from_lang_class() -> void:
	# class_stats.csv: 클래스 1 = mv6·cmd_range3·at23·df21, 클래스 4 = mv6·cmd_range4·at27·df24.
	assert_eq(GameUnits.movement("light_infantry"), 6, "이동력 = 클래스1 mv")
	assert_eq(GameUnits.command_range("light_infantry"), 3, "지휘범위 = 클래스1 cmd_range")
	assert_eq(GameUnits.movement("hero"), 6, "영웅 이동력 = 클래스4 mv")
	assert_eq(GameUnits.command_range("hero"), 4, "영웅 지휘범위 = 클래스4 cmd_range")
	assert_eq(GameUnits.base_at("hero"), 27, "영웅 기본 AT = 클래스4 at")
	assert_eq(GameUnits.base_df("hero"), 24, "영웅 기본 DF = 클래스4 df")
	assert_eq(GameUnits.base_at("light_infantry"), 23, "경보병 기본 AT = 클래스1 at")

func test_unknown_archetype() -> void:
	assert_eq(GameUnits.class_id("없음"), 0, "미지 아키타입 → 클래스 0")
	assert_eq(GameUnits.max_hp("없음"), 0, "미지 → HP 0")
	assert_eq(GameUnits.movement("없음"), 0, "미지 → 이동력 0")
	assert_false(GameUnits.is_ranged("없음"), "미지 → 원거리 아님")
