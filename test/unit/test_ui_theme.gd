extends GutTest
## 중세풍 UI 테마 — medieval_theme.tres + Cafe24 서라운드 폰트(Air 본문/Ssurround 굵게) + DarkAgesUi 타일시트.
## 전역 테마 등록·프레임 StyleBox·모달 OrnatePanel 변형·벡터 폰트(Slice 5)·타이포 스케일(Slice 6)을 검증한다. → docs/spec/features/ui-theme.md

const THEME_PATH := "res://assets/ui/medieval_theme.tres"
const FONT_AIR_PATH := "res://assets/ui/fonts/Cafe24SsurroundAir.otf"
const FONT_BOLD_PATH := "res://assets/ui/fonts/Cafe24Ssurround.otf"
const SHEET_PATH := "res://assets/ui/darkages/32x32-Tilesheet@3x.png"
const ModalScript = preload("res://scenes/modal/modal.gd")
const ToastScript = preload("res://scenes/game/toast.gd")
const MapTextScript = preload("res://scenes/game/map_text.gd")

func _theme() -> Theme:
	return load(THEME_PATH) as Theme

# --- 테마 리소스 ---

func test_theme_loads() -> void:
	assert_not_null(_theme(), "medieval_theme.tres가 Theme로 로드돼야 한다")

func test_theme_default_font() -> void:
	var t := _theme()
	assert_not_null(t.default_font, "테마 default_font가 지정돼야 한다")
	assert_eq(t.default_font_size, 20, "테마 default_font_size는 20(본문 MD)")

func test_font_file_loads() -> void:
	var f = load(FONT_AIR_PATH)
	assert_true(f is FontFile, "Cafe24 Air가 FontFile로 로드돼야 한다")

# --- 프레임 StyleBox ---

func test_panel_stylebox_defined() -> void:
	assert_true(_theme().has_stylebox("panel", "PanelContainer"),
		"기본 PanelContainer 'panel' StyleBox가 정의돼야 한다")

func test_ornate_stylebox_defined() -> void:
	assert_true(_theme().has_stylebox("panel", "OrnatePanel"),
		"OrnatePanel 변형 'panel' StyleBox가 정의돼야 한다")

func test_styleboxes_are_textured() -> void:
	var t := _theme()
	var dark := t.get_stylebox("panel", "PanelContainer")
	var ornate := t.get_stylebox("panel", "OrnatePanel")
	assert_true(dark is StyleBoxTexture, "기본 패널은 StyleBoxTexture")
	assert_true(ornate is StyleBoxTexture, "장식 패널은 StyleBoxTexture")
	assert_not_null((dark as StyleBoxTexture).texture, "기본 패널 texture 지정")
	assert_not_null((ornate as StyleBoxTexture).texture, "장식 패널 texture 지정")

# --- 에셋 ---

func test_sheet_texture_loads() -> void:
	assert_not_null(load(SHEET_PATH), "×3 업스케일 타일시트가 로드돼야 한다")

# --- 전역 등록 ---

func test_theme_registered_globally() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH,
		"project.godot의 gui/theme/custom이 medieval_theme.tres여야 한다")

# --- 모달 스킨 ---

func test_modal_uses_ornate_variation() -> void:
	var m = ModalScript.new()
	add_child_autofree(m)
	assert_not_null(m._panel, "모달이 중앙 PanelContainer(_panel)를 노출해야 한다")
	assert_eq(m._panel.theme_type_variation, &"OrnatePanel",
		"모달 패널은 OrnatePanel 변형을 써야 한다")

# --- Slice 2: 버튼 스킨 ---

func test_button_states_defined() -> void:
	var t := _theme()
	for state in ["normal", "hover", "pressed", "disabled"]:
		assert_true(t.has_stylebox(state, "Button"),
			"Button '%s' StyleBox가 정의돼야 한다" % state)

func test_button_styleboxes_are_textured() -> void:
	var t := _theme()
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := t.get_stylebox(state, "Button")
		assert_true(sb is StyleBoxTexture, "Button '%s'는 StyleBoxTexture" % state)
		assert_not_null((sb as StyleBoxTexture).texture, "Button '%s' texture 지정" % state)

func test_button_states_visually_distinct() -> void:
	# GL Compat에서 밝히기 클램프 → 음영으로만 구분. 상태별 modulate가 서로 달라야 한다.
	var t := _theme()
	var normal := t.get_stylebox("normal", "Button") as StyleBoxTexture
	var hover := t.get_stylebox("hover", "Button") as StyleBoxTexture
	var pressed := t.get_stylebox("pressed", "Button") as StyleBoxTexture
	assert_ne(hover.modulate_color, normal.modulate_color, "hover는 normal과 달라야 한다")
	assert_ne(pressed.modulate_color, normal.modulate_color, "pressed는 normal과 달라야 한다")
	assert_ne(pressed.modulate_color, hover.modulate_color, "pressed는 hover와 달라야 한다")
	# 밝히기 클램프 회피: 모든 채널 ≤ 1.0
	for c in [hover.modulate_color, pressed.modulate_color]:
		assert_true(c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0, "modulate는 LDR 클램프 회피 위해 ≤1.0")

func test_button_focus_is_empty() -> void:
	# 기본 테마의 사각 포커스 아웃라인을 픽셀 UI에서 억제.
	assert_true(_theme().get_stylebox("focus", "Button") is StyleBoxEmpty,
		"Button focus는 StyleBoxEmpty여야 한다")

