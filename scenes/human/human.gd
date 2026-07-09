class_name Human extends RefCounted
## 사람(Human). 능력치·자원을 보유하는 순수 데이터. 부대(Party)의 멤버로 존재한다.
## 맵 표시·선택·이동·마커 그리기는 개별 Human이 아니라 이들을 거느린 Party가 담당한다.

# --- 정체 ---
## 이름. 엔진 내장 프로퍼티 `name`과의 혼동을 피하려 별도 변수로 둔다.
var human_name := ""

# --- 능력치 (초기값) ---
var strength := 8      # 힘
var wisdom := 5        # 지혜
var agility := 6       # 민첩
var charm := 10        # 매력
var luck := 8          # 행운
var movement := 3      # 이동력 (부대 이동력 = 멤버 중 최소값)
var vision := 5        # 시야 (부대 시야 = 멤버 중 최대값)
var leadership := 7    # 지휘력
var eloquence := 9     # 화술
var diligence := 5     # 성실함
var sensitivity := 8   # 예민함

# --- 자원 ---
var hit_points := 20   # 히트포인트
var stamina := 20      # 스태미나
var morale := 20       # 사기

# --- 장비 (ItemTypes id) ---
var weapon := ""       # 무기 id. 전투 AT·데미지타입에 사용. ""=맨몸
var armor: Array = []  # 착용 방어구 id 목록(최대 4). DF=방어력 합, 상성 분류=방어력 최대 조각

func _init(p_name := "") -> void:
	human_name = p_name
