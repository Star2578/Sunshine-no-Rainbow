shader_type canvas_item;

// --- Tuning inputs from GDScript ---
uniform float mutation : hint_range(0.0, 1.0) = 0.0;  // form chaos: 0=clean, 1=full freak
uniform float hue_seed = 0.0;                          // unbounded, driven by cycle_count * golden_ratio
uniform float time_offset = 0.0;


// --- Hue rotation ---
vec3 hue_shift(vec3 color, float shift) {
    float a = shift * TAU;
    float s = sin(a), c = cos(a);
    mat3 m = mat3(
        vec3(0.299 + 0.701*c - 0.168*s, 0.587 - 0.587*c + 0.330*s, 0.114 - 0.114*c - 0.497*s),
        vec3(0.299 - 0.299*c + 0.328*s, 0.587 + 0.413*c + 0.035*s, 0.114 - 0.114*c - 0.292*s),
        vec3(0.299 - 0.300*c - 0.900*s, 0.587 - 0.588*c + 1.050*s, 0.114 + 0.886*c - 0.203*s)
    );
    return clamp(m * color, 0.0, 1.0);
}

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);
    float t = TIME + time_offset;

    // -------------------------------------------------------
    // CORONA SHAPE
    // -------------------------------------------------------
    float spike_freq = mix(6.0, 14.0, mutation);
    float noise  = sin(angle * spike_freq + t * 2.0) * 0.5 + 0.5;
          noise += sin(angle * (spike_freq * 1.7) - t * 1.3) * 0.3;
    float wobble_amount = 0.03 + noise * (0.03 + 0.08 * mutation);
	float corona_radius = mix(0.35, wobble_amount + 0.32, 0.4 + mutation * 0.6);

    float body   = smoothstep(corona_radius, corona_radius - 0.05, dist);
    float corona = smoothstep(0.5, corona_radius, dist) * mix(0.4, 0.7, mutation);
    float alpha  = body + corona * (1.0 - body);

    // -------------------------------------------------------
    // COLOR TERRITORY — three oscillators at irrational ratios
    // hue_seed is unbounded so these never repeat the same combo
    // -------------------------------------------------------
    float h1 = hue_seed * 1.000;    // base drift
    float h2 = hue_seed * 1.618;    // golden ratio desync
    float h3 = hue_seed * 2.718;    // e desync

    vec3 base_color = mix(vec3(1.0, 0.85, 0.2), vec3(1.0, 0.5, 0.1), dist * 2.0);

    // Body and corona shift independently — alien split at high mutation
    vec3 body_color   = hue_shift(base_color, h1 + sin(t * 0.5) * mutation * 0.05);
    vec3 corona_color = hue_shift(base_color, h1 + mutation * 0.8);

    // Third oscillator bleeds in at high mutation only
    vec3 color_c   = hue_shift(base_color, h3);
    float blend_ab = fract(hue_seed * 3.14159);
    vec3 blended   = mix(mix(body_color, corona_color, blend_ab), color_c, mutation * 0.4);

    // Spatially mix: center = body color, edge = corona color
    vec3 color = mix(corona_color, blended, body);

    // -------------------------------------------------------
    // IRIDESCENCE — rainbow oil-slick quality at high mutation
    // -------------------------------------------------------
    float irid = sin(angle * 3.0 + t) * 0.5 + 0.5;
	vec3 irid_color = hue_shift(color, irid * (0.05 + mutation * 0.20));
	color = mix(color, irid_color, 0.15 + mutation * 0.45);

    // -------------------------------------------------------
    // EXTREME TERRITORY — kicks in when hue_seed > 2.0
    // even cycles bleach to white, odd cycles collapse to void
    // -------------------------------------------------------
    float extreme    = clamp((hue_seed - 2.0) * 0.3, 0.0, 1.0);
    float luma       = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 bleached    = vec3(1.0);                    // overloaded white
    vec3 void_color  = vec3(0.05, 0.0, 0.1);         // void purple-black
    vec3 extreme_col = mix(bleached, void_color, mod(floor(hue_seed), 2.0));
    color = mix(color, extreme_col, extreme * mutation);

    // -------------------------------------------------------
    // PULSE — faster and more erratic with mutation
    // -------------------------------------------------------
    float pulse = 1.0 + sin(t * (3.0 + mutation * 4.0)) * (0.06 + 0.12 * mutation);
    color *= pulse;

    COLOR = vec4(color, alpha * COLOR.a);
}