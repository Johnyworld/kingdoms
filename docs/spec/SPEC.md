# Kingdoms — 스펙 문서

> Godot 4.7 / GL Compatibility 렌더러로 개발 중인 2D 헥스 기반 게임.
> 이 문서는 **현재 구현된 스펙**의 요약(Summary)이자 목차(TOC)다.
> 상세 내용은 하위 문서를 참고한다.

## 개요

- **엔진**: Godot 4.7, GL Compatibility (전 플랫폼 배포 목표)
- **해상도**: 1920×1080 기준, `canvas_items` 스트레치 / `expand` 종횡비
- **좌표계**: 뾰족한 위/아래(pointy-top) 헥스 타일, 타일 크기 64×46
- **진입점**: `res://scenes/splash/splash.tscn`
- **싱글턴(Autoload)**: `SceneManager` — 모든 씬 전환을 페이드로 처리

## 씬 흐름

```
Splash ──(자동/입력 스킵)──▶ Title ──(시작)──▶ Game
                                  └──(설정)──▶ (준비 중)
```

## 문서 목차

### 엔티티 (`entities/`)
게임 내 데이터 모델. 각 문서에 속성(properties) 목록을 정리한다.

- [Party](entities/Party.md) — 부대 (맵에서 움직이는 유닛 · 멤버 Human 보유 · 이동력=min·시야=max · 토큰 색)
- [Human](entities/Human.md) — 사람 (능력치 · 자원, 순수 데이터). 주인공은 부대의 멤버
- [Building](entities/Building.md) — 맵에 배치된 건물 (7헥스 · 종류 · 시야 · 소속 영지)
- [Territory](entities/Territory.md) — 영지 (이름 · 모든 자원 보유 · 소속 건물)
- [Faction](entities/Faction.md) — 세력 (이름 · 색상 · 소속 영지)

### 기능 (`features/`)
동작하는 기능 정의.

