# Feature: UI Theme (중세풍 UI 스킨)

> 테마 리소스: `assets/ui/medieval_theme.tres` (`Theme`)
> 에셋: `assets/ui/darkages/` — 원본 `32x32-Tilesheet.png`(DarkAgesUi_v1.0, 작가 Hypnobius) + StyleBox 소스로 쓰는 ×3 업스케일본 `32x32-Tilesheet@3x.png` + `LICENSE.txt`·`README.txt`
> 폰트: `assets/ui/fonts/Galmuri14.ttf` (갈무리14, SIL OFL, 한글 픽셀 폰트)
> 전역 등록: `project.godot` → `[gui] theme/custom`

게임 전체 UI를 **중세 다크판타지 픽셀아트**로 통일하는 중앙 테마. 기존 UI는 전부 코드로 만든
표준 Control 노드(`PanelContainer`·`Button`·`Label` 등)라, 전역 테마 하나를 등록하면 대부분의
UI가 별도 코드 수정 없이 스킨을 상속받는다. 단일 타일시트를 `StyleBoxTexture`의 `region_rect`로
영역 참조해 나인패치로 그린다(분리 파일 없음).

에셋 라이선스: 상업/개인 사용 허용, 재판매·재배포·다른 팩 포함·NFT/AI 학습 금지, 출처 표기 선택.
`LICENSE.txt`·`README.txt`를 에셋과 함께 리포에 동봉한다.

## 프레임 매핑 (용도별 구분)

| 시트 영역 | 테마 키 | 용도 |
| --- | --- | --- |
| 얇은 테두리 어두운 사각 프레임 | `PanelContainer/panel` (기본) | HUD·로스터·정보 패널 등 상시 패널 |
| 금장 코너 장식 프레임 | 타입 변형 `OrnatePanel/panel` | 모달·중요 창 |
| 크림 양피지 패널 | (Slice 3) `ParchmentPanel/panel` | 툴팁·토스트·본문 배경 — **미구현** |

## Slice 1 — 기반 (이 문서의 현재 구현 범위)

### 에셋 반입
- `assets/ui/darkages/`에 타일시트 + 라이선스/리드미 동봉.
- 나인패치 코너가 32px 원본에선 너무 얇으므로 **nearest-neighbor ×3 업스케일본**(`32x32-Tilesheet@3x.png`)을
  StyleBox 소스로 사용한다. region_rect·texture_margin은 업스케일본(×3) 픽셀 기준.
- 픽셀 선명도(Nearest 필터)는 CanvasItem/프로젝트 캔버스 필터 사안이라 `.import`로 지정되지 않는다.
  ×3 업스케일로 1차 확보하고, 전역 `rendering/textures/canvas_textures/default_texture_filter=Nearest`
  적용 여부는 기존 지형 렌더 영향을 실행 검증(Verification)에서 확인 후 결정한다(**Slice 1에서는 미변경**).

### 테마 리소스 `medieval_theme.tres`
- **default_font** = 갈무리14, **default_font_size** = 14(픽셀 폰트 권장 크기).
- **`Label/colors/font_color`** = 밝은 크림(본문 기본색). 제목 등 강조색은 각 UI의 기존 `add_theme_color_override`가 위에 얹힘.
- `PanelContainer/panel` StyleBoxTexture → 어두운 사각 프레임(나인패치). 상시 패널 기본 스킨.
- 타입 변형 **`OrnatePanel`**(base_type `PanelContainer`)의 `panel` StyleBoxTexture → 금장 장식 프레임.
- **버튼·구분선·진행바·아이콘 스킨은 Slice 2~3**에서 추가 — 현재 `Button`/`HSeparator` 등은 폰트만
  테마를 따르고 나머지는 Godot 기본값(미구현).

### 전역 등록
- `project.godot` `[gui] theme/custom="res://assets/ui/medieval_theme.tres"`.
- 등록 즉시 모든 코드빌드 UI(타이틀·스플래시·HUD·모달)가 폰트/패널 스킨을 상속.

### 모달 스킨 (`scenes/modal/modal.gd`)
- 중앙 `PanelContainer`에 `theme_type_variation = "OrnatePanel"`을 지정해 금장 프레임으로 그린다.
- 컴포지션 구조(`set_content`)·`ModalStack` 로직·닫기 입력은 **불변**.
- 닫기 버튼 X 아이콘화·타이틀 바 전용 StyleBox는 Slice 2~3(미구현, 현재 텍스트 "X" 유지).

## Slice 2~3 (미구현)

- **Slice 2**: `Button` normal/hover/pressed/disabled StyleBoxTexture, HUD/정보 패널 앵커 정합·패딩 보정.
- **Slice 3**: `HSeparator` 필리그리, `ProgressBar`(체력/자원) 컬러 바, 리스트 불릿 다이아 아이콘,
  양피지 배경(`ParchmentPanel`), `.tscn` 메뉴 씬(title·splash·lang_setup·result) 폰트 크기 정합.

## 테스트 시나리오

`test/unit/test_ui_theme.gd`.

- [정상] `res://assets/ui/medieval_theme.tres` 로드 성공 → `Theme` 인스턴스
- [정상] 테마 `default_font` 존재(null 아님), `default_font_size` == 14
- [정상] 폰트 파일 `res://assets/ui/fonts/Galmuri14.ttf` 로드 성공 → `FontFile`
- [정상] 테마에 `PanelContainer`의 `panel` StyleBox 정의됨(`has_stylebox("panel","PanelContainer")`)
- [정상] 타입 변형 `OrnatePanel`의 `panel` StyleBox 정의됨(`has_stylebox("panel","OrnatePanel")`)
- [정상] `PanelContainer/panel`·`OrnatePanel/panel` 모두 `StyleBoxTexture`이고 `texture` 지정됨
- [정상] `project.godot`의 `gui/theme/custom` == 테마 경로(`ProjectSettings.get_setting`)
- [정상] UI 타일시트 텍스처 `res://assets/ui/darkages/32x32-Tilesheet@3x.png` 로드 성공
- [정상] `Modal` 인스턴스의 중앙 `PanelContainer`.`theme_type_variation` == `"OrnatePanel"`

## 관련

- [Modal (공용 모달 기반)](modal.md) — 이 테마의 `OrnatePanel` 변형을 쓰는 첫 소비자.
