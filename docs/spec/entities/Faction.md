# Entity: Faction (세력)

> 스크립트: `scenes/faction/faction.gd` (`class_name Faction extends RefCounted`)

**영지**를 보유하는 세력. 예: "푸른 왕국". 하나의 세력은 여러 [영지](Territory.md)를 거느린다.
구조: **세력(Faction) → [영지](Territory.md) → [건물](Building.md)**.

시각 요소가 없는 **순수 데이터 엔티티**라 씬(`.tscn`) 없이 스크립트만 둔다.
(폴더 규칙 "각 폴더에 `.tscn` + `.gd`"의 소수 예외 — 데이터 전용 엔티티라 씬이 불필요.)

## Properties

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 이름 | `name` | `String` | `""` | 세력 이름 (예: "푸른 왕국") |
| 색상 | `color` | `Color` | `Color.WHITE` | 세력 대표색 (UI 표기용) |
| 소속 영지 | `territories` | `Array` | `[]` | 이 세력에 속한 [Territory](Territory.md) 목록 |
| 소멸 유예 | `grace_turns` | `int` | `-1` | 지휘소를 모두 잃은 뒤 소멸까지 남은 턴. `-1`이면 위기 아님. → [승패](../features/victory.md) |
| 소멸 여부 | `eliminated` | `bool` | `false` | 세력 소멸 확정 여부. true면 이후 판정에서 제외 |

`RefCounted`라 `name`은 노드 이름과 무관하게 자유롭게 쓸 수 있다.

## 동작

- `_init(name := "", color := Color.WHITE)` — 이름·색상을 받아 생성. `territories`는 빈 배열로 시작.
- `add_territory(territory) -> void` — 영지를 `territories`에 추가하고 **동시에** `territory.faction = self`로 설정한다(양방향 동기화). 이미 포함된 영지는 중복 추가하지 않는다.
- `remove_territory(territory) -> void` — 영지를 `territories`에서 제거하고, `territory.faction`이 이 세력이면 `null`로 되돌린다(양방향 해제). 없으면 no-op. [캠프 점령](../features/camp-capture.md) 흡수 시 이전 세력에서 영지를 떼어낼 때 쓴다.

## 테스트 시나리오

`test/unit/test_faction.gd`.

- [정상] `_init("푸른 왕국", 파랑)` 후 `name == "푸른 왕국"`, `color == 파랑`
- [정상] 생성 직후 `territories`는 빈 배열, `grace_turns == -1`, `eliminated == false`
- [정상] `add_territory(t)` 후 `territories`에 `t`가 들어가고, `t.faction`이 이 세력을 가리킨다 (양방향)
- [경계] 같은 영지를 두 번 `add_territory` 해도 `territories` 크기는 1 (중복 방지)
- [정상] `remove_territory(t)` 후 `territories`에서 빠지고 `t.faction == null`
- [정상] 이전: `old.remove_territory(t)` → `new.add_territory(t)` 후 `t.faction == new`, `new`에 포함·`old`에서 제외
- [경계] 보유하지 않은 영지를 `remove_territory` → no-op(크래시 없음)

## 관련

- 영지는 [Territory 엔티티](Territory.md)의 `faction` 필드로 자기 세력을 참조한다.
- 세력 이름은 [Camp Menu](../features/camp-menu.md) 우측 패널에 영지 이름과 함께 표시된다.