- [SceneManager (씬 전환)](features/scene-transition.md)
- [Splash (스플래시)](features/splash.md)
- [Title (타이틀 메뉴)](features/title.md)
- [Map & Camera (맵과 카메라)](features/map-and-camera.md)
- [Parties (부대 배치)](features/parties.md) — 유닛 카탈로그에서 플레이어 부대 + NPC 부대 3개 생성·배치
- [NPC Bases (NPC 세력 거점)](features/npc-bases.md) — NPC 세력별 수도 영지·캠프 배치, 안개(발견 후 상시 표시)·클릭 정보
- [NPC Movement (NPC 이동 AI)](features/npc-movement.md) — 턴 종료 시 NPC가 도달 가능한 가장 먼 칸으로 무작위 이동
- [Selection & Movement (선택과 이동)](features/selection-and-movement.md)
- [Party Info (부대 정보 패널)](features/party-info.md) — 부대 클릭 시 우측 상단에 이름·이동력·시야·멤버 표시
- [Party Action Menu (부대 행동 메뉴)](features/party-action-menu.md) — 토큰 근처 메뉴 [사격][휴식][경계] + 적 팝업 [공격][사격], 휴식/경계 회복·버프, 근접 승리 점령
- [Party Roster (부대 일람)](features/party-roster.md) — 우측 상단 상시 목록, 항목 클릭 시 그 부대로 카메라 이동
- [Fog of War (전장의 안개)](features/fog-of-war.md)
- [Camp Menu (캠프 메뉴)](features/camp-menu.md) — 캠프 클릭 시 영지 자원·건축 메뉴
- [Building Info (건물 정보 패널)](features/building-info.md) — 농장 등 건물 클릭 시 우측 상단에 종류·상태·시야·영지·생산 표시 + 철거(확인 다이얼로그)
- [Confirm Dialog (확인 다이얼로그)](features/confirm-dialog.md) — 되돌리기 어려운 동작 전 확인받는 범용 모달(첫 사용처: 건물 철거)
- [Turn (턴)](features/turn.md) — 턴 종료 · 부대 1턴 1이동 · 영지 자원 수입 · 건설 진행
- [Combat (전투 판정)](features/combat.md) — 능력치 기반 1회 공방·3회 교대 교전 순수 로직
- [Battle (전투씬·개시·복귀)](features/battle.md) — 인접 적 클릭 개시 → 실시간 관전 오버레이 → 사상자 반영·복귀
- [Raid (약탈)](features/raid.md) — 전투로 전멸한 적 부대의 화물·전사자 장비를 승자가 노획(플레이어=선택 패널 / NPC=자동 전량)
- [Equipment (장비 관리)](features/equipment.md) — 노획 장비를 멤버에게 장착·탈착(무기3·방어구4·방패1 슬롯, 스왑 없음). 행동 메뉴 [장비]로 여는 모달
- [Trade (상거래)](features/trade.md) — 캠프 메뉴에서 부대 노획 장비·화물을 금으로 판매하고, 금으로 장비를 구매(영지 금고)
- [Status Effects (상태이상)](features/status-effects.md) — 치명타 연동 출혈·기절 (전투씬 내, 초 기반)
- [Combat Feedback (전투 연출)](features/combat-feedback.md) — 대미지 숫자·타격 반짝임·흔들림·돌진·상태이상 텍스트·사망 넉백
- [Construction (건축)](features/building.md) — 자원 차감 · 건설 중 상태 · 배치 유효성 · 건설 모드 UI(리스트·배치)
- [Camp Capture (캠프 점령)](features/camp-capture.md) — 인접한 적 거점 점령 → [흡수](영지 획득)/[파괴](제거) 선택
- [Garrison / 주둔 (거점 수비)](features/garrison.md) — 수비대=부대, 거점 중심 타일 주둔 부대가 방어(초기 4명), 주둔/주둔 종료·주둔 중 사격
- [Wall / 성벽 (거점 방어 구조물)](features/wall.md) — 마을회관·성 성벽(`wall_level`) 적 접근 차단 + 사다리 공성(3턴·밀기 15%·통로 돌파)
- [Siege Engines / 공성병기 (부대 소속 공성 유닛)](features/siege-engines.md) — 투석기(공격 50·HP 60) 등 인구 비소모 재사용 유닛. 공성 작업장 생산·견인 이동(2·사람 4명+)·[투석](사거리 4~5·선택 모드)으로 성벽(내구도 180)을 랜덤 피해(30~70)로 깎아 평균 3~6발에 붕괴하거나, 적 부대를 battle.gd 통합 전투에서 폭격(최대 5명·유닛별 명중·양쪽 투석기 상호 반격). 성벽 구조물 전투원화·NPC AI는 후속
- [Party Composition (부대 편성)](features/party-composition.md) — 다중 부대 + 선택, 분할·병합으로 재조직
- [Victory & Defeat (승패)](features/victory.md) — 세력 소멸(10턴 유예)로만 승패 · 정복 승리 · 결과 오버레이 · 타이틀 복귀

### 데이터 (`data/`)
캐릭터 · 아이템 · 자원 등의 리스트.

- [Resources (자원)](data/resources.md)
- [Stats (능력치 정의)](data/stats.md)
- [Units (유닛·부대 카탈로그)](data/units.md) — 세력별 부대·멤버(이름·능력치·색) 데이터. game.gd가 여기서 부대 생성
- [Items (무기·방어구)](data/items.md) — 무기·방어구 카탈로그 + 상성표. 전투 AT·DF·상성에 사용
- [Buildings (건물 종류)](data/buildings.md)
- [Siege Units (공성 유닛 카탈로그)](data/siege-units.md) — 투석기 등 공성 유닛(`SiegeTypes`). 이름·견인 이동력·생산 비용
- [Terrain (지형)](data/terrain.md) — 초원·숲·습지·산·사막, 지형별 이동 규칙(산 불가·숲 ceil·습지 floor)

## 파일 매핑

