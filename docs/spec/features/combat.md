# Feature: Combat Resolution (전투 판정 로직)

> 스크립트: `scenes/combat/combat_resolver.gd` (`class_name CombatResolver extends RefCounted`)

두 [부대](../entities/Party.md)의 [멤버](../entities/Human.md)가 벌이는 교전을 **능력치로 판정하는 순수 로직**이다. 씬·시각 요소 없이 데이터만 다뤄 시드 RNG로 결정적으로 테스트한다(HexGrid·ClickRouter와 같은 헬퍼 패턴).

기획 원본 `docs/table/시스템/전투.md`(랑그릿사식)의 규칙 중 **현재 구현된 능력치·장비로 가능한 부분**을 옮겼다. 이 판정 로직을 시간 기반 전투씬([Battle](battle.md))이 사용한다(이동·타겟팅·사상자 반영은 거기서 구현).

## 계산 스탯

[능력치](../data/stats.md)와 착용 [장비](../data/items.md)를 쓴다. 무기·방어구·상성은 구현됐고, 방패·무게·지형은 아직 미반영이다.

| 값 | 식 | 비고 |
| --- | --- | --- |
| 공격력 AT | `무기 공격력 + floor(힘 / 5)` | 무기는 [ItemTypes](../data/items.md). 여러 무기 중 **그 전투에서 쓰는 무기**(근접=주무기, 원거리=활)로 계산. 맨몸이면 무기 0. **`alert`면 ×1.2(내림)** |
| 방어력 DF | `Σ 착용 방어구 방어력 + 방패 방어력` | `ItemTypes.total_defense` + `shield_defense`. **`alert`면 ×1.2(내림)** |
| 막기(%) | 방패 `block` | 명중해도 이 확률로 피해 완전 무효 |
| 상성배율 | `AFFINITY[방어자 방어구분류][공격자 데미지타입]` | 방어구분류 = 방어력 최대 조각. 없으면 `1.0` |
| 회피율(%) | `민첩 × 0.5 − 총장비무게 × 0.3` | 총장비무게 = **보유 무기 전부** + 방어구 + 방패 무게(`equip_weight`). 무기 여럿을 들면 그만큼 무겁다. 지형 보정 `미구현` |

`attack_power`·`hit_damage`·`resolve_hit`·`resolve_engagement`는 사용할 무기 id를 **선택 인자**로 받는다(생략 시 `ItemTypes.primary_weapon` = 주무기). 원거리 전투에서 활로 쏠 때는 호출부가 활 id를 넘긴다.
| 명중(%) | `90 − 회피율` | 상한 clamp 없음 — 0 이하면 무조건 빗나감 |
| 치명타(%) | `행운 × 0.5` | |

## 1회 공방 판정 (`resolve_hit`)

한 번의 타격을 다음 순서로 처리한다. `rng: RandomNumberGenerator`로 확률을 굴린다.

1. **명중 판정** — `rng.randf()×100 < 명중(%)`이면 명중. 빗나가면 피해 0.
2. **방패 막기** — 명중 시 `rng.randf()×100 < 방어자 막기(%)`이면 **막기 성공 → 피해 0(완전 무효)**. 이때 치명타·피해 계산을 건너뛴다.
3. **치명타 판정** — 막지 못하면 `rng.randf()×100 < 치명타(%)`이면 치명타(배율 1.5), 아니면 1.0.
4. **피해** — `피해 = floor(max(1, AT(공격자) − DF(방어자)) × 상성배율 × 치명배율)`. 상성배율은 방어자 방어구분류 × 공격자 데미지타입([ItemTypes](../data/items.md)).
5. **생명점 차감** — `대상 생명점 − 피해`. 0 이하면 전투불능(사망).

- 반환: `{hit, blocked, crit, damage, hp(차감 후), dead, inflict}`. 막기 성공이면 `blocked=true, damage=0`.
- **`inflict`** — 치명타로 피해가 들어간 타격이면 부여할 [상태이상](status-effects.md) id(`참격→"bleed"`, `타격→"stun"`), 그 외에는 `""`. 빗나감·방패 막기·비치명은 모두 `""`. 부여 계산은 `StatusEffects.on_crit(사용무기 데미지타입)`.

## 공격 간격 (`attack_interval`, 시간 기반 전투)

전투씬([Battle](battle.md))은 정해진 시간(10초) 동안 각 유닛이 **자기 공격 간격마다 1회 공격**(`resolve_hit`)한다. 교전을 3공방으로 묶던 옛 `resolve_engagement`는 폐기했다.

