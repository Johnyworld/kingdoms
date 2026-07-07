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

- [Character](entities/Character.md) — 주인공 캐릭터 (능력치 · 자원)
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
| 전장의 안개 | `scenes/game/fog.gd` |
| 주인공 | `scenes/character/character.gd` |
| 건물 | `scenes/building/building.gd` |
| 건물 종류 카탈로그 | `scenes/building/building_types.gd` |
| 영지 | `scenes/territory/territory.gd` |
| 캠프 메뉴 | `scenes/camp/camp_menu.gd` |
| 세력 | `scenes/faction/faction.gd` |
| 초원 타일셋 | `tiles/grass_tileset.tres` |

---

## 추천 스펙 (미구현 · 제안)

향후 문서화/구현을 고려할 만한 항목. 지금 당장 만들 필요는 없고, 방향성 참고용이다.

- **`features/settings.md`** — 타이틀의 "설정" 버튼이 아직 `TODO`다. 해상도 · 사운드 · 언어 등 저장 가능한 설정 화면을 정의하면 좋다.
- **`features/save-load.md`** — 세이브/로드. 게임 진행(주인공 위치, 자원, 탐험된 안개)을 직렬화하는 규칙.
- **`features/turn-system.md`** — 이동 범위·공격 범위 개념이 이미 있으니, 이를 묶는 턴/행동력 규칙을 정의하면 전투로 확장 가능.
- **`features/building.md` (Phase 2)** — 건물 종류 카탈로그([data/buildings.md](data/buildings.md))와 [Building 엔티티](entities/Building.md)는 도입됨. 남은 것은 캠프 메뉴 "건축" 버튼의 **건설 흐름**(종류 선택 · 자원 소비 · 배치)이다.
- **`data/terrain.md`** — 현재는 초원 단일 타일. 지형 종류(숲/산/물)와 이동 비용 · 시야 차단 규칙을 정의하면 맵이 풍부해진다.
- **`entities/Enemy.md`** — 공격 범위가 있으니 적/전투 대상 엔티티가 자연스러운 다음 단계.
- **`data/items.md`** — 아이템/장비 리스트 (능력치 보정 등).
- **`features/input-scheme.md`** — 키보드/마우스/게임패드/터치 입력 매핑을 한곳에 정리 (전 플랫폼 배포 목표에 맞춤).
