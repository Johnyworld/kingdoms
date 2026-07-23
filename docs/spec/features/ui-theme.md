# Feature: UI Theme (중세풍 UI 스킨)

> 테마 리소스: `assets/ui/medieval_theme.tres` (`Theme`)
> 에셋: `assets/ui/darkages/` — 원본 `32x32-Tilesheet.png`(DarkAgesUi_v1.0, 작가 Hypnobius) + StyleBox 소스로 쓰는 ×3 업스케일본 `32x32-Tilesheet@3x.png` + `LICENSE.txt`·`README.txt`
> 폰트: 본문 `assets/ui/fonts/Cafe24SsurroundAir.otf`(Air, 일반) · 제목 `assets/ui/fonts/Cafe24Ssurround.otf`(굵게) — 카페24 서라운드, 한글 전체(11,172음절)+ASCII 지원 벡터 폰트. 구 `Galmuri14.ttf`(갈무리14 픽셀 폰트)는 **미사용**(Slice 5에서 교체, 리포에는 잔존)
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
- **default_font** = 갈무리14, **default_font_size** = 14(픽셀 폰트 권장 크기). *(Slice 5에서 default_font를 Cafe24 Air로 교체 — 크기 14 유지.)*
- **`Label/colors/font_color`** = 밝은 크림(본문 기본색). 제목 등 강조색은 각 UI의 기존 `add_theme_color_override`가 위에 얹힘.
- `PanelContainer/panel` StyleBoxTexture → 어두운 사각 프레임(나인패치). 상시 패널 기본 스킨.
- 타입 변형 **`OrnatePanel`**(base_type `PanelContainer`)의 `panel` StyleBoxTexture → 금장 장식 프레임.
- **구분선·진행바·아이콘 스킨은 Slice 3**에서 추가 — 현재 `HSeparator` 등은 폰트만
  테마를 따르고 나머지는 Godot 기본값(미구현). 버튼은 Slice 2에서 스킨 적용.

### 전역 등록
- `project.godot` `[gui] theme/custom="res://assets/ui/medieval_theme.tres"`.
- 등록 즉시 모든 코드빌드 UI(타이틀·스플래시·HUD·모달)가 폰트/패널 스킨을 상속.

### 모달 스킨 (`scenes/modal/modal.gd`)
- 중앙 `PanelContainer`에 `theme_type_variation = "OrnatePanel"`을 지정해 금장 프레임으로 그린다.
- 컴포지션 구조(`set_content`)·`ModalStack` 로직·닫기 입력은 **불변**.
- 닫기 버튼 X 아이콘화·타이틀 바 전용 StyleBox는 Slice 2~3(미구현, 현재 텍스트 "X" 유지).

## Slice 2 — 버튼 스킨 + 패널 정합 (구현)

### 버튼 StyleBox (`Button/styles/*`)
- 소스 = 얇은 테두리 롱버튼(탄 외곽선 + 네이비 베벨 + 올리브 채움, 라운드 코너, @3x region `Rect2(960, 318, 96, 45)`), 나인패치 texture_margin 12.
  - region은 세로 중앙의 좌우 테두리(x≈960·1055)까지 포함해야 한다. 모서리에서 6px 안쪽으로 말리는 라운드 사각틀이라, 좌우를 좁게 잡으면 세로 테두리가 잘려 보인다.
- 4상태를 **같은 텍스처 + `modulate_color`**로 구성. GL Compatibility LDR 캔버스는 `modulate>1.0`을
  클램프하므로(밝히기 불가), **음영 방향(≤1.0)**으로 피드백한다:
  - `normal` = 원색, `hover` = 약간 어둡고 차갑게(≈0.87×·청색틴트), `pressed` = 더 어둡게(≈0.68×),
    `disabled` = 흐리게(회색·반투명 0.5). normal→hover→pressed 3단계 음영 + 글자색 변화로 구분.
- content_margin: 좌우 16 / 상하 8(텍스트 여백).
- **글자색**: `Button/colors/font_color` 크림, `font_hover_color` 밝은 금색, `font_pressed_color` 크림,
  `font_disabled_color` 회색.

### 패널 정합
- HUD·정보·로스터·행동 메뉴 등 코드빌드 `PanelContainer`는 전역 `panel`(어두운 프레임)을 자동 상속.
  프레임 content_margin(30)만큼 콘텐츠가 안쪽으로 들어가며, 앵커·grow 방향은 기존 코드가 유지하므로
  레이아웃 구조 변경 없음(스크립트 수정 없이 스킨만 적용). 프리뷰 렌더에서 프레임·콘텐츠 겹침 없음 확인
  (실제 게임 HUD 통합 확인은 전 슬라이스 완료 후 플레이 검증).

