class_name TurnManager extends RefCounted
## 게임의 턴 진행을 관리한다. 시각 요소가 없는 순수 데이터/로직이라 씬 없이 스크립트만 둔다.
## 턴 종료 = 번호 +1 → 모든 유닛 이동 상태 리셋 → 모든 영지 자원 수입 → 모든 영지 건설 진행.

var number := 1   # 현재 턴 번호. 1부터 시작.

## 한 턴을 종료한다.
## units: 이동 상태를 리셋할 유닛(주인공 등). territories: 자원 수입·건설 진행을 받을 영지.
## 수입 정산 뒤에 건설을 진행하므로, 이번 턴에 완성된 건물은 다음 턴부터 생산한다.
func end_turn(units: Array, territories: Array) -> void:
	number += 1
	for unit in units:
		unit.reset_turn()
	for territory in territories:
		territory.collect_income()
	for territory in territories:
		territory.advance_construction()
