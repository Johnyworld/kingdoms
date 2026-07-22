# Kingdoms — 스펙 문서

> Godot 4.7 / GL Compatibility 렌더러로 개발 중인 2D 헥스 기반 게임.
> 이 문서는 **현재 구현된 스펙**의 요약(Summary)이자 목차(TOC)다.
> 상세 내용은 하위 문서를 참고한다.

## 개요

- **엔진**: Godot 4.7, GL Compatibility (전 플랫폼 배포 목표)
- **해상도**: 1920×1080 기준, `canvas_items` 스트레치 / `expand` 종횡비
- **좌표계**: 헥스 타일(16×16, LaPetiteTile). 지형 데이터/렌더 분리 → [Terrain](data/terrain.md)
- **진입점**: `res://scenes/splash/splash.tscn`
- **싱글턴(Autoload)**: `SceneManager` — 모든 씬 전환을 페이드로 처리

## 씬 흐름

```
Splash ──(자동/입력 스킵)──▶ Title ──(시작)────▶ Game ──(부대 전투)──▶ Lang Battle (정식 전투 오버레이)
                                  └──(설정)─────▶ (준비 중)
```

## 문서 목차

### 엔티티 (`entities/`)
게임 내 데이터 모델. 각 문서에 속성(properties) 목록을 정리한다.

- [Party](entities/Party.md) — 부대 (맵에서 움직이는 유닛 · 클래스+병력수(soldiers) · 이동력·시야는 클래스 기반 · 토큰 색 · **종류 kind(영웅/일반)** · **소속 영웅 lord**)
- [Building](entities/Building.md) — 맵에 배치된 건물 (7헥스 · 종류 · 시야 · 소속 영지)
- [Territory](entities/Territory.md) — 영지 (이름 · 모든 자원 보유 · 소속 건물)
- [Faction](entities/Faction.md) — 세력 (이름 · 색상 · 소속 영지)

### 기능 (`features/`)
동작하는 기능 정의.