## Slice 3 — 마감: 구분선·양피지·닫기 아이콘 (구현)

### HSeparator 구분선 (`HSeparator/styles/separator`)
- 체인 브레이드(@3x region `Rect2(639, 804, 165, 24)`)를 `axis_stretch_horizontal = TILE(1)`로 가로 반복.
  스트레치 왜곡 없이 폭에 맞게 링크가 되풀이된다.
- **선 두께**: `Separator`는 스타일박스 최소 높이로 선 두께를 정하므로 `texture_margin_top/bottom = 12`
  (합 24)로 높이를 확보한다(margin 0이면 두께 0으로 안 그려짐). `constants/separation = 24`.
- **가시성**: 체인 원본이 어두워 다크 패널 위에서 안 보이므로 `modulate_color = Color(2.6, 2.2, 1.4)`로
  금빛으로 lift. 소스가 어두워 LDR 클램프 없이 밝아진다(밝은 탄색 버튼과 반대 경우).
- 전역 적용 → 모달·부대 정보·일람·캠프 메뉴·건물 정보의 기존 `HSeparator`가 모두 자동 상속.

### 양피지 패널 (`ParchmentPanel` + `ParchmentLabel`)
- `ParchmentPanel`(base `PanelContainer`) StyleBoxTexture = 크림 양피지(@3x region `Rect2(297, 3, 276, 288)`,
  torn edge 나인패치 margin 27, content_margin 28/22).
- 밝은 양피지 위에는 크림 글자가 안 보이므로 `ParchmentLabel`(base `Label`) = 어두운 갈색 글자.
- 소비자: 알림 Toast(`scenes/game/toast.gd`) — `_box`에 `ParchmentPanel`, `_label`에 `ParchmentLabel` 지정.

### 모달 닫기 X 아이콘 (`scenes/modal/modal.gd`)
- 닫기 버튼을 텍스트 "X" → 시트의 X 아이콘 `AtlasTexture`(@3x region `Rect2(228, 708, 21, 24)`)로 교체.
  시트 로드 실패 시 텍스트 "X"로 폴백. 닫기 로직·시그널은 불변.

## Slice 4 (미구현 · 유예)

- 리스트 불릿 다이아 아이콘(리스트 렌더 코드 침투 필요), `ProgressBar` 스킨(**현재 코드베이스에서 미사용** —
  전투 병력바는 `draw_rect` 커스텀이라 테마 대상 아님), `.tscn` 메뉴 씬(title·splash·lang_setup·result)
  폰트 크기 재튜닝(현재는 전역 폰트만 상속, 크기 override 유지).

## Slice 5 — 벡터 폰트 전환 (구현)

UI를 벡터(슈퍼샘플) 렌더로 전환함에 따라 픽셀 비트맵 폰트(갈무리14)를 부드러운 벡터 폰트
**카페24 서라운드**로 교체한다. **본문은 Air(일반), 제목·배너는 굵은 Ssurround**를 쓴다.

### 에셋 반입
- `assets/ui/fonts/Cafe24SsurroundAir.otf`(Air, 일반) + `Cafe24Ssurround.otf`(굵게), 각 라이선스 PDF 동봉.
- 두 폰트 모두 한글 음절 전체(11,172)+ASCII(95) 포함(cmap 검증 완료). 상업 배포 허용 폰트.
- `.import`: 벡터 폰트이므로 `antialiasing = 1`(그레이스케일 AA). 임베디드 비트맵 없음.
  최초 1회 `godot --headless --import`로 `.godot/imported` 생성.
- 구 `Galmuri14.ttf`는 더 이상 참조되지 않음(리포에는 잔존, 필요 시 별도 커밋에서 제거).

### 테마 (`medieval_theme.tres`)
- **default_font = Cafe24 Air**, `default_font_size = 14` 유지(개별 씬 크기 override 불변).
- 타입 변형 **`TitleLabel`**(base_type `Label`): `fonts/font` = 굵은 Ssurround. 제목/배너 라벨용.
  크기·색은 각 소비자의 기존 `add_theme_*_override`가 위에 얹힌다.
- 버튼은 전부 default(Air) 유지 — 별도 굵게 버튼 변형 없음.

