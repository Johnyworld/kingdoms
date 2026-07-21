# Feature: Command Range (지휘 범위 버프)

> 스크립트: `scenes/party/party.gd` (`command_range`·`command_buffed`·배지 `_draw`) · `scenes/human/human.gd` (`in_command`) · `scenes/combat/combat_resolver.gd` (`COMMAND_MULT`) · `scenes/game/game.gd` (`_in_command`·`_refresh_command_buffs`·`_apply_command_flags`)

랑그릿사식 편제의 핵심. **일반부대**([Party](../entities/Party.md) `KIND_TROOP`)가 자신이 [소속](party-lord.md)된 **영웅부대**(`lord`)의 **지휘 범위 안**에 있으면, 전투에서 **공격·방어 ×1.2** 보정을 받는다. 지휘관 곁에 부하를 모아 싸우게 만드는 유인이다.

## 지휘 범위 — `Party.command_range()`

영웅부대의 지휘 반경(헥스). **부대 아키타입의 lang 클래스 `cmd_range`** 로 결정한다([GameUnits](../data/units.md) → LangData). Human `leadership` 스탯 기반 공식은 [순수 랑그릿사 유닛 모델 전환](lang-battle.md#게임-통합)으로 폐기.

```
command_range() = GameUnits.command_range(archetype())   # = lang 클래스 cmd_range
```

- 영웅(클래스 4) `cmd_range = 4`, 경보병·경궁병(클래스 1) `cmd_range = 3`. 아키타입 없으면 `0`.
- 영웅부대가 아니어도 호출은 되지만, 버프 판정은 **일반부대의 `lord`(영웅부대)** 에 대해서만 쓴다.

## 버프 판정 — `_in_command(troop)` (`game.gd`)

일반부대 `troop`이 지금 지휘 범위 안인지:

- `troop.lord`가 있고, 그 영웅부대에 **살아있는 멤버가 있어야** 한다(전멸한 영웅은 지휘 못 함).
- `troop`의 칸이 `lord` 칸에서 **`lord.command_range()` 헥스 이내**여야 한다. 거리는 **지형 무관 헥스 거리**(`HexGrid.cells_within`, 산에 막히지 않음) — 지휘는 지형을 타지 않는다.
- **영웅부대 자신**은 `lord == null`이라 항상 거짓(지휘관은 지휘 버프를 받지 않는다 — 원작대로 부하만).

## 전투 효과 — `Human.in_command` + `CombatResolver`

alert와 **같은 모델**: 멤버 플래그 → CombatResolver가 배율 곱.

- `Human.in_command: bool`(기본 `false`). 참이면 전투 공격력·방어력에 `COMMAND_MULT = 1.2`를 곱한다.
- `CombatResolver.attack_power(h)` / `defense(h)`: 배율 = `(alert면 ×ALERT_MULT) × (in_command이면 ×COMMAND_MULT)`. **alert와 곱셈 중첩**(경계+지휘 = ×1.44, 내림).
- **수명(alert와 동일)**: 전투 직전 양측 부대의 멤버에 세팅하고, 전투가 끝나면 해제한다.
  - `_run_battle`·`_resolve_battle_headless`(부대 vs 부대) 진입 시 `_apply_command_flags(attacker, true)`(+ `defender`), 종료 시 `false`. **멤버가 전투에 참여하는 모든 경로**에 붙인다.
  - `_apply_command_flags(party, on)`: `party`의 각 멤버 `in_command = on and party.command_buffed`(아래 배지 상태 재사용).
- **모든 세력** 적용 — 플레이어·NPC 모두 자기 영웅 근처 부대가 강해진다(전투 경로가 대칭이라 자동).

## 맵 배지 — `Party.command_buffed`

플레이어가 버프 상태를 **눈으로 보고** 부대를 지휘관 곁에 모으도록 토큰에 표시한다.

- `Party.command_buffed: bool`(기본 `false`). 참이면 토큰에 **지휘 배지**(작은 금색 표식)를 그린다(`_draw`).
- `_refresh_command_buffs()`(`game.gd`): `PartyManager.units + PartyManager.npc_parties`의 각 부대에 `command_buffed = _in_command(p)`를 세팅하고, 값이 바뀌면 다시 그린다.
- **갱신 시점**(위치가 정착하는 지점): 턴 종료, 플레이어 이동 완료, 추종·교전·돌격 시퀀스 종료, NPC 이동 완료, 소속 변경(`_on_lord_changed`), 부대 분할·병합.
- 전투 직전 `_run_battle`도 먼저 `_refresh_command_buffs()`를 불러 `command_buffed`를 최신화한 뒤 `_apply_command_flags`가 그 값을 읽는다(전투 데미지의 단일 출처).

## API

`Party` (`party.gd`):

| 속성/메서드 | 설명 |
| --- | --- |
| `command_range()` | 지휘 반경(헥스) = lang 클래스 `cmd_range`(영웅 4·경보병 3), 아키타입 없으면 0 |
| `command_buffed` | `bool`, 기본 `false`. 지휘 범위 안이라 버프 중인지(맵 배지·전투 플래그의 출처) |

`Human` (`human.gd`): `in_command: bool`(기본 `false`) — 전투 배율 플래그(`CombatResolver`가 읽음).

`CombatResolver`: `COMMAND_MULT = 1.2` — 공격력·방어력 지휘 배율.

`game.gd`:
- `_in_command(troop) -> bool` — 위 판정.
- `_refresh_command_buffs() -> void` — 모든 부대 `command_buffed` 갱신.
- `_apply_command_flags(party, on) -> void` — 부대 멤버 `in_command`를 `command_buffed` 기준으로 on/off.

## 미구현 / 후속

- **대기(방어) 자세 버프**, **NPC 작전 발동** — [Squad Stance](squad-stance.md) 참고.
- 지휘 범위 밖 페널티(사기 저하 등)는 없음 — 지금은 "안이면 보너스"만.

## 테스트 시나리오

### 전투 배율 — `test/unit/test_combat_resolver.gd`

- [정상] `in_command = true`면 `attack_power`·`defense`가 ×1.2(내림), `false`면 원값
- [정상] `alert`와 `in_command` 둘 다 true면 ×1.44(내림) — 곱셈 중첩
- [경계] `in_command = false`, `alert = false`면 원값(회귀 확인)

### 지휘 범위 공식 — `test/unit/test_party.gd`

- [정상] 영웅 부대 → `command_range() == 4`(클래스 4); 경보병 → `3`(클래스 1)
- [경계] 아키타입 없으면 `command_range() == 0`
- [정상] 생성 직후 `command_buffed == false`

### 판정·배지·갱신 (실행 확인)

`_in_command`(부대 거리·lord 위치)·배지 렌더·`_refresh_command_buffs` 호출 시점·전투 직전 플래그 세팅/해제는 씬 트리·터레인 의존이라 실제 실행으로 확인한다.

- 하위부대를 영웅 지휘 범위(클래스 4 → 4칸) 안에 두면 배지가 켜지고, 밖으로 나가면 꺼진다.
- 지휘 범위 안 하위부대가 전투하면 공격·방어가 ×1.2(경계까지면 ×1.44)로 적용된다.
- 영웅부대 자신·소속 없는 독립부대는 배지·버프 없음.
- NPC 하위부대도 자기 영웅 근처면 버프(배지 표시).

## 관련

- [Party (부대)](../entities/Party.md) — `lord`·`command_range`·`command_buffed`. [Party Lord](party-lord.md) — 소속 설정. [Squad Stance](squad-stance.md) — 하위부대를 영웅 곁으로 모으는 작전(추종 등).
- [Combat](combat.md) — 데미지 공식·배율(alert·지휘). 지휘 범위값은 [GameUnits](../data/units.md) 클래스 `cmd_range`.
