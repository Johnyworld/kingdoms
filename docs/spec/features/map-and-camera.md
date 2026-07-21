# Feature: Map & Camera (맵과 카메라)

> 스크립트: `scenes/game/game.gd` (`extends Node2D`)
> 씬: `scenes/game/game.tscn`

## 맵

- **크기**: 50 × 50 헥스 (`MAP_WIDTH`, `MAP_HEIGHT` = 2,500 셀).
- **지형 데이터/렌더 분리** → [Terrain](../data/terrain.md).
  - **데이터 레이어** `TerrainLayer`(보이지 않음): 지형 타입을 source id로 보관(`0` 초원·`1` 숲·`2` 습지·`3` 산·`4` 사막·`7` 물·`8` 철맥·`9` 금맥, atlas `(0,0)`). BFS·좌표 지오메트리 기준. `tiles/terrain_tileset.tres`, 헥스 16×16.
  - **비주얼 레이어** `TerrainVisual`(LaPetiteTile 오토타일 스택): `TerrainRenderer`가 데이터를 읽어 그린다. 헥스 형태(16×16), 코너 매칭.
- **4왕국 모서리 배치**: 플레이어 + NPC 3세력의 거점을 맵 네 모서리 근처(안쪽 `MARGIN=10`칸)에 둔다. → [NPC Bases](npc-bases.md).
  - 플레이어 거점(마을회관) = **남서(SW)** 모서리 `PLAYER_BASE = (MARGIN, MAP_HEIGHT-1-MARGIN) = (10, 39)`.
- **생성**(`_generate_map`): 전체를 초원으로 채운 뒤, **플레이어 거점(남서 모서리)** 근처에 방향별 지형 덩어리를 배치하고(`_place_starting_terrain`), 마지막에 `TerrainRenderer.repaint`로 비주얼 레이어를 그린다.
  - **서쪽=숲 · 동쪽=습지 · 북쪽=사막 · 남쪽=산 · 남동쪽=호수(물)**. 각 방향 씨앗 칸 + 이웃 6칸을 그 지형으로 칠한다(`_paint_patches`).
  - **강**(`_place_river`): 맵 중앙에 사인 곡선으로 굽이치는 `WATER` 경로(거점 4곳과 떨어짐, 가장자리 미접촉 → 맵을 완전히 가르지 않아 양끝으로 우회 가능). WATER는 통행 불가라 강은 자연 장벽이 된다(다리는 후속). Ocean 오토타일이 둑을 자동 렌더.
  - 캠프(중심 반경1)·주인공 배치 칸과 겹치지 않게 떨어뜨린다. (y 증가=남쪽, x 증가=동쪽)

## 카메라

- 시작 시 **플레이어 거점(남서 모서리)** 타일로 이동(`_center_camera` → `PLAYER_BASE`).
- **이동 방법** (`_process`):
  - 키보드: **WASD**
  - 마우스: 화면 가장자리(`EDGE_MARGIN = 24px`)에 커서를 대면 해당 방향으로 스크롤.
  - 속도: `CAM_SPEED = 900 px/초`.
- **범위 제한**: 맵 밖으로 벗어나지 않도록 `_min_pos`~`_max_pos`로 클램프.

## 줌

- **마우스 휠**: 위 = 확대, 아래 = 축소 (`InputEventMouseButton` WHEEL_UP/DOWN, 스텝 `0.1`).
- **트랙패드 두 손가락 스크롤**(`InputEventPanGesture`): 위로 = 확대, 아래로 = 축소.
  `_zoom_level += delta.y * PAN_ZOOM_SPEED(0.05)`.
- **트랙패드 핀치**(`InputEventMagnifyGesture`): 벌리면(factor>1) 확대, 오므리면(factor<1) 축소.
  `_zoom_level /= factor`.
- 줌 배율 `_zoom_level` 범위: `ZOOM_MIN 0.125`(8× 확대, 타일 128px) ~ `ZOOM_MAX 1.0`(전체 조망). 기본값 `0.33`(~3× = 화면상 48px). 16px 픽셀아트 헥스 기준.
- 값이 작을수록 확대. `Camera2D.zoom = Vector2.ONE / _zoom_level`로 변환 적용.

## 테스트 시나리오
- [정상] 마우스 휠 위 → `_zoom_level` 감소(확대) / 휠 아래 → 증가(축소)
- [정상] PanGesture `delta.y < 0`(위로 스크롤) → 확대 / `delta.y > 0` → 축소
- [정상] MagnifyGesture `factor > 1`(핀치 아웃) → 확대 / `factor < 1` → 축소
- [경계] 확대/축소가 `ZOOM_MIN`~`ZOOM_MAX` 범위로 클램프됨
- [예외] MagnifyGesture `factor <= 0`(비정상 입력) → 무시(zoom 불변)

## 게임 씬 구성 노드

`TerrainVisual`(Ocean·Waves·SandShore·Ground·GroundOverlay·Grass·Cliff·Decoration(나무·산봉우리) 오토타일 레이어) · `TerrainLayer`(데이터, 숨김) · `BuildingsLayer`(거점 건물 오토타일, `Tileset_Elements`) · `Building` · `RangeOverlay` · `Hero` · `Fog`(z_index 10) · `Camera2D` · `CampMenu`.

시작 순서(`_ready`): 맵 생성 → 카메라 → 오버레이 setup → 건물 배치(남서 모서리 캠프) → 영지·세력 연결(캠프의 영지 "창천성" ∈ 세력 "푸른 왕국") → 부대 생성·배치(플레이어 + NPC 3, [Parties](parties.md)) → 안개 setup → 안개 갱신.
