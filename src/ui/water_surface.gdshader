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
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (reduced_motion) { COLOR = base; }
	else {
	// CanvasItem UV coordinates are already top-down for this plate.
	float image_y = UV.y;
	float perspective = mix(.12, 1.0, smoothstep(.40, .90, image_y));
	float strength = profile == 0 ? 1.0 : (profile == 1 ? 1.18 : (profile == 2 ? 1.08 : 1.0));
	vec2 px = vec2(UV.x * 720.0, image_y * 1280.0);
	float a = field(px, float(profile)); float b = field(px + vec2(29.0, -17.0), float(profile));
	vec2 shift = vec2(a * 2.15 + b * 1.55, a * 1.15 - b * 1.75) * strength * perspective * .78;
	if (profile == 2) shift += vec2(-1.8 + sin(phase * 3.0 + px.y * .04), .35) * perspective;
	if (profile == 3) { float swell = sin(px.x * .021 + px.y * .038 - phase * 1.4) + sin(px.x * -.014 + px.y * .026 + phase * 2.0 + .8) * .55; shift += vec2(swell * 3.3, swell * 6.6) * perspective; }
	shift *= min(1.0, (profile == 3 ? 10.0 : 5.0) / max(length(shift), .01));
	vec2 offset = shift / vec2(720.0, 1280.0);
	// Sampling against the forward shared displacement makes reflected photo
	// features travel with the CPU bobber's positive offset, rather than opposite.
	float gate = smoothstep(.10, .92, min(mask_at(UV), mask_at(UV - offset)));
	vec3 moved = texture(TEXTURE, clamp(UV - offset, vec2(.001), vec2(.999))).rgb;
	vec3 colour = mix(base.rgb, moved, gate);
	float crest = smoothstep(.965, 1.0, .5 + .5 * field(px + vec2(18.0, -24.0), float(profile)));
	float ocean_crest = profile == 3 ? smoothstep(.66, .98, .5 + .5 * sin(px.x * .021 + px.y * .038 - phase * 1.4)) : 0.0;
	float shine = max(crest * .024, ocean_crest * .052) * gate * perspective;
	COLOR = vec4(mix(colour, vec3(1.0), shine), base.a);
	}
}
