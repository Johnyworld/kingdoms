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
var hit_points := 20   # 현재 생명점. 전투에서 깎이고 전투 후에도 지속(battle.gd). 생성 시 max_hp()로 채움
var level := 1         # 전투 레벨. max_hp() 배수. 경험치·성장은 미구현(1 고정)
var stamina := 20      # 현재 스태미나. 생성 시 max_stamina로 채움. 소모 시스템은 미구현(휴식/경계로 회복만)
var max_stamina := 20  # 최대 스태미나(상한)
var alert := false     # 경계 버프. true면 전투 공격력·방어력 ×1.2(CombatResolver). 적 턴 후 해제
var in_command := false  # 지휘 버프. true면 전투 공격력·방어력 ×1.2(alert와 곱셈 중첩). 영웅 지휘 범위 안 소속 하위부대에 전투 직전 부여·전투 후 해제 → command-range.md
var morale := 20       # 사기

# --- 장비 (ItemTypes id) ---
var weapons: Array = []   # 무기 id 목록(최대 MAX_WEAPONS). 첫 원소=주무기. 근접=주무기·원거리=활. 무게 전부 합산. []=맨몸(정상)
var armor: Array = []  # 착용 방어구 id 목록(최대 4). DF=방어력 합, 상성 분류=방어력 최대 조각
var shield := ""       # 방패 id. DF에 방어력 합산 + 막기 확률. ""=없음

const MAX_WEAPONS := 3   # 무기 슬롯 상한(장비 관리 장착이 지킨다). 방패는 단일 슬롯.
const MAX_ARMOR := 4     # 방어구 슬롯 상한.

const BASE_HIT_POINTS := 40   # max_hp() 기본값
const REST_PCT := 0.25        # 휴식: hp·스태미나 회복 비율
const ALERT_STAM_PCT := 0.10  # 경계: 스태미나 회복 비율

func _init(p_name := "") -> void:
	human_name = p_name

## 최대 생명점(상한) = 40 + floor(힘/10) × 전투 레벨. 민첩 등 다른 스탯 기여·회복 수단은 미구현.
## 장비 무관한 고유 능력치라 Human 메서드로 둔다(장비 반영 계산 스탯은 CombatResolver).
func max_hp() -> int:
	return BASE_HIT_POINTS + int(strength) / 10 * level   # 정수 나눗셈(내림) × level

## 휴식 — hp·스태미나를 각각 최대의 25%(반올림)만큼 회복(상한 clamp).
func apply_rest() -> void:
	hit_points = mini(max_hp(), hit_points + int(round(max_hp() * REST_PCT)))
	stamina = mini(max_stamina, stamina + int(round(max_stamina * REST_PCT)))

## 경계 — 스태미나 10%(반올림) 회복 + 전투 버프(alert) 부여.
func apply_alert() -> void:
	stamina = mini(max_stamina, stamina + int(round(max_stamina * ALERT_STAM_PCT)))
	alert = true
