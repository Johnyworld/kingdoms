# Feature: Combat Feedback (전투 연출 — 대미지 숫자·타격 효과)

> 스크립트: `scenes/combat/hit_feedback.gd` (`class_name HitFeedback extends RefCounted`) · `scenes/combat/battle.gd`

전투씬([Battle](battle.md)) 오버레이에 **타격의 시각 피드백**을 더한다. 떠오르는 대미지 숫자, 피격 반짝임·흔들림, 공격 돌진, 상태이상 텍스트, 사망 축소. 판정은 [CombatResolver](combat.md)·[StatusEffects](status-effects.md)가 이미 내며, 이 기능은 그 결과를 **보이게** 만든다.

**판정 결과 → 텍스트 사양** 매핑만 순수 로직(`HitFeedback`)으로 빼서 단위 테스트하고, 실제 애니메이션(tween)은 프로젝트 관례대로 **실행으로 확인**한다.

## 순수 로직 (`hit_feedback.gd`)

씬·노드 없이 판정 결과를 "떠오를 텍스트 사양"으로 바꾸는 순수 함수. 색은 `Color` 상수(값 타입)라 테스트에서 그대로 비교한다.

| 함수 | 반환 | 규칙 |
| --- | --- | --- |
| `hit_text(r: Dictionary) -> Dictionary` | `{text: String, color: Color, big: bool}` | `resolve_hit` 결과 `r`를 받아 아래 표대로 |
| `status_text(id: String) -> String` | 텍스트 | `"bleed"→"출혈!"`, `"stun"→"기절!"`, 그 외 `""` |

`hit_text` 분기(위에서부터 우선):

| 조건 | text | color | big |
| --- | --- | --- | --- |
| `not r.hit` (빗나감) | `"빗나감"` | `MISS_COLOR` 회색 | `false` |
| `r.blocked` (막기) | `"막기"` | `BLOCK_COLOR` 하늘색 | `false` |
| `r.crit` (치명타) | `str(r.damage)` | `CRIT_COLOR` 노랑 | `true` |
| 그 외 (평타) | `str(r.damage)` | `HIT_COLOR` 흰색 | `false` |

- 색 상수(초안): `MISS=(0.7,0.7,0.7)`, `BLOCK=(0.6,0.8,1.0)`, `HIT=(1,1,1)`, `CRIT=(1.0,0.85,0.2)`. 출혈 도트 숫자 색 `BLEED=(1.0,0.4,0.4)`, 상태이상 텍스트 색 `STATUS=(1.0,0.6,0.2)`는 `battle.gd`가 쓴다.

## 오버레이 연출 (`battle.gd`)

토큰은 바깥 `Control`(node) 안에 몸통 `ColorRect`(name `body`) + hp `Label`을 둔다. `_sync_node`가 **매 프레임 node.position**을 갱신하므로, 흔들림·돌진·반짝임은 **node를 건드리지 않고 내부 `body`의 위치/색을 tween**해 충돌을 피한다.

| 연출 | 계기 | 방식 |
| --- | --- | --- |
| 대미지 숫자 | 타격 1회(`_attack`) | 대상 위치에서 `hit_text` 라벨을 위로 띄우며 페이드. `big`이면 확대 |
| 상태이상 텍스트 | `r.inflict` 있음 | `status_text` 라벨을 대상 위로 띄움(숫자보다 살짝 위·늦게) |
| 출혈 도트 숫자 | 도트 틱(hp 감소) | 작은 붉은 `str(피해)` 라벨을 유닛 위로 띄움 |
| 흰 반짝임 | 피해 입은 타격(명중·미막힘·피해>0) | 대상 `body.color`를 잠깐 흰색 → 팀색 복귀 |
| 흔들림 | 위와 동일 | 대상 `body.position`을 짧게 좌우 흔들고 원위치 |
| 돌진(lunge) | 공격(`_attack`) | 공격자 `body.position`을 대상 쪽으로 살짝 냈다 복귀 |
| 사망 축소 | 전투불능(`_kill`) | `node.scale`을 축소 tween(+기존 alpha 0.3) |

- 수치는 초안: 떠오름 높이 ~40px·0.7초, 반짝임 ~0.12초, 흔들림 ~0.18초, 돌진 ~10px·0.12초, 사망 스케일 0.6.
- 연출은 관전 편의일 뿐 **판정·생존 결과에 영향을 주지 않는다**(피해는 이미 `_attack`/도트에서 적용됨).

## 미구현 (범위 밖)

- 히트스톱·화면 전체 흔들림·파티클·사운드·데미지 타입별 이펙트 — `미구현`.
- HP 바(현재는 숫자 라벨), 상태이상 아이콘(현재는 텍스트+tint) — `미구현`.

## 테스트 시나리오

`test/unit/test_hit_feedback.gd` (순수). 애니메이션은 실행으로 확인.

### `hit_text` — 판정 → 텍스트 사양
- [정상] 평타(hit·미막힘·비치명, damage 15) → `text=="15"`, `color==HIT_COLOR`, `big==false`
- [정상] 치명타(crit, damage 22) → `text=="22"`, `color==CRIT_COLOR`, `big==true`
- [경계] 빗나감(`hit==false`) → `text=="빗나감"`, `color==MISS_COLOR`, `big==false` (damage 무시)
- [경계] 막기(`blocked==true`) → `text=="막기"`, `color==BLOCK_COLOR`, `big==false`
- [경계] 우선순위 — 빗나감이면 치명·피해와 무관하게 `"빗나감"`

### `status_text` — 상태이상 id → 텍스트
- [정상] `"bleed"` → `"출혈!"`, `"stun"` → `"기절!"`
- [경계] `""`·미지정 id → `""`

### 실행 확인 (오버레이)
- 타격 시 대상 위로 숫자가 떠오르고, 치명타는 노랑·큰 글씨로 뜬다.
- 빗나감/막기 시 각각 `"빗나감"`/`"막기"`가 뜬다.
- 피해 입은 토큰이 흰색으로 반짝이며 살짝 흔들린다.
- 공격자가 공격 순간 대상 쪽으로 살짝 돌진했다 복귀한다.
- 상태이상 부여 시 `"출혈!"`/`"기절!"`이 뜨고, 출혈 도트마다 작은 붉은 숫자가 뜬다.
- 전투불능 시 토큰이 축소되며 흐려진다.

## 관련

- 판정: [Combat](combat.md), 상태이상: [Status Effects](status-effects.md), 전투씬 흐름: [Battle](battle.md).
