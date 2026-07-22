class_name BuildingTypes
## 건물 종류 카탈로그. 각 종류의 스펙(라벨·시야·외형·건설/경제)을 데이터로 정의한다.
## Building.setup(.., type_id)이 여기서 시야·외형을 읽고, 캠프의 resources는 생성 영지의 초기 자원이 된다.
## build_turns/build_cost/demolish_refund/production은 데이터로만 기록 — 소비 로직은 Phase 2.

const CAMP := "camp"
const FARM := "farm"

# 거점(center) = 세력의 전략 앵커. 캠프→마을회관→성 티어. 승리·점령·수비대·캠프 메뉴가 이 세트를 기준으로 한다.
# (캠프 하나라도 있으면 세력 유지 → 세 티어 중 하나라도 있으면 유지.) → docs/spec/features/victory.md
const CENTER_IDS := ["camp", "town_hall", "castle"]

## 그 종류가 거점(center)인지 — 캠프/마을회관/성. 승리·점령·수비대·거점 메뉴 판정에 쓴다.
static func is_center(type_id: String) -> bool:
	return type_id in CENTER_IDS

## 거점 티어(캠프 0 → 마을회관 1 → 성 2). 거점이 아니면 -1. 업그레이드·선행 티어 판정에 쓴다.
static func center_tier(type_id: String) -> int:
	return CENTER_IDS.find(type_id)   # 비거점이면 -1

## 인플레이스 업그레이드의 다음 티어 id(camp→town_hall, town_hall→castle). 최종(성)·비거점이면 "".
static func next_center(type_id: String) -> String:
	var t := center_tier(type_id)
	if t < 0 or t + 1 >= CENTER_IDS.size():
		return ""
	return CENTER_IDS[t + 1]

# --- 이동(통행) ---
# 도시·거점·생산 건물 발자국의 진입비용(통과 가능하나 이동력 페널티). → docs/spec/features/selection-and-movement.md
const CITY_MOVE_COST := 2
# 통행 불가 랜드마크 종류(피라미드·기념물 등). 현재 카탈로그엔 없음 — 후속 랜드마크 배치용 훅.
const IMPASSABLE_TYPES := ["pyramid", "monument"]

## 그 건물 종류 칸의 이동 진입비용. 불가 종류면 Terrain.BLOCKED(-1), 그 외(도시·거점·생산건물)는 CITY_MOVE_COST(2).
static func move_cost(type_id: String) -> int:
	if type_id in IMPASSABLE_TYPES:
		return Terrain.BLOCKED
	return CITY_MOVE_COST

# 건축(캠프 메뉴)에서 지을 수 있는 종류. 거점(캠프·마을회관·성)은 제외 — 캠프=새 영지(미구현), 마을회관·성=업그레이드.
# 순서 = 캠프 메뉴 리스트 표시 순서. 선행 미충족 종류도 뜨되 비활성.
const BUILDABLE_IDS := ["farm", "lumberjack", "iron_mine", "gold_mine", "house"]   # 공성 작업장은 공성 삭제와 함께 제거

