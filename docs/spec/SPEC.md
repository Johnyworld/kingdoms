# Kingdoms — 스펙 문서

> Godot 4.7 / GL Compatibility 렌더러로 개발 중인 2D 헥스 기반 게임.
> 이 문서는 **현재 구현된 스펙**의 요약(Summary)이자 목차(TOC)다.
> 상세 내용은 하위 문서를 참고한다.

## 개요

- **엔진**: Godot 4.7, GL Compatibility (전 플랫폼 배포 목표)
- **해상도**: 1280×720 기준, `canvas_items` 스트레치 / `expand` 종횡비
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

- [Human](entities/Human.md) — 사람 (능력치 · 자원). 주인공은 이 Human의 객체
- [Building](entities/Building.md) — 맵에 배치된 건물 (7헥스 · 종류 · 시야 · 소속 영지)
- [Territory](entities/Territory.md) — 영지 (이름 · 모든 자원 보유 · 소속 건물)
- [Faction](entities/Faction.md) — 세력 (이름 · 색상 · 소속 영지)

### 기능 (`features/`)
동작하는 기능 정의.

- [SceneManager (씬 전환)](features/scene-transition.md)
- [Splash (스플래시)](features/splash.md)
- [Title (타이틀 메뉴)](features/title.md)
- [Map & Camera (맵과 카메라)](features/map-and-camera.md)
- [Selection & Movement (선택과 이동)](features/selection-and-movement.md)
- [Fog of War (전장의 안개)](features/fog-of-war.md)
- [Camp Menu (캠프 메뉴)](features/camp-menu.md)
- [Turn (턴)](features/turn.md) — 턴 종료 · 유닛 1턴 1이동 · 영지 자원 수입 · 건설 진행
- [Construction (건축)](features/building.md) — 자원 차감 · 건설 중 상태 · 배치 유효성 · 건설 모드 UI(리스트·배치)

### 데이터 (`data/`)
캐릭터 · 아이템 · 자원 등의 리스트.

- [Resources (자원)](data/resources.md)
- [Stats (능력치 정의)](data/stats.md)
- [Buildings (건물 종류)](data/buildings.md)

## 파일 매핑

| 영역 | 스크립트 |
| --- | --- |
| 씬 전환 | `autoload/scene_manager.gd` |
| 스플래시 | `scenes/splash/splash.gd` |
| 타이틀 | `scenes/title/title.gd` |
| 게임 루트 | `scenes/game/game.gd` |
| 범위 오버레이 | `scenes/game/range_overlay.gd` |
| 건설 미리보기 오버레이 | `scenes/game/build_preview.gd` |
| 전장의 안개 | `scenes/game/fog.gd` |
| 사람(주인공) | `scenes/human/human.gd` |
| 건물 | `scenes/building/building.gd` |
| 건물 종류 카탈로그 | `scenes/building/building_types.gd` |
| 건설 배치 유틸 | `scenes/building/build_planner.gd` |
| 영지 | `scenes/territory/territory.gd` |
| 캠프 메뉴 | `scenes/camp/camp_menu.gd` |
| 세력 | `scenes/faction/faction.gd` |
| 턴 매니저 | `scenes/turn/turn_manager.gd` |
| 턴 HUD | `scenes/turn/turn_hud.gd` |
| 초원 타일셋 | `tiles/grass_tileset.tres` |

---

## 추천 스펙 (미구현 · 제안)

향후 문서화/구현을 고려할 만한 항목. 지금 당장 만들 필요는 없고, 방향성 참고용이다.

- **`features/settings.md`** — 타이틀의 "설정" 버튼이 아직 `TODO`다. 해상도 · 사운드 · 언어 등 저장 가능한 설정 화면을 정의하면 좋다.
- **`features/save-load.md`** — 세이브/로드. 게임 진행(주인공 위치, 자원, 탐험된 안개)을 직렬화하는 규칙.
- **턴/행동력 확장** — 기본 턴 시스템([features/turn.md](features/turn.md))은 도입됨(턴 종료 · 1턴 1이동 · 자원 수입). 남은 것은 행동력(AP) · 공격/전투 행동 · 적 턴(AI) 등으로의 확장이다.
- **건축 확장** — 건축 코어 로직·리스트 UI·건설 모드 배치([features/building.md](features/building.md))는 모두 구현됨. 남은 것은 **완성 농장의 시야를 fog에 반영**하는 작업, **캠프 건설**(새 영지 생성), **철거**(demolish_refund)다.
- **`data/terrain.md`** — 현재는 초원 단일 타일. 지형 종류(숲/산/물)와 이동 비용 · 시야 차단 규칙을 정의하면 맵이 풍부해진다.
- **`entities/Enemy.md`** — 공격 범위가 있으니 적/전투 대상 엔티티가 자연스러운 다음 단계.
- **`data/items.md`** — 아이템/장비 리스트 (능력치 보정 등).
- **`features/input-scheme.md`** — 키보드/마우스/게임패드/터치 입력 매핑을 한곳에 정리 (전 플랫폼 배포 목표에 맞춤).
