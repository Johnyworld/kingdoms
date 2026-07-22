extends GutTest
## TypeAdvantage — 병종 상성 테이블(res://data/type_advantage.csv) 로더 검증.
## kind 가위바위보(기병>보병>창병>기병, 기/보/창>궁병)를 데이터로 정의. 우위=+4/+2, 그 외 0.

func test_advantage_pairs() -> void:
	assert_eq(TypeAdvantage.bonus("cavalry", "infantry"), Vector2i(4, 2), "기병>보병")
	assert_eq(TypeAdvantage.bonus("infantry", "spear"), Vector2i(4, 2), "보병>창병")
	assert_eq(TypeAdvantage.bonus("spear", "cavalry"), Vector2i(4, 2), "창병>기병")
	assert_eq(TypeAdvantage.bonus("infantry", "archer"), Vector2i(4, 2), "보병>궁병")

func test_non_advantage_is_zero() -> void:
	assert_eq(TypeAdvantage.bonus("infantry", "cavalry"), Vector2i.ZERO, "역방향은 보정 없음")
	assert_eq(TypeAdvantage.bonus("infantry", "infantry"), Vector2i.ZERO, "동일 병종 보정 없음")

func test_archer_beats_none() -> void:
	# 궁병은 공격측일 때 어떤 병종도 상성으로 못 이김(원거리 이점 대가).
	for foe in ["cavalry", "infantry", "spear", "archer"]:
		assert_eq(TypeAdvantage.bonus("archer", foe), Vector2i.ZERO, "궁병은 %s에 우위 없음" % foe)

func test_hero_is_neutral() -> void:
	# hero 는 테이블에 없어 공격·방어 양쪽 모두 중립(0).
	assert_eq(TypeAdvantage.bonus("hero", "infantry"), Vector2i.ZERO, "영웅 공격 중립")
	assert_eq(TypeAdvantage.bonus("infantry", "hero"), Vector2i.ZERO, "영웅 방어 중립")
	assert_eq(TypeAdvantage.bonus("", ""), Vector2i.ZERO, "빈 kind 중립")