### 소비자 (굵게 = `theme_type_variation` 한 줄 추가)
| 위치 | 대상 | 변형 |
| --- | --- | --- |
| `splash.tscn` | 스플래시 타이틀 | `TitleLabel` |
| `title.tscn` | "KINGDOMS" 타이틀 | `TitleLabel` |
| `result_overlay.gd` | 결과 타이틀(승/패) | `TitleLabel` |
| `turn_banner.gd` | NPC 진행 배너 라벨 | `TitleLabel` |
| `turn_banner.gd` | 플레이어 턴 헤럴드 라벨(양피지) | `ParchmentLabel` 유지 + 굵은 폰트 `add_theme_font_override` (색은 양피지용 어두운 글자 유지) |
| `modal.gd` | 모달 타이틀(전 모달 공통) | `TitleLabel` |
| `party_roster.gd`·`party_info.gd`·`camp_menu.gd`·`building_info.gd` | 패널 섹션 제목 | `TitleLabel` |
| `lang_setup.gd` | 셋업 타이틀·섹션 헤더 | `TitleLabel` |

그 외 본문·HUD·토스트·결과 서브타이틀·모든 버튼(시작 포함)은 default(Air) 유지.

### 지도 텍스트 (`scenes/game/map_text.gd`)
- 월드 라벨 폰트 `const TTF` preload를 Air(`Cafe24SsurroundAir.otf`)로 교체(본문 계열).
  슈퍼샘플 파이프라인·`font_size` 기준은 불변.

## 테스트 시나리오

`test/unit/test_ui_theme.gd`.

- [정상] `res://assets/ui/medieval_theme.tres` 로드 성공 → `Theme` 인스턴스
- [정상] 테마 `default_font` 존재(null 아님), `default_font_size` == 14
- [정상] 본문 폰트 `res://assets/ui/fonts/Cafe24SsurroundAir.otf` 로드 성공 → `FontFile`
- [정상] 테마에 `PanelContainer`의 `panel` StyleBox 정의됨(`has_stylebox("panel","PanelContainer")`)
- [정상] 타입 변형 `OrnatePanel`의 `panel` StyleBox 정의됨(`has_stylebox("panel","OrnatePanel")`)
- [정상] `PanelContainer/panel`·`OrnatePanel/panel` 모두 `StyleBoxTexture`이고 `texture` 지정됨
- [정상] `project.godot`의 `gui/theme/custom` == 테마 경로(`ProjectSettings.get_setting`)
- [정상] UI 타일시트 텍스처 `res://assets/ui/darkages/32x32-Tilesheet@3x.png` 로드 성공
- [정상] `Modal` 인스턴스의 중앙 `PanelContainer`.`theme_type_variation` == `"OrnatePanel"`
- [Slice2][정상] `Button`의 `normal`·`hover`·`pressed`·`disabled` StyleBox가 모두 정의됨
- [Slice2][정상] 위 4개 모두 `StyleBoxTexture`이고 `texture` 지정됨
- [Slice2][정상] 상태별 `modulate_color`가 서로 다르고(normal≠hover≠pressed) 모두 ≤1.0(LDR 클램프 회피)
- [Slice2][정상] `Button/styles/focus`는 `StyleBoxEmpty`(기본 포커스 아웃라인 억제)
- [Slice2][정상] `Button/colors/font_color`·`font_hover_color`·`font_pressed_color`·`font_disabled_color` 정의됨
- [Slice3][정상] `HSeparator/styles/separator`가 `StyleBoxTexture`이고 `axis_stretch_horizontal == TILE`
- [Slice3][정상] 타입 변형 `ParchmentPanel`의 `panel` StyleBox가 `StyleBoxTexture`로 정의됨
- [Slice3][정상] 타입 변형 `ParchmentLabel`의 `font_color`가 어두운 색(밝기 낮음)으로 정의됨
- [Slice3][정상] `Modal` 인스턴스의 닫기 버튼에 아이콘(`icon`)이 지정됨(텍스트 "X" 아님)
- [Slice3][정상] `Toast` 인스턴스의 `_box`는 `ParchmentPanel`, `_label`은 `ParchmentLabel` 변형
- [Slice5][정상] 굵은 폰트 `res://assets/ui/fonts/Cafe24Ssurround.otf` 로드 성공 → `FontFile`
- [Slice5][정상] 테마 `default_font`의 `resource_path`가 Air 폰트(`Cafe24SsurroundAir.otf`)
- [Slice5][정상] 타입 변형 `TitleLabel`에 `font`가 정의됨(`has_font("font","TitleLabel")`)이고 굵은 폰트(default_font와 다름)
- [Slice5][정상] `map_text.gd`의 `TTF` 상수 `resource_path`가 Air 폰트를 가리킴
- [Slice5][정상] `Modal` 인스턴스의 타이틀 라벨 `theme_type_variation` == `"TitleLabel"`

## 관련

- [Modal (공용 모달 기반)](modal.md) — 이 테마의 `OrnatePanel` 변형을 쓰는 첫 소비자.