func test_button_font_colors_defined() -> void:
	var t := _theme()
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		assert_true(t.has_color(key, "Button"), "Button/colors/%s가 정의돼야 한다" % key)

# --- Slice 3: 구분선 · 양피지 · 닫기 아이콘 ---

func test_divider_stylebox_tiled() -> void:
	var sb := _theme().get_stylebox("separator", "HSeparator")
	assert_true(sb is StyleBoxTexture, "HSeparator separator는 StyleBoxTexture")
	assert_eq((sb as StyleBoxTexture).axis_stretch_horizontal,
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "구분선은 가로 타일링")

func test_parchment_panel_defined() -> void:
	assert_true(_theme().get_stylebox("panel", "ParchmentPanel") is StyleBoxTexture,
		"ParchmentPanel panel은 StyleBoxTexture")

func test_parchment_label_is_dark() -> void:
	var t := _theme()
	assert_true(t.has_color("font_color", "ParchmentLabel"), "ParchmentLabel font_color 정의")
	assert_lt(t.get_color("font_color", "ParchmentLabel").v, 0.5,
		"양피지 위 글자색은 어두워야 한다(밝기<0.5)")

func test_modal_close_has_icon() -> void:
	var m = ModalScript.new()
	add_child_autofree(m)
	assert_not_null(m._close_button.icon, "닫기 버튼에 X 아이콘이 지정돼야 한다")
	assert_eq(m._close_button.text, "", "아이콘 사용 시 텍스트는 비어야 한다")

func test_toast_uses_parchment() -> void:
	var t = ToastScript.new()
	add_child_autofree(t)
	assert_eq(t._box.theme_type_variation, &"ParchmentPanel", "토스트 상자=ParchmentPanel")
	# 라벨은 크기(LabelLG)를 변형에서 얻고, 양피지 위 어두운 글자색은 인스턴스 override로 얹는다.
	assert_eq(t._label.theme_type_variation, &"LabelLG", "토스트 라벨=LabelLG")
	assert_lt(t._label.get_theme_color("font_color").v, 0.5, "토스트 라벨 글자색은 어두워야 한다")

# --- Slice 5: 벡터 폰트 전환 (Cafe24 서라운드) ---

func test_bold_font_file_loads() -> void:
	assert_true(load(FONT_BOLD_PATH) is FontFile, "Cafe24 Ssurround(굵게)가 FontFile로 로드돼야 한다")

func test_default_font_is_air() -> void:
	var f := _theme().default_font
	assert_not_null(f, "default_font 지정")
	assert_eq(f.resource_path, FONT_AIR_PATH, "default_font는 Cafe24 Air여야 한다")

func test_title_tier_variation_is_bold() -> void:
	# 타이틀 계층(Label2XL) 변형이 굵은 Ssurround인지(제목 굵게 규칙의 대표 검증).
	var t := _theme()
	assert_true(t.has_font("font", "Label2XL"), "Label2XL 변형에 font가 정의돼야 한다")
	var f := t.get_font("font", "Label2XL")
	assert_eq(f.resource_path, FONT_BOLD_PATH, "Label2XL 폰트는 굵은 Ssurround여야 한다")
	assert_ne(f.resource_path, t.default_font.resource_path, "Label2XL 폰트는 본문(Air)과 달라야 한다")

func test_map_text_uses_air() -> void:
	assert_eq(MapTextScript.TTF.resource_path, FONT_AIR_PATH,
		"map_text.gd의 TTF는 Cafe24 Air를 가리켜야 한다")

func test_modal_title_uses_title_variation() -> void:
	var m = ModalScript.new()
	add_child_autofree(m)
	assert_eq(m._title_label.theme_type_variation, &"LabelLG",
		"모달 타이틀 라벨=LabelLG 변형(굵게 24)")

# --- Slice 6: 타이포그래피 스케일 ---

const _SCALE := {
	"LabelXS": 14,
	"LabelSM": 18,
	"LabelMD": 20,
	"LabelLG": 24,
	"LabelXL": 28,
	"Label2XL": 32,
	"LabelHuge": 64,
	"ButtonXL": 28,
}

func test_button_default_font_size_is_20() -> void:
	assert_eq(_theme().get_font_size("font_size", "Button"), 20,
		"모든 버튼 기본 font_size는 20")

func test_type_scale_font_sizes() -> void:
	var t := _theme()
	for name in _SCALE:
		assert_true(t.has_font_size("font_size", name),
			"%s 변형에 font_size가 정의돼야 한다" % name)
		assert_eq(t.get_font_size("font_size", name), int(_SCALE[name]),
			"%s font_size == %d" % [name, _SCALE[name]])

func test_size_tiers_weight() -> void:
	# 제목 계층(LG/XL/2XL/HUGE)은 굵은 Ssurround, 본문 계층(XS/SM/MD)은 Air 상속.
	var t := _theme()
	for name in ["LabelLG", "LabelXL", "Label2XL", "LabelHuge"]:
		assert_true(t.has_font("font", name), "%s에 font 정의" % name)
		assert_eq(t.get_font("font", name).resource_path, FONT_BOLD_PATH,
			"%s는 굵은 Ssurround여야 한다" % name)
	# 본문 계층은 굵은 폰트를 지정하지 않아 본문(Air)으로 렌더돼야 한다.
	for name in ["LabelXS", "LabelSM", "LabelMD"]:
		assert_ne(t.get_font("font", name).resource_path, FONT_BOLD_PATH,
			"%s은 본문 폰트(Air)여야 한다(굵게 아님)" % name)
