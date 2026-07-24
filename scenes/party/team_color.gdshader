shader_type canvas_item;

// 세력색 팔레트 스왑 셰이더 (팀컬러). 맵 토큰(party.gd)·전투 병사(lang_battlefield.gd) 공용.
// 원본 유닛 스프라이트에서 "세력색 존"(붉은 튜닉/머리)만 골라 team_color로 치환하되,
// 원본 픽셀의 명암(밝기)을 유지해 곱셈 합성한다 → 단색 덩어리가 아니라 명암 있는 세력색.
//
// [임시 마스크] 존은 key_color 색조(hue)에 가깝고 채도↑·밝기↓인 픽셀을 자동 선택한다.
//   - 채도/밝기 조건이 밝은 얼굴 피부를 1차 제외한다.
//   - 눈동자는 튜닉/머리와 같은 붉은 색이라 색만으론 못 거른다 → 이웃에 피부가 여러 방향(eye_skin_threshold개
//     이상) 있으면 "피부에 둘러싸인 눈"으로 보고 제외한다(눈은 피부에 박혀 있고, 머리 가장자리는 한쪽만 닿음).
// 실사용 정밀화 시 이 자동 판정을 아티스트가 그린 마스크 텍스처 샘플링으로 교체할 수 있다.

uniform vec4 team_color : source_color = vec4(0.2, 0.3, 0.8, 1.0);
uniform vec3 key_color : source_color = vec3(0.40, 0.125, 0.125); // 대체할 원본 존 색(붉은 튜닉/머리)
uniform float hue_tolerance = 0.08;   // 색조 허용 오차(원 위 거리)
uniform float min_saturation = 0.55;  // 이 이상 채도만 — 진한 튜닉/머리는 통과, 채도 낮은 피부는 제외
uniform float max_value = 0.70;       // 이 이하 밝기만 — 어두운 튜닉/머리는 통과, 밝은 얼굴 피부는 제외
uniform float strength = 1.0;         // 0=원본(치환 안 함), 1=완전 치환. 전투의 세력 없는 시나리오는 0.
uniform float flash : hint_range(0.0, 1.0) = 0.0;  // 피격 흰색 플래시(전투 공용). 0=없음.
// 눈 제외(피부에 둘러싸인 붉은 눈동자 보호).
uniform float eye_guard = 1.0;             // 0=끔, 1=켬
uniform float skin_min_value = 0.72;       // 피부 판정 밝기 하한
uniform float skin_max_saturation = 0.50;  // 피부 판정 채도 상한
uniform float eye_skin_threshold = 3.0;    // 이 개수 이상 피부 이웃이면 눈으로 보고 제외

const vec2 NEIGHBORS[8] = {
	vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(1.0, -1.0),
	vec2(-1.0, 0.0),                    vec2(1.0, 0.0),
	vec2(-1.0, 1.0),  vec2(0.0, 1.0),  vec2(1.0, 1.0)
};

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// 붉은 피부톤(밝고 채도 낮음) 여부 — 눈 주변 얼굴 판정용.
bool is_skin(vec3 c) {
	vec3 hsv = rgb2hsv(c);
	bool reddish = hsv.x <= 0.10 || hsv.x >= 0.90;
	return hsv.z >= skin_min_value && hsv.y <= skin_max_saturation && reddish;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	vec3 key = rgb2hsv(key_color);

	// 색조 원형 거리 → 존 여부(마스크). 채도 낮은(회색/피부)·너무 밝은(얼굴 피부)·투명 픽셀 제외.
	float dh = abs(hsv.x - key.x);
	dh = min(dh, 1.0 - dh);
	float mask = step(dh, hue_tolerance) * step(min_saturation, hsv.y) * step(hsv.z, max_value) * step(0.01, tex.a);

	// 눈 제외: 존 픽셀이 피부에 여러 방향 둘러싸이면 눈으로 보고 뺀다(머리·튜닉은 유지).
	if (mask > 0.5 && eye_guard > 0.5) {
		float skin_n = 0.0;
		for (int i = 0; i < 8; i++) {
			vec4 n = texture(TEXTURE, UV + NEIGHBORS[i] * TEXTURE_PIXEL_SIZE);
			if (n.a > 0.5 && is_skin(n.rgb)) {
				skin_n += 1.0;
			}
		}
		if (skin_n >= eye_skin_threshold) {
			mask = 0.0;
		}
	}
	mask *= strength;

	// 원본 밝기(value)를 key 밝기 기준으로 정규화해 team_color에 곱함 → 명암 보존.
	vec3 recolored = team_color.rgb * (hsv.z / max(key.z, 0.001));

	vec3 outc = mix(tex.rgb, recolored, mask);
	outc = mix(outc, vec3(1.0), flash);   // 피격 플래시(전투). 세력색 치환 뒤 흰색으로 덮음.
	COLOR = vec4(outc, tex.a);
}