- [SceneManager (씬 전환)](features/scene-transition.md)
- [Splash (스플래시)](features/splash.md)
- [Title (타이틀 메뉴)](features/title.md)
- [Tile Gallery (타일 보기)](features/tile-gallery.md) — 사용 가능한 타일을 격자+라벨로 훑어보는 읽기 전용 검사 화면(타이틀 "타일 보기" 버튼)
- [Map & Camera (맵과 카메라)](features/map-and-camera.md)
- [Parties (부대 배치)](features/parties.md) — 랑그릿사식 편제: 세력마다 영웅부대 4 + 부하부대 12(경보병2·경궁병1/영웅) = 16부대, 4세력 맵 64부대. 거점 중심에 경보병 1부대(방어)
- [NPC Bases (NPC 세력 거점)](features/npc-bases.md) — NPC 세력별 수도 영지·캠프 배치, 안개(발견 후 상시 표시)·클릭 정보
- [NPC Movement (NPC 이동 AI)](features/npc-movement.md) — 턴 종료 시 NPC가 도달 가능한 가장 먼 칸으로 무작위 이동
- [Selection & Movement (선택과 이동)](features/selection-and-movement.md)
- [Edge Barriers (경계 장벽 — 강·벽)](features/edge-barriers.md)
- [Party Info (부대 정보 패널)](features/party-info.md) — 부대 클릭 시 우측 상단에 이름·이동력·시야·지휘관·병력 표시
- [Party Action Menu (부대 행동 메뉴)](features/party-action-menu.md) — 토큰 근처 메뉴 [사격](+대기/취소/소속) + 적 팝업 [공격][사격], 근접 승리 점령
- [Party Roster (부대 일람)](features/party-roster.md) — 우측 상단 상시 목록, 항목 클릭 시 그 부대로 카메라 이동
- [Fog of War (전장의 안개)](features/fog-of-war.md)
- [Camp Menu (캠프 메뉴)](features/camp-menu.md) — 캠프 클릭 시 영지 자원·건축 메뉴
- [Building Info (건물 정보 패널)](features/building-info.md) — 농장 등 건물 클릭 시 우측 상단에 종류·상태·시야·영지·생산 표시 + 철거(확인 다이얼로그)
- [Confirm Dialog (확인 다이얼로그)](features/confirm-dialog.md) — 되돌리기 어려운 동작 전 확인받는 범용 모달(첫 사용처: 건물 철거)
- [Modal (공용 모달 기반)](features/modal.md) — 딤 백드롭 + 제목바 + 우측 상단 X, 콘텐츠 주입(컴포지션), 모달 스택으로 지도 입력 차단·ESC·중첩 관리(소비자: 캠프 메뉴·확인 다이얼로그·소속 모달)
- [Turn (턴)](features/turn.md) — 턴 종료 · 부대 1턴 1이동 · 영지 자원 수입 · 건설 진행
- [Lang Battle (랑그릿사 1 오마주 전투 — 게임 정식 전투)](features/lang-battle.md) — 게임의 **정식 전투 시스템**(구 battle.gd 오버레이 대체). 모든 부대 전투가 이 오버레이로 열린다. Resolver(순수 계산)/Presenter(연출) 분리, 원본 RNG·상성·지휘보정·병력바 재현
- [Construction (건축)](features/building.md) — 자원 차감 · 건설 중 상태 · 배치 유효성 · 건설 모드 UI(리스트·배치)
- [Primary Production (1차 생산 건물)](features/production.md) — 지형 위 자원 채취 건물(농장·식량 / 벌목소·목재 / 철광·철 / 금광·금). 생산포인트(1÷거리, 거리 기반) 모델 · 거점 배정/변경 · 배치 규칙(건물∪부대 시야 · 1차=지형+캠프 / 기타=마을회관 인접). 자원 4종 체제
- [Camp Capture (캠프 점령·방어)](features/camp-capture.md) — 거점 방어=중심 타일 점거 부대(창발, 별도 상태 없음)·"수비 N" 배지 / 인접한 적 거점 점령 → [흡수](영지 획득)/[파괴](제거) 선택
- [Party Composition (부대 편성)](features/party-composition.md) — 다중 부대 + 선택, 병합으로 재조직(분할은 M4-C로 제거)
- [Party Lord (소속 영웅)](features/party-lord.md) — 일반부대의 소속 영웅부대 설정/해제 UI([소속] 버튼 → 모달, 소속=인접 영웅 필요·해제 자유·턴 무소비)
- [Squad Stance (부대 작전 — 이동 후 하위부대 명령)](features/squad-stance.md) — 영웅 이동 직후 작전 메뉴 [추종][대기][교전][돌격]로 하위부대 일괄 통솔. 교전=최근접 적 접근·신중 전투, 돌격=목표 1지점 어택무브(공격적)
- [Command Range (지휘 범위 버프)](features/command-range.md) — 소속 하위부대가 영웅(`lord`) 지휘 범위(lang 클래스 `cmd_range`, 3~4칸) 안인지 판정해 맵 배지 표시. 전투 배율 효과는 RPG 전투 수학 폐기로 **현재 미반영**(lang 연동 미정), 모든 세력
- [Victory & Defeat (승패)](features/victory.md) — 세력 소멸(10턴 유예)로만 승패 · 정복 승리 · 결과 오버레이 · 타이틀 복귀

### 데이터 (`data/`)
캐릭터 · 아이템 · 자원 등의 리스트.

- [Resources (자원)](data/resources.md) — 4종(목재·식량·철·금) + 인구(병력 예약)
- [Units (유닛·부대 카탈로그)](data/units.md) — 세력별 영웅 4명 + 병종 아키타입(경보병·경궁병 10인). 부대 이분화(영웅/일반). game.gd가 여기서 부대 생성. **데이터는 `res://data/*.csv`**(factions·heroes·units), 세력 `start_corner`로 거점 모서리 배치
- [Buildings (건물 종류)](data/buildings.md)
- [Terrain (지형)](data/terrain.md) — 초원·숲·습지·산·사막·물, 칸당 진입비용(초원 1·숲 2·습지 3·산/물 불가)

## 파일 매핑