const CATALOG := {
	"camp": {
		"label": "캠프",
		"vision": 5,
		"footprint": 7,   # 차지 헥스 수(중심+이웃 6). 소형 건물은 1.
		"prerequisite": "",   # 선행 건물 종류 id(없으면 ""). 그 영지에 선행 완성 건물이 있어야 건축 가능.
		"pop_cap": 0,   # 캠프 티어는 인구 상한 0 — 마을회관으로 업그레이드해야 인구가 생긴다.
		# 초기 자원 = 건설 시 생성되는 영지의 초기 자원. 삽입 순서 = 메뉴 표시 순서.
		# 자원 4종(목재·식량·철·금) + 인구. → docs/spec/data/resources.md
		"resources": {
			"목재": 40,
			"식량": 50,
			"철": 10,
			"금": 0,      # 금광에서 캐는 생산 자원(과거 화폐 역할 폐지)
			"인구": 10,   # 병력 전용 예약(생산·건설비에 안 씀)
		},
		# 외형.
		"fill_color": Color(0.52, 0.38, 0.24, 0.9),  # 부지(흙색)
		"edge_color": Color(0.28, 0.19, 0.1),         # 테두리
		"tent_color": Color(0.85, 0.8, 0.68),         # 텐트
		# 건설 · 경제 (Phase 2에서 사용). 캠프 건설 완료 시 새 영지 생성.
		"build_turns": 8,
		"build_cost": {"목재": 10, "식량": 10},
		"demolish_refund": {"목재": 2},
	},
	# --- 마을회관: 대부분 소형 건물의 선행. 값은 테이블에서 조정(플레이성/부트스트랩, docs 참고). ---
	"town_hall": {
		"label": "마을회관",
		"vision": 6,
		"footprint": 7,
		"prerequisite": "camp",
		# 외형(밝은 목조·기와 계열).
		"fill_color": Color(0.62, 0.5, 0.36, 0.9),
		"edge_color": Color(0.36, 0.26, 0.16),
		"tent_color": Color(0.8, 0.4, 0.3),   # 붉은 기와 지붕 느낌
		"build_turns": 8,
		"build_cost": {"목재": 20, "식량": 20},
		"demolish_refund": {"목재": 2},
		"pop_cap": 10,   # 거점 tier 1 — 인구 상한 10.
		# 상인 방문 등 특수효과는 미구현. production 없음.
	},
	# --- 성: 지휘소 최종 단계(선행 마을회관). 값은 테이블에서 조정(금·목재 도달 불가, docs 참고). ---
	"castle": {
		"label": "성",
		"vision": 8,
		"footprint": 7,
		"prerequisite": "town_hall",
		# 외형(회청색 석조 계열).
		"fill_color": Color(0.5, 0.54, 0.6, 0.9),
		"edge_color": Color(0.28, 0.32, 0.4),
		"tent_color": Color(0.72, 0.76, 0.82),
		"build_turns": 12,
		"build_cost": {"목재": 40, "식량": 30, "철": 20},
		"demolish_refund": {"목재": 4, "철": 2},
		"pop_cap": 20,   # 거점 tier 2 — 인구 상한 20.
		# 고급 건물 해금(마법사의 탑·성벽 등)은 미구현. production 없음.
	},
	"farm": {
		"label": "농장",
		"vision": 4,
		"footprint": 1,
		"prerequisite": "camp",   # 1차 생산은 캠프부터(배치 규칙). → production.md
		# 외형(녹색 밭 계열). 농장 전용 렌더링은 Phase 2에서 다듬는다.
		"fill_color": Color(0.45, 0.62, 0.28, 0.9),
		"edge_color": Color(0.28, 0.4, 0.16),
		"tent_color": Color(0.85, 0.78, 0.5),
		"build_turns": 3,
		"build_cost": {"목재": 5},
		"demolish_refund": {"목재": 1},
		# 1차 생산: 초원 위에 지어 생산포인트(1÷거리)로 식량을 캔다. flat production·required_pop 없음. → production.md
		"primary_production": true,
		"produces": "식량",
		"buildable_terrains": [Terrain.PLAINS],
	},
	# --- 소형 생산 건물(footprint 1). 필요직업/인원은 미구현(다음 슬라이스). ---
	"house": {
		"label": "집",
		"vision": 2,
		"footprint": 1,
		"prerequisite": "town_hall",
		# 외형(따뜻한 흙색 목조 계열).
		"fill_color": Color(0.7, 0.55, 0.4, 0.9),
		"edge_color": Color(0.4, 0.3, 0.2),
		"tent_color": Color(0.85, 0.7, 0.5),
		"build_turns": 4,
		"build_cost": {"목재": 8, "식량": 4},
		"demolish_refund": {"목재": 2},
		# "거주 인구 +2" = 영지 인구 상한 +2(생산이 아님). 완성 시 상한을 올리고, 인구는 턴당 상한까지 자연 증가.
		"pop_cap": 2,
	},
	"lumberjack": {
		"label": "벌목소",
		"vision": 3,
		"footprint": 1,
		"prerequisite": "camp",   # 1차 생산은 캠프부터(배치 규칙). → production.md
		# 외형(짙은 녹갈색 계열).
		"fill_color": Color(0.4, 0.5, 0.28, 0.9),
		"edge_color": Color(0.24, 0.3, 0.15),
		"tent_color": Color(0.7, 0.55, 0.35),
		"build_turns": 3,
		"build_cost": {"목재": 5},
		"demolish_refund": {"목재": 1},
		# 1차 생산: 숲 위에 지어 생산포인트(1÷거리)로 목재를 캔다. → production.md
		"primary_production": true,
		"produces": "목재",
		"buildable_terrains": [Terrain.FOREST],
	},
	# --- 1차 생산 광산: 생산포인트(1÷거리)·지형 제한·캠프 선행. → docs/spec/features/production.md ---
	"iron_mine": {
		"label": "철광",
		"vision": 3,
		"footprint": 1,
		"prerequisite": "camp",
		"fill_color": Color(0.45, 0.46, 0.5, 0.9),
		"edge_color": Color(0.28, 0.29, 0.33),
		"tent_color": Color(0.66, 0.68, 0.72),
		"build_turns": 5,
		"build_cost": {"목재": 15},
		"demolish_refund": {"목재": 2},
		"primary_production": true,
		"produces": "철",
		"buildable_terrains": [Terrain.IRON_VEIN],
	},
	"gold_mine": {
		"label": "금광",
		"vision": 3,
		"footprint": 1,
		"prerequisite": "camp",
		"fill_color": Color(0.6, 0.52, 0.28, 0.9),
		"edge_color": Color(0.4, 0.34, 0.16),
		"tent_color": Color(0.9, 0.8, 0.4),
		"build_turns": 6,
		"build_cost": {"목재": 15, "철": 5},
		"demolish_refund": {"목재": 2, "철": 1},
		"primary_production": true,
		"produces": "금",
		"buildable_terrains": [Terrain.GOLD_VEIN],
	},
}

## 종류 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_type(type_id: String) -> Dictionary:
	return CATALOG.get(type_id, {})
