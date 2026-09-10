shader_type canvas_item;

uniform sampler2D water_mask;
uniform int profile = 0;
uniform float phase = 0.0;
uniform bool reduced_motion = false;

float mask_at(vec2 uv) { vec4 m = texture(water_mask, clamp(uv, vec2(.001), vec2(.999))); return m.r * m.a; }
float field(vec2 px, float speed) {
	return sin(dot(px, vec2(.058, .123)) - phase * (4.0 + speed))
		+ sin(dot(px, vec2(-.044, .091)) + phase * (5.0 + speed * .6) + 1.4) * .76
		+ sin(dot(px, vec2(.084, -.166)) - phase * 7.0 + 2.1) * .54
		+ sin(dot(px, vec2(.027, .047)) + phase * 2.0 + 2.9) * .48;
}
float shore_y(float x) {
	if (x < 100.0) return mix(930.0, 995.0, x / 100.0);
	if (x < 200.0) return mix(995.0, 1060.0, (x - 100.0) / 100.0);
	if (x < 300.0) return mix(1060.0, 1110.0, (x - 200.0) / 100.0);
	if (x < 400.0) return mix(1110.0, 1150.0, (x - 300.0) / 100.0);
	if (x < 500.0) return mix(1150.0, 1200.0, (x - 400.0) / 100.0);
	if (x < 600.0) return mix(1200.0, 1230.0, (x - 500.0) / 100.0);
	return mix(1230.0, 1280.0, (x - 600.0) / 120.0);
}
float ocean_shore_weight(vec2 px) {
	float depth = shore_y(px.x) - px.y;
	return smoothstep(-70.0, 0.0, depth) * (1.0 - smoothstep(150.0, 360.0, depth));
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (reduced_motion) { COLOR = base; }
	else {
	// CanvasItem UV coordinates are already top-down for this plate.
	float image_y = UV.y;
	float perspective = mix(.12, 1.0, smoothstep(.40, .90, image_y));
	float strength = profile == 0 ? 1.0 : (profile == 1 ? 1.18 : (profile == 2 ? 1.08 : (profile == 3 ? 1.0 : (profile == 4 ? .82 : (profile == 5 ? .58 : (profile == 6 ? .76 : 1.42))))));
	vec2 px = vec2(UV.x * 720.0, image_y * 1280.0);
	float a = field(px, float(profile)); float b = field(px + vec2(29.0, -17.0), float(profile));
	vec2 shift = vec2(a * 2.15 + b * 1.55, a * 1.15 - b * 1.75) * strength * perspective * .78;
	if (profile == 2) shift += vec2(-1.8 + sin(phase * 3.0 + px.y * .04), .35) * perspective;
	if (profile == 3) { float swell = sin(px.x * .021 + px.y * .038 - phase * 1.4) + sin(px.x * -.014 + px.y * .026 + phase * 2.0 + .8) * .55; shift += vec2(swell * 3.3, swell * 6.6) * perspective; }
	if (profile == 4) shift += vec2(sin(phase * 1.4 + px.y * .018) * .75, .25) * perspective;
	if (profile == 5) shift += vec2(-.45 + sin(phase * .72 + px.y * .012) * .35, .16) * perspective;
	if (profile == 6) shift += vec2(sin(phase * 1.2 + px.x * .014) * 1.2, sin(phase * .9 + px.y * .017) * 1.55) * perspective;
	if (profile == 7) { float bluewater_swell = sin(px.x * .016 + px.y * .030 - phase * 1.15) + sin(px.x * -.010 + px.y * .021 + phase * 1.65 + .6) * .68; shift += vec2(bluewater_swell * 4.2, bluewater_swell * 8.5) * perspective; }
	float displacement_cap = profile == 3 ? 10.0 : (profile == 7 ? 12.5 : (profile > 3 ? 4.5 : 5.0));
	shift *= min(1.0, displacement_cap / max(length(shift), .01));
	// Hatteras gets a bounded shore-space run-up/backwash mapping. It uses the
	// source photo once at the final coordinate, avoiding a high-contrast double
	// image mix that can marble foam during a larger foreground displacement.
	vec2 shore_offset = vec2(0.0);
	if (profile == 3) {
		float depth = shore_y(px.x) - px.y;
		float shoreline_lag = sin(px.x * .005) * .018;
		float run_cycle = .5 - .5 * cos((phase / 6.28318530718 + shoreline_lag) * 6.28318530718);
		float shore_envelope = ocean_shore_weight(px);
		float offshore_envelope = smoothstep(95.0, 165.0, depth) * (1.0 - smoothstep(420.0, 610.0, depth));
		float push = 28.0 * run_cycle * shore_envelope + 7.0 * sin((phase / 6.28318530718 + depth * .004 + px.x * .002) * 6.28318530718) * offshore_envelope;
		shore_offset = normalize(vec2(-.46, 1.0)) * push / vec2(720.0, 1280.0);
	}
	vec2 offset = shift / vec2(720.0, 1280.0) + shore_offset;
	// Sampling against the forward shared displacement makes reflected photo
	// features travel with the CPU bobber's positive offset, rather than opposite.
	float gate = smoothstep(.10, .92, min(mask_at(UV), mask_at(UV - offset)));
	vec3 moved = texture(TEXTURE, clamp(UV - offset, vec2(.001), vec2(.999))).rgb;
	vec3 colour = mix(base.rgb, moved, gate);
	// Generated plates own their irregular photographic highlight detail. The
	// synthetic crest pass is kept only for the original four hand-tuned waters;
	// on the new plates it read as repeated pale oval stamps.
	float crest = profile < 4 ? smoothstep(.965, 1.0, .5 + .5 * field(px + vec2(18.0, -24.0), float(profile))) : 0.0;
	float ocean_crest = profile == 3 ? smoothstep(.66, .98, .5 + .5 * sin(px.x * .021 + px.y * .038 - phase * 1.4)) : 0.0;
	float shine = max(crest * .024, ocean_crest * .052) * gate * perspective;
	COLOR = vec4(mix(colour, vec3(1.0), shine), base.a);
	}
}
