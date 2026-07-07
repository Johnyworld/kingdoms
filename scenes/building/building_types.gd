class_name BuildingTypes
## 건물 종류 카탈로그. 각 종류의 스펙(라벨·시야·초기 자원·외형)을 데이터로 정의한다.
## Building.setup(.., type_id)이 여기서 스펙을 읽어 인스턴스 값을 채운다.

const CAMP := "camp"

const CATALOG := {
	"camp": {
		"label": "캠프",
		"vision": 5,
		# 초기 자원. 삽입 순서 = 캠프 메뉴 표시 순서.
		"resources": {
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
	},
}

## 종류 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_type(type_id: String) -> Dictionary:
	return CATALOG.get(type_id, {})
