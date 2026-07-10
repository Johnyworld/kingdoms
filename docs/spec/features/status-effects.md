# Feature: Status Effects (상태이상 — 전투 치명타 연동)

> 스크립트: `scenes/combat/status_effects.gd` (`class_name StatusEffects extends RefCounted`)

유닛([Human](../entities/Human.md))에게 일정 시간 동안 붙는 효과. 이번 슬라이스는 **전투씬 안에서 완결**되는 두 효과, **출혈·기절**만 다룬다. 부여 계기는 [전투 판정](combat.md)의 **치명타**다.

기획 원본 `docs/table/시스템/상태이상.md`는 지속을 **턴** 단위로 적지만, 구현된 전투는 [시간 기반](combat.md)(초)이라 **초 단위로 재해석**했다(수치는 밸런싱용 초안).

## 효과 정의

| 효과 | id | 부여 조건 | 지속 | 효과 | 중첩 |
| --- | --- | --- | --- | --- | --- |
| 출혈 | `bleed` | **참격** 무기 치명타 명중 | `3.0`초 | 초당 `3` 피해(스택당) | O — 재부여 시 지속 리셋 + 스택 +1(상한 `3` = 9dps) |
| 기절 | `stun` | **타격** 무기 치명타 명중 | `2.0`초 | 그동안 **공격 불가** | X — 재부여 시 지속만 리셋 |

- 데미지타입 → 효과: `참격 → bleed`, `타격 → stun`, 그 외(`자돌·원거리·마법`) → 없음.
- 부여는 **치명타로 피해가 실제로 들어간 타격**에서만(빗나감·방패 막기는 부여 없음).

## 순수 API (`status_effects.gd`)

효과 상태는 유닛마다 하나의 `Dictionary`(`effects`)로 들고 다닌다. 예: `{"bleed": {"remaining": 2.4, "stacks": 2, "acc": 0.7}, "stun": {"remaining": 1.1}}`.

| 함수 | 설명 |
| --- | --- |
| `on_crit(damage_type: String) -> String` | 치명타 시 부여할 효과 id. `참격→"bleed"`, `타격→"stun"`, 그 외 `""` |
| `apply(effects: Dictionary, id: String) -> void` | 효과 부여/갱신. `bleed`는 지속 리셋 + 스택 +1(상한). `stun`은 지속만 리셋 |
| `advance(effects: Dictionary, dt: float) -> int` | 모든 효과를 `dt`(초)만큼 진행. 만료된 것 제거. **이 구간 출혈 누적 피해(정수)**를 반환 |
| `is_stunned(effects: Dictionary) -> bool` | `stun` 효과가 살아 있으면 `true` |

- **출혈 도트의 정수화**: 프레임 `dt`가 작아도(예: 0.016초) 피해가 사라지지 않도록, 효과에 실수 누적치 `acc`를 둔다. `advance`는 `acc += dps × stacks × min(dt, 남은지속)` 후 `floor(acc)`만큼을 피해로 떼어내고 `acc`에서 뺀다. 남은 조각은 다음 호출로 이월된다.
- `advance`는 남은 지속을 `dt`만큼 줄이고, 0 이하가 된 효과는 지운다.

## 전투 연동

### `CombatResolver.resolve_hit`

반환 dict에 `"inflict"`(String)를 추가한다.

- **명중 && 미막힘 && 치명타**일 때 `StatusEffects.on_crit(사용무기 데미지타입)`, 그 외에는 `""`.
- 빗나감·방패 막기·비치명 타격은 모두 `inflict = ""`.

### 전투 재생 (오버레이 · 헤드리스)

두 경로 모두 유닛 상태에 `effects: {}`를 두고 [Battle](battle.md)에서 적용한다.

