# Feature: Map & Camera (맵과 카메라)

> 스크립트: `scenes/game/game.gd` (`extends Node2D`)
> 씬: `scenes/game/game.tscn`

## 맵

- **크기**: 300 × 300 헥스 (`MAP_WIDTH`, `MAP_HEIGHT` = 90,000 셀).
- **타일**: 초원 단일 타일(`grass_tileset.tres`, source id 0, atlas `(0,0)`).
  - 헥스 형태(pointy-top), 타일 크기 64×46.
- 시작 시 전체를 초원 타일로 채운다(`_generate_map`).

## 카메라

- 시작 시 맵 중앙 타일로 이동(`_center_camera`).
- **이동 방법** (`_process`):
  - 키보드: **WASD**
  - 마우스: 화면 가장자리(`EDGE_MARGIN = 24px`)에 커서를 대면 해당 방향으로 스크롤.
  - 속도: `CAM_SPEED = 900 px/초`.
- **범위 제한**: 맵 밖으로 벗어나지 않도록 `_min_pos`~`_max_pos`로 클램프.

## 줌

- 마우스 휠 위 = 확대, 아래 = 축소.
- 줌 배율 `_zoom_level` 범위: `ZOOM_MIN 0.5` ~ `ZOOM_MAX 3.0`, 스텝 `0.1`.
- 값이 작을수록 확대. `Camera2D.zoom = Vector2.ONE / _zoom_level`로 변환 적용.

## 게임 씬 구성 노드

`TerrainLayer` · `Camp` · `RangeOverlay` · `Hero` · `Fog`(z_index 10) · `Camera2D` · `CampMenu`.

시작 순서(`_ready`): 맵 생성 → 카메라 중앙 → 오버레이 setup → 캠프 배치(중앙) → 주인공 배치 → 안개 setup → 안개 갱신.
