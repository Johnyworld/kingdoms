# Feature: Tile Gallery (타일 보기)

> 스크립트: `scenes/tile_gallery/tile_gallery.gd` (`extends Node2D`)
> 씬: `scenes/tile_gallery/tile_gallery.tscn`
> 진입: 타이틀의 **"타일 보기"** 버튼(우상단, 전투 테스트 버튼 아래) → `SceneManager.change_scene`

LaPetiteTile 팩의 타일/스프라이트를 **빠짐없이** 훑어보는 읽기 전용 화면(전투 테스트와 같은 인게임 검사 도구). 맵 에디터가 아니라 카탈로그 뷰어다. **런타임 열거** — 하드코딩 목록이 아니라 타일셋/폴더를 스캔해 자동으로 전부 보여주므로, 에셋이 늘면 갤러리도 자동으로 반영된다.

## 내용 (섹션 순서)

1. **게임 지형 (실제 렌더)**: 초원·숲·습지·사막·산·물·철맥·금맥 — `TerrainRenderer.PAINT` 스택 재사용해 게임과 100% 동일. 끝에 **강 데모**(물 밑 + 땅 틈 기법) 한 칸 — 강은 단일 타일이 아니라 다층 기법임을 보여준다.
2. **게임 건물 (플레이어색)**: 캠프·마을회관·성 — `BuildingRenderer`로 렌더(티어별 크기 차등 확인).
3. **모든 터레인 타일셋의 전 terrain**: `ALL_TILESETS`(14종 — Ground/Grass/GroundOverlay/Cliff/Ocean/OceanOverlay/SandShore/Waves/Roads/Rock/Pattern/Elements/Ramparts앞·뒤)를 로드해 `get_terrain_sets_count`×`get_terrains_count`로 전 terrain을 3×3 오토타일 스와치 + terrain 이름으로.
4. **모든 스탠드얼론 스프라이트**: `SPRITE_FOLDERS`(Standalone_Buildings·Vegetation·Rocks·Creatures·Ship·Icons·Parchment&WindRoses)를 `DirAccess`로 **재귀 스캔**해 모든 `.png`를 Sprite2D 썸네일(최대 변 `SPRITE_PX`로 정규화)로. 수백 개.

## 조작

- **이동**: WASD / 방향키, 좌클릭 드래그, 또는 트랙패드 두 손가락 스크롤.
- **줌**: 마우스 휠 / 트랙패드 핀치(`ZOOM_MIN 0.1`=10× ~ `ZOOM_MAX 2.0`, 기본 0.6). 진입 시 첫 섹션(상단)이 보이도록 카메라를 맞춘다.
- **복귀**: 좌상단 "← 타이틀" 버튼 또는 ESC → 타이틀.

## 테스트

- `test/unit/test_tile_gallery.gd` — 배선 검증: `ALL_TILESETS` 로드·terrain_set 존재, 게임 지형 PAINT 레이어 키가 `PAINT_KEY_TS`에 매핑, 매핑 타일셋이 열거 목록에 포함, 게임 건물 타입 유효, 스프라이트 폴더에 png 존재. 실제 렌더는 육안 확인.

## 미구현 / TODO / 주의

- 스프라이트 열거는 `DirAccess`로 `res://` 소스 png를 스캔한다 — 에디터/소스 실행에서 동작. 완전 export 빌드에서 소스 png가 리맵되면 나열이 달라질 수 있다(검사 도구라 에디터 실행 전제).
- 맵 에디터(타일 골라 칠하고 저장/로드)는 별도 기능. 지금은 조회 전용.
- 애니메이션 스프라이트(배·깃발)는 정지 프레임(png)으로만 표시.
