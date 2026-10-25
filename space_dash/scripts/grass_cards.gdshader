shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D blade_texture : source_color, filter_nearest;
uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform bool debug_normals = false;
varying vec4 blade_tint;
void vertex() {
    blade_tint = COLOR;
    float tip = clamp(1.0 - UV.y, 0.0, 1.0);
    vec3 world = VERTEX;
    float cloud = texture(wind_noise, world.xz / 3000.0 + vec2(TIME * 0.001, TIME * 0.0007)).r;
    blade_tint.rgb *= mix(0.88, 1.06, cloud);
    float gust = cloud; // Share the broad gust sample with cloud tint; no second lookup.
    float sway = sin(TIME * 0.7 + world.x * 0.004 + world.z * 0.003);
    world.xz += vec2(1.0, 0.35) * (sway * 0.5 + (gust - 0.5) * 0.8) * tip * tip;
    VERTEX = world;
    // world_vertex_coords presents vertices AND normals in world space.
    // Godot subsequently transforms this world-up normal into view space.
    NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
    // Double-sided rasterization may flip interpolated vertex normals on back faces.
    // Fragment normals are view-space: enforce world-up after that flip.
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    vec4 leaf = texture(blade_texture, UV);
    ALBEDO = leaf.rgb * blade_tint.rgb;
    ROUGHNESS = 1.0;
    ALPHA = leaf.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    if (debug_normals) {
        ALBEDO = vec3(0.0);
        EMISSION = (normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz) + 1.0) * 0.5;
    }
}
