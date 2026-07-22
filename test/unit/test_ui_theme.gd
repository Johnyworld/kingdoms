extends GutTest
## 중세풍 UI 테마(Slice 1) — medieval_theme.tres + 갈무리14 폰트 + DarkAgesUi 타일시트.
## 전역 테마 등록·프레임 StyleBox·모달 OrnatePanel 변형을 검증한다. → docs/spec/features/ui-theme.md

const THEME_PATH := "res://assets/ui/medieval_theme.tres"
const FONT_PATH := "res://assets/ui/fonts/Galmuri14.ttf"
const SHEET_PATH := "res://assets/ui/darkages/32x32-Tilesheet@3x.png"
const ModalScript = preload("res://scenes/modal/modal.gd")

func _theme() -> Theme:
	return load(THEME_PATH) as Theme

# --- 테마 리소스 ---

func test_theme_loads() -> void:
	assert_not_null(_theme(), "medieval_theme.tres가 Theme로 로드돼야 한다")

func test_theme_default_font() -> void:
	var t := _theme()
	assert_not_null(t.default_font, "테마 default_font가 지정돼야 한다")
	assert_eq(t.default_font_size, 14, "테마 default_font_size는 14")

func test_font_file_loads() -> void:
	var f = load(FONT_PATH)
	assert_true(f is FontFile, "Galmuri14.ttf가 FontFile로 로드돼야 한다")

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
