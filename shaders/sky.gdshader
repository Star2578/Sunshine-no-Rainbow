shader_type canvas_item;

uniform float time_of_day : hint_range(0.0, 24.0) = 6.0;

void fragment() {
    // Normalize time into 0..1 for easier math
    float t = time_of_day / 24.0;
    float y = UV.y;  // 0 = top, 1 = bottom

    // -------------------------------------------------------
    // SKY COLOR KEYFRAMES
    // Define sky color at key times, lerp between them
    // -------------------------------------------------------
    vec3 night   = mix(vec3(0.01, 0.01, 0.08), vec3(0.04, 0.04, 0.15), y);  // deep navy → slightly lighter horizon
    vec3 dawn    = mix(vec3(0.55, 0.25, 0.35), vec3(0.95, 0.55, 0.25), y);  // purple top → warm orange horizon
    vec3 morning = mix(vec3(0.35, 0.60, 0.90), vec3(0.75, 0.88, 1.00), y);  // sky blue → pale horizon
    vec3 noon    = mix(vec3(0.20, 0.48, 0.95), vec3(0.55, 0.80, 1.00), y);  // deep blue → bright horizon
    vec3 dusk    = mix(vec3(0.40, 0.20, 0.50), vec3(0.95, 0.45, 0.15), y);  // purple top → deep orange horizon

    // -------------------------------------------------------
    // BLEND BETWEEN KEYFRAMES based on time_of_day
    // 0  = midnight, 6 = dawn, 9 = morning, 12 = noon
    // 18 = dusk,     21 = night returns
    // -------------------------------------------------------
    vec3 sky;

    if (time_of_day < 6.0) {
        // midnight → dawn (0 to 6)
        sky = mix(night, dawn, smoothstep(0.0, 6.0, time_of_day));
    } else if (time_of_day < 9.0) {
        // dawn → morning (6 to 9)
        sky = mix(dawn, morning, smoothstep(6.0, 9.0, time_of_day));
    } else if (time_of_day < 12.0) {
        // morning → noon (9 to 12)
        sky = mix(morning, noon, smoothstep(9.0, 12.0, time_of_day));
    } else if (time_of_day < 18.0) {
        // noon → dusk (12 to 18)
        sky = mix(noon, dusk, smoothstep(12.0, 18.0, time_of_day));
    } else if (time_of_day < 21.0) {
        // dusk → night (18 to 21)
        sky = mix(dusk, night, smoothstep(18.0, 21.0, time_of_day));
    } else {
        // stays night (21 to 24)
        sky = night;
    }

    // -------------------------------------------------------
    // STARS — only visible at night
    // -------------------------------------------------------
    float night_amount = 1.0 - smoothstep(4.5, 6.5, time_of_day)   // fade out at dawn
                             + smoothstep(18.5, 21.0, time_of_day); // fade in at dusk
    night_amount = clamp(night_amount, 0.0, 1.0);

    // Cheap hash-based star field
    vec2 star_uv = floor(UV * 120.0);
    float star_hash = fract(sin(dot(star_uv, vec2(127.1, 311.7))) * 43758.5);
    float star = step(0.985, star_hash);  // only ~1.5% of cells get a star
    // Twinkle
    float twinkle_phase = fract(star_hash * 13.7) * TAU;
    float twinkle = 0.6 + 0.4 * sin(TIME * (1.5 + star_hash * 2.0) + twinkle_phase);
    star *= twinkle * night_amount;

    sky += vec3(star);

    COLOR = vec4(sky, 1.0);
}