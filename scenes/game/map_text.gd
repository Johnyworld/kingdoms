class_name MapText
## 지도 위 world-space 텍스트를 선명하게 그리는 공용 헬퍼(부대 인원 배지·거점/세력 라벨 등).
## 좌표·크기는 16px 헥스 월드 기준으로 작게 잡되, 기본 카메라 3배 줌(16px→48px)에서 뭉개지지 않도록
## 글리프를 SUPERSAMPLE배 해상도로 래스터한 뒤 1/배 축소한다(48px 헥스급 디테일).
## ⚠️ 호출하는 CanvasItem은 `texture_filter = TEXTURE_FILTER_NEAREST`여야 확대 시 선명하다.
## 폰트는 Cafe24 서라운드 Air(본문) + 합성 볼드(작은 글자 가독성). 슈퍼샘플로 래스터하므로 벡터도 선명하다.

const SUPERSAMPLE := 3
const EMBOLDEN := 0.4
const TTF := preload("res://assets/ui/fonts/Cafe24SsurroundAir.otf")

static var _font: FontVariation
## Cafe24 Air + 합성 볼드 폰트(전역 공유, 지연 생성).
static func font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = TTF
		_font.variation_embolden = EMBOLDEN
	return _font

## ci의 _draw 안에서 호출. text를 (center_x, baseline_y)에 가로 중앙 정렬로 슈퍼샘플 렌더한다.
## font_size는 월드(16px 헥스) 기준 크기.
static func draw_centered(ci: CanvasItem, text: String, center_x: float, baseline_y: float, font_size: int, color: Color) -> void:
	var f := font()
	var fs := font_size * SUPERSAMPLE
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_set_transform(Vector2(center_x, baseline_y), 0.0, Vector2.ONE / float(SUPERSAMPLE))
	ci.draw_string(f, Vector2(-w * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
