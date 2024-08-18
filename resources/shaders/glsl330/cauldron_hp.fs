#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0; // blood mask
uniform vec4 colDiffuse;

uniform sampler2D cauldronBlood;
uniform float healthRatio;

// Output fragment color
out vec4 finalColor;

void main()
{
    const float uv_v_begin = 47.0 / 255.0;
    const float uv_v_end = 195.0 / 255.0;

    float health_ratio_relative_begin = mix(uv_v_end, uv_v_begin, healthRatio);
    bool is_less_health_ratio_begin = fragTexCoord.y < health_ratio_relative_begin;

    bool v_out_of_mask_range = fragTexCoord.y < uv_v_begin || fragTexCoord.y > uv_v_end;
    if (is_less_health_ratio_begin || v_out_of_mask_range) {
        discard;
        return;
    }

    vec4 blood_mask_pixel = texture(texture0, fragTexCoord);
    if (blood_mask_pixel.a < 0.1) {
        discard;
        return;
    }

    float v_offset = (uv_v_end - uv_v_begin) * (1 - healthRatio);
    vec2 moved_coord = vec2(fragTexCoord.x, fragTexCoord.y - v_offset);
    vec4 blood_pixel = texture(cauldronBlood, moved_coord);
    finalColor = blood_pixel;
}
