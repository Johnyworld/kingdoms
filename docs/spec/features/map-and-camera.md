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
- **손맵(직접 제작)**: `_generate_map`이 세 경우를 자동 판별한다.
  1. **비주얼 손맵(권장·WYSIWYG)**: `TerrainVisual` 아래 오토타일 레이어(Ground/Ocean/Grass/Cliff/Decoration…)를 **에디터에서 직접 칠하면** 그 그림을 **그대로 두고**(`repaint` 안 함), 게임 로직용 지형타입을 비주얼에서 **역산**한다(`_visual_authored`/`_derive_data_from_visuals`/`_derive_type` — **물=Ocean 있고 Ground 없음**(Ocean은 전체 바닥 underlay라 땅이 안 덮인 칸만 물·강), Cliff·Ground바위=MOUNTAIN, 나무=FOREST, GroundOverlay swamp=SWAMP·그 외 모래=DESERT, 나머지 PLAINS). 제작법: `game.tscn` 열고 `TerrainVisual`의 레이어 선택 → TileMap Terrains로 칠하고 저장 → 실행.
  2. **데이터 손맵**: 비주얼은 비었고 숨김 데이터 레이어(`TerrainLayer`)에 칠해진 게 있으면 그걸 쓰고 `TerrainRenderer`로 비주얼을 그린다. `terrain_tileset` 팔레트는 각 지형 실제 렌더를 캡처한 미리보기(`tiles/terrain_preview/*.png`)로 보인다.
  3. **절차 생성**(둘 다 비었을 때): 전체 초원 + **방향별 지형 덩어리**(서=숲·동=습지·북=사막·남=산·남동=호수, 씨앗+이웃 6칸 `_place_starting_terrain`) + 강 + 길을 만들고 `TerrainRenderer.repaint`. (y↑=남, x↑=동; 캠프·주인공 칸과 안 겹치게)
     - **강**(`_place_river`): 맵 중앙 사인 곡선 `WATER`(거점 4곳과 떨어짐·가장자리 미접촉 → 맵을 완전히 가르지 않아 양끝 우회 가능). 통행 불가 자연 장벽(다리는 후속), Ocean 오토타일이 둑 렌더.
     - **길**(`_place_roads`): 거점↔철맥·금맥 잇는 장식 흙길(`Roads` 레이어, `HexGrid.reconstruct_path` 우회 경로). 순수 시각 — 이동/BFS 무관(이동 보너스는 후속).
- 데이터 레이어(`TerrainLayer`)는 런타임에 항상 `visible = false`.
- **거점 배치 마커**(`Placements/PlayerBase`·`batur`·`balthazar`·`qasim`, Marker2D): `_placement_cell`이 마커가 있으면 그 칸(`local_to_map`으로 스냅)을, 없으면 기본 모서리 좌표(`PLAYER_BASE`/`NPC_BASES`)를 거점 위치로 쓴다. 에디터에서 마커를 원하는 칸으로 드래그하면 거점 + 소속 부대가 거기 생긴다(부대는 `_faction_center_building` 기준 배치).
- **레이어 잠금**: TerrainVisual의 지형 레이어·TerrainLayer·BuildingsLayer는 에디터 Lock(`metadata/_edit_lock_`)이 걸려 있어 실수로 이동되지 않는다(칠할 땐 Scene 트리에서 선택).
- **한계**: 부대 **개별** 스폰 지점은 아직 미지원(거점 단위 배치). 철맥·금맥은 겉보기 구분 불가라 비주얼 손맵에선 초원으로 취급. 완전한 엔티티 배치는 후속 [맵 데이터 포맷].

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
