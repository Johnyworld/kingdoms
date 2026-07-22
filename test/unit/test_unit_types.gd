extends GutTest
## UnitTypes — 게임 아키타입 카탈로그(단일 출처, res://data/unit_types.csv).
## HP·시야·원거리·kind·전투 스탯(at/df·mv·cmd_range·cmd_at/cmd_df)이 모두 카탈로그 값임을 검증.

func test_archetype_specs() -> void:
	assert_eq(UnitTypes.kind("hero"), "hero", "영웅 kind")
	assert_eq(UnitTypes.kind("light_infantry"), "infantry", "경보병 kind")
	assert_eq(UnitTypes.kind("light_archer"), "archer", "경궁병 kind")
	assert_eq(UnitTypes.max_hp("light_infantry"), 10, "병력(HP) 10")
	assert_true(UnitTypes.is_ranged("light_archer"), "경궁병은 원거리")
	assert_false(UnitTypes.is_ranged("light_infantry"), "경보병은 근접")
	assert_false(UnitTypes.is_ranged("hero"), "영웅은 근접")

func test_display_name() -> void:
	assert_eq(UnitTypes.display_name("light_infantry"), "경보병", "병종 표시명")
	assert_eq(UnitTypes.display_name("light_archer"), "경궁병", "병종 표시명")
	assert_eq(UnitTypes.display_name("hero"), "", "영웅은 표시명 없음(hero_name 사용)")
	assert_eq(UnitTypes.display_name("없음"), "", "미지 아키타입 → 빈 문자열")

func test_kind_mapping() -> void:
	assert_eq(UnitTypes.kind("light_infantry"), "infantry", "근접 = infantry 병종")
	assert_eq(UnitTypes.kind("light_archer"), "archer", "원거리 = archer 병종(근접 상성 페널티)")
	assert_eq(UnitTypes.kind("hero"), "hero", "영웅 kind(상성 중립 — TypeAdvantage에 hero 행 없음)")

func test_combat_stats() -> void:
	# unit_types.csv: 경보병·경궁병 = at23·df21·mv6·cmd_range3·cmd_at2·cmd_df2, 영웅 = at27·df24·mv6·cmd_range4·cmd_at2·cmd_df4.
	assert_eq(UnitTypes.movement("light_infantry"), 6, "이동력")
	assert_eq(UnitTypes.command_range("light_infantry"), 3, "지휘범위")
	assert_eq(UnitTypes.movement("hero"), 6, "영웅 이동력")
	assert_eq(UnitTypes.command_range("hero"), 4, "영웅 지휘범위")
	assert_eq(UnitTypes.base_at("hero"), 27, "영웅 기본 AT")
	assert_eq(UnitTypes.base_df("hero"), 24, "영웅 기본 DF")
	assert_eq(UnitTypes.base_at("light_infantry"), 23, "경보병 기본 AT")

func test_combat_stats_bundle() -> void:
	# LangResolver 주입용 번들 — at/df/cmd_*/kind 를 한 번에.
	var s: Dictionary = UnitTypes.combat_stats("hero")
	assert_eq(s["at"], 27, "번들 at")
	assert_eq(s["df"], 24, "번들 df")
	assert_eq(s["cmd_range"], 4, "번들 cmd_range")
	assert_eq(s["cmd_at"], 2, "번들 cmd_at")
	assert_eq(s["cmd_df"], 4, "번들 cmd_df")
	assert_eq(s["kind"], "hero", "번들 kind")

func test_unknown_archetype() -> void:
	assert_eq(UnitTypes.kind("없음"), "", "미지 아키타입 → 빈 kind")
	assert_eq(UnitTypes.max_hp("없음"), 0, "미지 → HP 0")
	assert_eq(UnitTypes.movement("없음"), 0, "미지 → 이동력 0")
	assert_false(UnitTypes.is_ranged("없음"), "미지 → 원거리 아님")
