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
var alert := false     # 경계 플래그. 적 턴 후 해제. 구 전투 수학(×1.2) 폐기로 현재 전투 미반영(플래그만 유지)
var in_command := false  # 지휘 플래그. 영웅 지휘 범위 안 소속 하위부대에 전투 직전 부여·전투 후 해제 → command-range.md. 구 ×1.2 폐기로 현재 전투 미반영
var morale := 20       # 사기

const REST_PCT := 0.25        # 휴식: hp·스태미나 회복 비율
const ALERT_STAM_PCT := 0.10  # 경계: 스태미나 회복 비율

func _init(p_name := "") -> void:
	human_name = p_name

## 최대 생명점(상한) = floor(힘/2) × 전투 레벨. 힘에 비례(고정 바탕 없음) — 힘 낮은 보병은 얇고 힘 높은 영웅은 두껍다.
## 민첩 등 다른 스탯 기여·회복 수단은 미구현. 장비 무관한 고유 능력치라 Human 메서드로 둔다(구 장비 반영 전투 계산은 폐기 — 전투는 lang 클래스). → stats.md
func max_hp() -> int:
	return int(strength) / 2 * level   # 정수 나눗셈(내림) × level

## 휴식 — hp·스태미나를 각각 최대의 25%(반올림)만큼 회복(상한 clamp).
func apply_rest() -> void:
	hit_points = mini(max_hp(), hit_points + int(round(max_hp() * REST_PCT)))
	stamina = mini(max_stamina, stamina + int(round(max_stamina * REST_PCT)))

## 경계 — 스태미나 10%(반올림) 회복 + 전투 버프(alert) 부여.
func apply_alert() -> void:
	stamina = mini(max_stamina, stamina + int(round(max_stamina * ALERT_STAM_PCT)))
	alert = true
