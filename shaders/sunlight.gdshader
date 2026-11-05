shader_type canvas_item;
// 全屏暖阳叠加：左上方向斜射的日光 + 右下角偏冷的空气，给纯像素画面加一点光照氛围
// 纯加法混合，不采样屏幕纹理，Web(Compatibility) 下也稳定

uniform vec3 warm : source_color = vec3(1.0, 0.87, 0.63);
uniform vec3 cool : source_color = vec3(0.46, 0.55, 0.82);
uniform float strength : hint_range(0.0, 1.0) = 0.20;

void fragment() {
	vec2 uv = UV;
	// 日光梯度：越靠左上越亮
	float sun = clamp(1.0 - (uv.x * 1.05 + uv.y * 0.8) / 1.55, 0.0, 1.0);
	sun = sun * sun;
	// 从左上角光斑向外衰减的柔光
	float spot = 1.0 - clamp(distance(uv, vec2(0.26, 0.14)) * 1.45, 0.0, 1.0);
	float light = sun * (0.6 + 0.4 * spot);
	vec3 col = mix(cool * 0.18, warm, clamp(light * 1.6, 0.0, 1.0));
	float alpha = (0.06 + light * 0.94) * strength;
	COLOR = vec4(col, alpha);
}
