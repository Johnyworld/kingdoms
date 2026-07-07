# Entity: Character (주인공)

> 스크립트: `scenes/character/character.gd` (`extends Node2D`)
> 씬: `scenes/character/character.tscn`

맵 위에 표시되는 주인공. 능력치와 자원을 보유하며, 선택 시 강조 링이 표시된다.
현재 외형은 임시 플레이스홀더(원형 마커, 반지름 12px)로 `_draw()`에서 직접 그려진다.

## Properties

### 능력치 (Stats)

| 속성 | export 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 힘 | `strength` | 8 | |
| 지혜 | `wisdom` | 5 | |
| 민첩 | `agility` | 6 | |
| 매력 | `charm` | 10 | |
| 행운 | `luck` | 8 | |
| 이동력 | `movement` | 5 | 한 번에 이동 가능한 헥스 거리 (범위·이동 판정에 사용) |
| 시야 | `vision` | 5 | 전장의 안개를 밝히는 반경 |
| 지휘력 | `leadership` | 7 | |
| 화술 | `eloquence` | 9 | |
| 성실함 | `diligence` | 5 | |
| 예민함 | `sensitivity` | 8 | |

### 자원 (Resources)

| 속성 | export 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 히트포인트 | `hit_points` | 20 | |
| 스태미나 | `stamina` | 20 | |
| 사기 | `morale` | 20 | |

### 상태 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 선택됨 | `selected` | 선택 상태. `set_selected(value)`로 변경 시 강조 링을 다시 그린다 |
| 이번 턴 이동함 | `moved_this_turn` | 이번 [턴](../features/turn.md)에 이미 이동했는지. `true`면 재선택·재이동 불가 + 흐리게 표시 |

## 동작

- `set_selected(bool)` — 선택 상태를 토글하고 `queue_redraw()`.
- `can_move() -> bool` — 이번 턴에 이동 가능한지(`not moved_this_turn`).
- `mark_moved() -> void` — 이동 완료 표시(`moved_this_turn = true`). 흐리게(반투명) 다시 그린다.
- `reset_turn() -> void` — 턴 종료 시 호출. `moved_this_turn = false`로 되돌리고 불투명하게 다시 그린다.
- `_draw()` — 선택 시 발밑 강조 링(노란색) + 그림자 + 몸통 원 + 외곽선을 그린다. `moved_this_turn`이면 전체를 반투명하게 그린다.

## 관련

- 이동력·시야는 [Selection & Movement](../features/selection-and-movement.md), [Fog of War](../features/fog-of-war.md)에서 사용.
- 턴당 1회 이동 제한(`moved_this_turn`/`can_move`/`mark_moved`/`reset_turn`)은 [Turn](../features/turn.md)에서 사용. 관련 테스트는 `test/unit/test_turn.gd`.
- 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