| 영역 | 스크립트 |
| --- | --- |
| 씬 전환 | `autoload/scene_manager.gd` |
| 모달 스택(싱글턴) | `autoload/modal_stack.gd` |
| 공용 모달 기반 | `scenes/modal/modal.gd` |
| 스플래시 | `scenes/splash/splash.gd` |
| 타이틀 | `scenes/title/title.gd` |
| 게임 루트 | `scenes/game/game.gd` |
| 범위 오버레이 | `scenes/game/range_overlay.gd` |
| 건설 미리보기 오버레이 | `scenes/game/build_preview.gd` |
| 건설 가능 영역 오버레이 | `scenes/game/build_area_overlay.gd` |
| 전장의 안개 | `scenes/game/fog.gd` |
| NPC 이동 AI | `scenes/game/npc_ai.gd` |
| 랑그릿사 전투 오버레이 | `scenes/lang_battle/lang_battle.gd` |
| 전장 렌더러(픽셀아트) | `scenes/lang_battle/lang_battlefield.gd` |
| 전장 순수 기하/분배 수학 | `scenes/lang_battle/lang_field_math.gd` |
| 부대↔lang 매핑 | `scenes/lang_battle/lang_bridge.gd` |
| 유닛 카탈로그(클래스·HP) | `scenes/party/game_units.gd` |
| 부대(맵 토큰) | `scenes/party/party.gd` |
| 부대 정보 패널 | `scenes/party/party_info.gd` |
| 부대 행동 메뉴 | `scenes/party/party_action_menu.gd` |
| 부대 일람 | `scenes/party/party_roster.gd` |
| 유닛·부대 카탈로그 | `scenes/party/unit_types.gd` |
| 건물 | `scenes/building/building.gd` |
| 건물 정보 패널 | `scenes/building/building_info.gd` |
| 확인 다이얼로그 | `scenes/game/confirm_dialog.gd` |
| 건물 종류 카탈로그 | `scenes/building/building_types.gd` |
| 건물 렌더러(거점 오토타일·세력색) | `scenes/building/building_renderer.gd` |
| 건설 배치 유틸 | `scenes/building/build_planner.gd` |
| 영지 | `scenes/territory/territory.gd` |
| 캠프 메뉴 | `scenes/camp/camp_menu.gd` |
| 세력 | `scenes/faction/faction.gd` |
| 턴 매니저 | `scenes/turn/turn_manager.gd` |
| 턴 HUD | `scenes/turn/turn_hud.gd` |
| 지형 카탈로그 | `scenes/game/terrain.gd` |
| 지형 렌더러 | `scenes/game/terrain_renderer.gd` |
| 지형 데이터 타일셋 | `tiles/terrain_tileset.tres` (숨김 데이터 레이어) |
| 지형 비주얼 타일셋 | `assets/tiles/lapetite/Tilesets/*.tres` (LaPetiteTile 오토타일) |
| 게임 튜닝 데이터(CSV) | `data/factions.csv` · `data/heroes.csv` · `data/units.csv`(병종+전투 스탯 인라인) · `data/type_advantage.csv`(병종 상성) (스프레드시트 편집, `importer="keep"`) |

---

## 추천 스펙 (미구현 · 제안)

향후 문서화/구현을 고려할 만한 항목. 지금 당장 만들 필요는 없고, 방향성 참고용이다.

- **`features/settings.md`** — 타이틀의 "설정" 버튼이 아직 `TODO`다. 해상도 · 사운드 · 언어 등 저장 가능한 설정 화면을 정의하면 좋다.
- **`features/save-load.md`** — 세이브/로드. 게임 진행(주인공 위치, 자원, 탐험된 안개)을 직렬화하는 규칙.
- **턴/행동력 확장** — 기본 턴 시스템([features/turn.md](features/turn.md))은 도입됨(턴 종료 · 1턴 1이동 · 자원 수입). 남은 것은 행동력(AP) · 공격/전투 행동 · 적 턴(AI) 등으로의 확장이다.
- **건축 확장** — 건축 코어 로직·리스트 UI·건설 모드 배치([features/building.md](features/building.md))·완성 건물 시야의 fog 반영([features/fog-of-war.md](features/fog-of-war.md))·**캠프 건설**(새 영지 생성)·**철거**([building-info.md#철거](features/building-info.md#철거) — `demolish_refund` 자재 환급)까지 구현됨. 남은 세부: **철거 확인 다이얼로그**, **캠프(거점) 철거**(영지 상실), **건설 중 부분 환급**([building-info.md 미구현](features/building-info.md)).
- **`entities/Enemy.md`** — 공격 범위가 있으니 적/전투 대상 엔티티가 자연스러운 다음 단계.
- **`features/input-scheme.md`** — 키보드/마우스/게임패드/터치 입력 매핑을 한곳에 정리 (전 플랫폼 배포 목표에 맞춤).