| 영역 | 스크립트 |
| --- | --- |
| 씬 전환 | `autoload/scene_manager.gd` |
| 스플래시 | `scenes/splash/splash.gd` |
| 타이틀 | `scenes/title/title.gd` |
| 게임 루트 | `scenes/game/game.gd` |
| 범위 오버레이 | `scenes/game/range_overlay.gd` |
| 건설 미리보기 오버레이 | `scenes/game/build_preview.gd` |
| 건설 가능 영역 오버레이 | `scenes/game/build_area_overlay.gd` |
| 전장의 안개 | `scenes/game/fog.gd` |
| NPC 이동 AI | `scenes/game/npc_ai.gd` |
| 전투 판정 | `scenes/combat/combat_resolver.gd` |
| 상태이상(순수) | `scenes/combat/status_effects.gd` |
| 전투 연출(순수 텍스트 매핑) | `scenes/combat/hit_feedback.gd` |
| 전투씬 오버레이 | `scenes/combat/battle.gd` |
| 전투 공간 판정 | `scenes/combat/battle_field.gd` |
| 헤드리스 전투 결산 | `scenes/combat/battle_sim.gd` |
| 아이템(무기·방어구) 카탈로그 | `scenes/item/item_types.gd` |
| 자원 가치 카탈로그 | `scenes/resource/resource_types.gd` |
| 부대(맵 토큰) | `scenes/party/party.gd` |
| 부대 정보 패널 | `scenes/party/party_info.gd` |
| 부대 행동 메뉴 | `scenes/party/party_action_menu.gd` |
| 부대 일람 | `scenes/party/party_roster.gd` |
| 약탈 패널 | `scenes/loot/loot_menu.gd` |
| 장비 관리 모달 | `scenes/equip/equip_menu.gd` |
| 사람(데이터) | `scenes/human/human.gd` |
| 유닛·부대 카탈로그 | `scenes/party/unit_types.gd` |
| 건물 | `scenes/building/building.gd` |
| 건물 정보 패널 | `scenes/building/building_info.gd` |
| 확인 다이얼로그 | `scenes/game/confirm_dialog.gd` |
| 건물 종류 카탈로그 | `scenes/building/building_types.gd` |
| 건설 배치 유틸 | `scenes/building/build_planner.gd` |
| 영지 | `scenes/territory/territory.gd` |
| 캠프 메뉴 | `scenes/camp/camp_menu.gd` |
| 세력 | `scenes/faction/faction.gd` |
| 턴 매니저 | `scenes/turn/turn_manager.gd` |
| 턴 HUD | `scenes/turn/turn_hud.gd` |
| 지형 카탈로그 | `scenes/game/terrain.gd` |
| 지형 타일셋 | `tiles/terrain_tileset.tres` |

---

## 추천 스펙 (미구현 · 제안)

향후 문서화/구현을 고려할 만한 항목. 지금 당장 만들 필요는 없고, 방향성 참고용이다.

- **`features/settings.md`** — 타이틀의 "설정" 버튼이 아직 `TODO`다. 해상도 · 사운드 · 언어 등 저장 가능한 설정 화면을 정의하면 좋다.
- **`features/save-load.md`** — 세이브/로드. 게임 진행(주인공 위치, 자원, 탐험된 안개)을 직렬화하는 규칙.
- **턴/행동력 확장** — 기본 턴 시스템([features/turn.md](features/turn.md))은 도입됨(턴 종료 · 1턴 1이동 · 자원 수입). 남은 것은 행동력(AP) · 공격/전투 행동 · 적 턴(AI) 등으로의 확장이다.
- **건축 확장** — 건축 코어 로직·리스트 UI·건설 모드 배치([features/building.md](features/building.md))·완성 건물 시야의 fog 반영([features/fog-of-war.md](features/fog-of-war.md))·**캠프 건설**(새 영지 생성)·**철거**([building-info.md#철거](features/building-info.md#철거) — `demolish_refund` 자재 환급 + `required_pop` 인구 반환)까지 구현됨. 남은 세부: **철거 확인 다이얼로그**, **캠프(거점) 철거**(영지 상실), **건설 중 부분 환급**([building-info.md 미구현](features/building-info.md)).
- **`entities/Enemy.md`** — 공격 범위가 있으니 적/전투 대상 엔티티가 자연스러운 다음 단계.
- **`data/items.md`** — 아이템/장비 리스트 (능력치 보정 등).
- **`features/input-scheme.md`** — 키보드/마우스/게임패드/터치 입력 매핑을 한곳에 정리 (전 플랫폼 배포 목표에 맞춤).
