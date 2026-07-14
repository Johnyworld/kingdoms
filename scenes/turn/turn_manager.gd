class_name TurnManager extends RefCounted
## 게임의 턴 진행을 관리한다. 시각 요소가 없는 순수 데이터/로직이라 씬 없이 스크립트만 둔다.
## 턴 종료 = 번호 +1 → 유닛 이동 상태 리셋 → 영지 인구 자연 증가 → 영지 건설 진행.
## 자원 생산은 1차 생산포인트·2차 작업포인트로 이관돼 game.gd가 턴 종료 시 별도 처리한다(flat collect_income 폐지).

var number := 1   # 현재 턴 번호. 1부터 시작.

## 한 턴을 종료한다.
## units: 이동 상태를 리셋할 유닛(주인공 등). territories: 인구 증가·건설 진행을 받을 영지.
func end_turn(units: Array, territories: Array) -> void:
	number += 1
	for unit in units:
		unit.reset_turn()
	for territory in territories:
		territory.grow_population()
	for territory in territories:
		territory.advance_construction()
