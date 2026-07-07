class_name BuildingTypes
## 건물 종류 카탈로그. 각 종류의 스펙(라벨·시야·외형·건설/경제)을 데이터로 정의한다.
## Building.setup(.., type_id)이 여기서 시야·외형을 읽고, 캠프의 resources는 생성 영지의 초기 자원이 된다.
## build_turns/build_cost/demolish_refund/production은 데이터로만 기록 — 소비 로직은 Phase 2.

const CAMP := "camp"
const FARM := "farm"

# 건축(캠프 메뉴)에서 지을 수 있는 종류. 캠프는 새 영지 생성이라 제외(미구현).
const BUILDABLE_IDS := ["farm"]

const CATALOG := {
	"camp": {
		"label": "캠프",
		"vision": 5,
		# 초기 자원 = 건설 시 생성되는 영지의 초기 자원. 삽입 순서 = 메뉴 표시 순서.
		"resources": {
			"인구": 10,
			"밀": 50,
			"빵": 20,
			"나무": 20,
			"목재": 20,
			"철": 10,
			"철괴": 10,
		},
		# 외형.
		"fill_color": Color(0.52, 0.38, 0.24, 0.9),  # 부지(흙색)
		"edge_color": Color(0.28, 0.19, 0.1),         # 테두리
		"tent_color": Color(0.85, 0.8, 0.68),         # 텐트
		# 건설 · 경제 (Phase 2에서 사용). 캠프 건설 완료 시 새 영지 생성.
		"build_turns": 8,
		"build_cost": {"목재": 10, "밀": 10},
		"demolish_refund": {"목재": 2},
	},
	"farm": {
		"label": "농장",
		"vision": 4,
		# 외형(녹색 밭 계열). 농장 전용 렌더링은 Phase 2에서 다듬는다.
		"fill_color": Color(0.45, 0.62, 0.28, 0.9),
		"edge_color": Color(0.28, 0.4, 0.16),
		"tent_color": Color(0.85, 0.78, 0.5),
		# 건설 · 경제 (Phase 2에서 사용).
		"build_turns": 3,
		"build_cost": {"인구": 2, "목재": 5, "밀": 5},
		"demolish_refund": {"인구": 2, "목재": 1},
		"production": {"밀": 1},
	},
}

## 종류 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_type(type_id: String) -> Dictionary:
	return CATALOG.get(type_id, {})