- **피해 적용 후** `resolve_hit`의 `inflict`가 비어 있지 않으면 대상에 `StatusEffects.apply`.
- **시간 진행마다** 각 유닛에 `advance`로 출혈 피해를 hp에서 차감(0 이하면 사망 처리). 헤드리스는 이벤트 사이 경과 시간, 오버레이는 프레임 `delta`가 `dt`다.
- **기절 유닛은 공격하지 않는다**(`is_stunned`면 그 유닛의 공격을 건너뜀).
- **최소 시각 표시(오버레이)**: 출혈 = 토큰 붉은 tint, 기절 = 토큰 흐림. 아이콘·피해 플로팅 등 연출은 `미구현`.

## 이번 범위 밖 (TODO / 미구현)

- **월드맵 턴 이월** — 상태이상은 전투씬 종료와 함께 사라진다. 전투 후 hp가 회복되는 현재 규칙([Battle](battle.md))과 같은 층위. 턴 지속·이월은 `미구현`.
- **나머지 상태이상 10종**(화상·중독·빙결·둔화·속박·실명·침묵·공포·저주·약화)과 이로운 효과 5종 — `미구현`.
- **자돌 → 방어 관통**, 마법·소모품·붕대 등 다른 부여/해제 수단, 신전 정화 — `미구현`.

## 테스트 시나리오

`test/unit/test_status_effects.gd` (순수 로직) + `test/unit/test_combat_resolver.gd`·`test_battle_sim.gd`(연동).

### `on_crit` 매핑 — `test_status_effects.gd`
- [정상] `"참격"` → `"bleed"`
- [정상] `"타격"` → `"stun"`
- [경계] `"자돌"`·`"원거리"`·`"마법"`·`""` → `""`

### `apply` / 중첩 — `test_status_effects.gd`
- [정상] 빈 effects에 `bleed` 부여 → `bleed` 존재, 스택 1, 남은지속 3.0
- [정상] `bleed` 재부여 → 스택 2로 증가, 남은지속 3.0으로 리셋
- [경계] `bleed`를 4번 부여해도 스택 상한 3
- [정상] `stun` 부여/재부여 → 스택 개념 없이 남은지속 2.0으로 (리)셋

### `advance` / 출혈 도트 — `test_status_effects.gd`
- [정상] 스택 1 출혈에 `advance(1.0)` → 3 피해 반환, 남은지속 2.0
- [정상] 작은 dt 누적: `advance(0.5)` 두 번의 피해 합 = `advance(1.0)` 한 번(정수 이월로 손실 없음)
- [정상] 스택 2면 같은 시간에 2배 피해
- [경계] 출혈 전체 지속(3.0초) 동안 누적 피해 총합 = `3dps × 3s × 스택`
- [경계] 남은지속보다 큰 `dt`로 진행 → 남은 시간만큼만 피해, 이후 `bleed` 제거
- [정상] `stun`은 `advance`로 지속이 줄고 0에서 제거, 피해는 0

### `is_stunned` — `test_status_effects.gd`
- [정상] `stun` 부여 직후 `true`, 2.0초 경과(`advance`) 후 `false`

### 치명타 연동 — `test_combat_resolver.gd`
- [정상] 참격 무기로 **치명타 명중**(행운 200으로 항상 치명, 회피 음수로 항상 명중) → `inflict == "bleed"`
- [정상] 타격 무기로 치명타 명중 → `inflict == "stun"`
- [경계] 치명타 아님(행운 0) → `inflict == ""`
- [경계] 빗나감(회피 과다)·방패 막기(막기 100) → `inflict == ""`

### 전투 적용 — `test_battle_sim.gd`
- [정상] 참격 치명 확정(행운 200·항상 명중) 셋업에서, 출혈 도트가 더해져 방어측이 **평타만으로 계산한 경우보다 빨리** 전멸한다(도트 기여 확인, 시드 고정)
- [정상] 기절 셋업 — 타격 치명으로 기절한 유닛은 기절 지속 동안 공격을 걸지 못한다(상대가 그동안 피해를 받지 않음, 시드 고정)

## 관련

- 부여 계기(치명타)·피해 공식은 [Combat](combat.md), 전투 재생은 [Battle](battle.md).
- 기획 원본: `docs/table/시스템/상태이상.md`(전체 비전 — 대부분 미구현).
