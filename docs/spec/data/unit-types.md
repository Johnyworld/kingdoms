# Data: Unit Types (병종 아키타입 카탈로그)

> 스크립트: `scenes/party/unit_types.gd` (`class_name UnitTypes`)
> 데이터: `res://data/unit_types.csv`(병종 아키타입) · `res://data/type_advantage.csv`(병종 상성)

병종(unit type) 아키타입을 **데이터로 정의**하는 단일 출처. 전투 스탯(at/df·이동력 mv·지휘범위 cmd_range·지휘보정 cmd_at/cmd_df)·병종 kind·HP·시야·원거리 여부·표시명이 모두 이 카탈로그 한 곳에서 나온다. 세력·영웅은 [FactionCatalog](factions.md), 맵에 놓이는 초기 유닛은 [UnitSpawns](unit-spawns.md)가 담당한다.
데이터는 `res://data/unit_types.csv`에서 **lazy-load** 한다([FactionCatalog]·[UnitSpawns]와 동일 패턴). 정적 API로만 노출한다. `importer="keep"`로 Godot 번역 자동임포트를 막는다.

**순수 class+count 모델**(M4-C) — 부대는 "아키타입 + 병력수"다. 개별 병사(Human) 스탯은 없다. Human RPG 계층(str·agi·luck 등)은 이 전환으로 제거됐고, 병종은 unit_types.csv 전투 스탯으로만 구분된다.

## 병종 아키타입 (`unit_types.csv`, 세력 공용)

**전투 스탯이 병종 행에 인라인**되어 있다(랑그릿사 ROM `class_stats.csv` 참조를 폐기하고 직접 튜닝). CSV 헤더:

```
id,name,kind,hp,vision,ranged,range,at,df,mv,cmd_range,cmd_at,cmd_df
```

- `id` — 아키타입 id. [`Party.troop_type`](../entities/Party.md#정체-identity)에 저장되어 [병합 가능 판정](../features/party-composition.md)(같은 병종끼리만)의 기준. 영웅은 `hero`.
- `name` — 병종 표시명(경보병/경궁병). 영웅(`hero`)은 표시명 없음(`FactionCatalog.hero_name` 사용).
- `kind` — 병종 상성 분류(`infantry`·`archer`·`cavalry`·`spear`·`hero`). 가위바위보 우위는 [`type_advantage.csv`](#병종-상성-type_advantagecsv)가 정의. `hero`는 상성 중립.
- `hp`·`vision` — 병력(HP 풀 시작값, 현재 10 균일)·fog 시야 반경(헥스).
- `ranged`·`range` — 원거리 여부(경궁병 true)·월드맵 공격거리(근접 0, 원거리 3).
- `at`·`df`·`mv`·`cmd_range`·`cmd_at`·`cmd_df` — 전투/이동/지휘 스탯. [LangResolver](../features/lang-battle.md)에 `UnitTypes.combat_stats(archetype)` 번들로 주입된다.

| 병종 | id | kind | at/df | 성격 |
| --- | --- | --- | --- | --- |
| (영웅) | `hero` | `hero` | 27/24 | 지휘관(표시명 없음 — `hero_name` 사용), cmd_range 4 |
| 경보병 | `light_infantry` | `infantry` | 23/21 | 근접, cmd_range 3 |
| 경궁병 | `light_archer` | `archer` | 23/21 | 원거리(부대 [공격거리](../entities/Party.md) 3), 경보병과 동일 base |

`kind`가 알려지지 않은 값(오타)이면 로드 시 `push_error`로 경고한다(참조 무결성 — `_KNOWN_KINDS`).

## 병종 상성 (`type_advantage.csv`)

`res://data/type_advantage.csv` — `kind` 가위바위보 표([TypeAdvantage](../features/lang-battle.md)가 소유). 컬럼: `attacker`·`defender`·`at`·`df`(우위 시 공격자에게 주는 보정). **우위 조합만 기재**하고 나머지는 0으로 간주. 기병>보병>창병>기병(사이클), 그리고 기/보/창 > 궁병(궁병은 원거리 이점 대가로 근접 모든 병종에 약함). `hero`는 미기재 → 공수 양쪽 중립. 현재 값은 전 우위 조합 공통 +4/+2.

- **미사용 행**: `cavalry`·`spear` 관련 행은 unit_types.csv에 해당 병종이 아직 없어 **미사용**이다(실전 조합은 `infantry>archer`뿐). 병종 추가 시 즉시 활성화된다.

## API

| 함수 | 반환 | 설명 |
| --- | --- | --- |
| `spec(arche) -> Dictionary` | 아키타입 스펙 | 없는 id면 빈 Dictionary |
| `display_name(arche) -> String` | 병종 표시명 | 영웅·미지면 빈 문자열 |
| `kind(arche) -> String` | 병종 상성 kind | 없으면 빈 문자열 |
| `max_hp(arche) -> int` | 최대 병력(HP) | 부대 생성 시 soldiers 시작값 |
| `vision(arche)` · `is_ranged(arche)` · `attack_range(arche)` · `movement(arche)` · `command_range(arche)` | — | fog 시야 · 원거리 여부 · 공격거리 · 이동력 · 지휘범위 |
| `base_at(arche)` · `base_df(arche)` -> int | 표시용 기본 공/방 | 상성·지휘보정 전 |
| `combat_stats(arche) -> Dictionary` | 전투 스탯 번들 | `{at, df, cmd_range, cmd_at, cmd_df, kind}` — [LangResolver](../features/lang-battle.md) 주입용 |

## 테스트 시나리오

`test/unit/test_unit_types.gd` · `test/unit/test_lang_bridge.gd`.

- [정상] `kind` — `light_infantry`=infantry, `light_archer`=archer, `hero`=hero(상성 중립); 미지 아키타입 → 빈 문자열
- [정상] `max_hp("light_infantry") == 10`; `is_ranged("light_archer")` 참, `light_infantry`/`hero` 거짓
- [정상] `display_name` — 경보병/경궁병; `hero`는 빈 문자열; 미지 → 빈 문자열
- [정상] 전투 스탯 — `hero` at27/df24/cmd_range4/cmd_at2/cmd_df4, `light_infantry` at23/df21/mv6/cmd_range3; `combat_stats("hero")` 번들 일치
- [경계] 미지 아키타입 → kind/이동력/HP 0·빈 값, 원거리 아님

## 관련

- [Factions (세력·영웅)](factions.md) · [Unit Spawns (초기 배치)](unit-spawns.md) · [Party (부대)](../entities/Party.md)
- 전투·클래스 통합은 [Lang Battle](../features/lang-battle.md)(UnitTypes).