- `attack_interval(h, weapon := "") -> float` = `max(0.4, 무기 기본 공격속도 × (1 − 민첩 × 0.005))`.
  - 무기 기본 공격속도(초)는 [ItemTypes](../data/items.md) `weapon_attack_speed`. `weapon` 생략 시 주무기.
  - **민첩이 높을수록 공격 간격이 짧다**(빠르다). 하한 `0.4`초(`MIN_ATTACK_INTERVAL`).
  - 예: 검(기본 2.0) · 민첩 0 → 2.0초 / 민첩 60 → `2.0 × 0.7 = 1.4`초.
- 한 전투에서의 공격 횟수는 `10초 ÷ 공격 간격`으로 자연히 정해진다(무기·민첩에 따라 다름).

## 미구현 (다음 슬라이스/시스템)

- **치명타 연동 상태이상**은 [status-effects.md](status-effects.md)로 도입됨(참격→출혈, 타격→기절, 전투씬 내 완결). 나머지 상태이상·월드맵 이월은 거기 미구현 목록 참조.
- **마법 전용 위력 공식** — 마법 무기도 물리와 같은 `AT − DF` 공식을 따르되 데미지타입 `마법`으로 상성만 다르게 적용한다. 기획의 "마법은 물리 방어 무시 + 마법 기능치" 별도 공식은 `미구현`.
- **지형 전투 보정(방어·회피·시야)·지휘관 지휘범위 보너스·스태미나·사기 보정** — `미구현`.

## 테스트 시나리오

`test/unit/test_combat_resolver.gd`. Human은 능력치를 직접 설정해 만든다.

### 계산 스탯 (결정적, RNG 없음)
- [정상] `attack_power` = `무기공격력 + floor(힘/5)` — 맨몸 힘 78 → 15, 검(14) 장착 → 29
- [정상] `attack_power`에 무기 id를 명시하면 그 무기로 계산 — 검+활 소지자에 `"bow"` 지정 시 활(12) 기준
- [정상] `defense` = `Σ 방어구 방어력 + 방패 방어력` — 맨몸 0, 가죽 세트면 합, 방패 들면 +방패 방어력
- [정상] `block_chance` = 방패 막기(%) — 방패 없으면 0
- [정상] `evasion` = `민첩 × 0.5 − 총장비무게 × 0.3` — 맨몸(무게 0)이면 `민첩 × 0.5`
- [정상] `equip_weight` = **보유 무기 전부**+방어구합+방패 무게 (맨몸 0) — 검+활이면 두 무기 무게 합산
- [정상] 무거운 장비는 회피를 낮춘다(같은 민첩에서 중갑+대형방패 < 경장)
- [정상] `hit_chance` = `90 − 대상 회피율`
- [정상] `crit_chance` = `행운 × 0.5`
- [정상] `hit_damage(공격자, 방어자, crit)` = `floor(max(1, AT−DF) × 상성 × (1.5 if crit else 1.0))` — 최소 1
- [정상] 상성 반영 — 마법 무기 vs 판금(1.3) > vs 맨몸(1.0); 참격 vs 사슬(0.7) 감소
- [정상] `alert` 버프 — `alert=true`면 `attack_power`·`defense`가 ×1.2(내림), `false`면 원값 ([경계](party-action-menu.md))

### 1회 공방 (`resolve_hit`)
- [경계] 회피율이 매우 높아(민첩 200 → 회피 100 → 명중 −10) 항상 빗나감 → `hit=false`, 피해 0, hp 불변
- [정상] 같은 시드 → 같은 결과(결정적)
- [정상] 명중 시 `hp = 이전 hp − damage`, `dead = hp ≤ 0`
- [정상] 방패 막기 — 항상 명중(회피 음수)하는 방어자에 방패를 들리고 여러 시드를 돌리면, **막힌 타격**(`blocked=true, damage=0, hp 불변`)과 **막히지 않은 타격**(`damage>0`)이 모두 나온다
- [경계] 방패 없으면 `blocked`는 항상 `false`
- [정상] 치명타 명중 시 `inflict` — 참격 무기 → `"bleed"`, 타격 무기 → `"stun"` ([status-effects.md](status-effects.md))
- [경계] 비치명·빗나감·막힘이면 `inflict == ""`

### 공격 간격 (`attack_interval`)
- [정상] 민첩 0 → 무기 기본 공격속도 그대로(검 2.0초)
- [정상] 민첩 60 → 검 `2.0 × 0.7 = 1.4`초(민첩이 간격을 줄인다)
- [경계] 극단적으로 높은 민첩이어도 하한 `0.4`초 아래로 못 감
- [정상] 무기 id를 명시하면 그 무기 공격속도, 생략 시 주무기

## 관련

- 능력치 정의는 [Stats](../data/stats.md), 멤버는 [Human](../entities/Human.md), 부대는 [Party](../entities/Party.md).
- 기획 원본(전체 비전): `docs/table/시스템/전투.md` (랑그릿사식 — 대부분 미구현).
