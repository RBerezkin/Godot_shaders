shader_type spatial;


// rooms tiling
uniform float _tiling: hint_range(1, 100, 1) = 6.0;
// how many rooms in texture
uniform vec2 _room_variations = vec2(1.0);
// rooms texture atlas
uniform sampler2D _room_tex: hint_albedo;


// eye vector in tangent space
varying vec3 t_eye_vec;


void vertex() {
	// transform matrix from object space to tangent space
	mat3 TBN = transpose(mat3(TANGENT, -BINORMAL, NORMAL));
	// camera position in object space
	vec3 o_cam_pos = inverse(MODELVIEW_MATRIX)[3].xyz;
	// eye vector in object space
	vec3 o_eye_vec = VERTEX - o_cam_pos;
	
	// eye vector in tangent space
	t_eye_vec = TBN * o_eye_vec;
}


vec2 rand(float n) {
	return fract(sin(n * vec2(12.9898,78.233)) * 43758.5453);
}


void fragment() {
	// need seperate variable because varying can't be modified
	vec3 t_view_dir = t_eye_vec;
	
	// room uvs
	vec2 room_UV = fract(UV * _tiling);
	vec2 room_index_UV = floor(UV * _tiling);
	
	// randomize the room
	vec2 n = floor(rand(room_index_UV.x + room_index_UV.y * (room_index_UV.x + 1.0)) * _room_variations.xy);
	room_index_UV += n;
	
	// get room depth from room atlas alpha
	float far_frac = texture(_room_tex, (room_index_UV + 0.5) / _room_variations.xy).a;
	float depth_scale = 1.0 / (1.0 - far_frac) - 1.0;
	
	t_view_dir.z *= -depth_scale;
	
	// raytrace box from view dir
	vec3 pos = vec3(room_UV * 2.0 - 1.0, -1.0);
	vec3 id = 1.0 / t_view_dir;
	vec3 dist = abs(id) - pos * id;
	float dist_min = min(min(dist.x, dist.y), dist.z);
	
	pos += dist_min * t_view_dir;
	
	// map room depth
	// from -1.0 - 1.0
	// to    0.0 - 1.0
	float interp = pos.z * 0.5 + 0.5;
	
	// account for perspective in [_room_tex] textures
	// assumes camera with an fov of 53.13 degrees (atan(0.5))
	float real_z = clamp(interp, 0.0, 1.0) / depth_scale + 1.0;
	interp = 1.0 - (1.0 / real_z);
	interp *= depth_scale + 1.0;
	
	// iterpolate from wall back to near wall
	vec2 interior_UV = pos.xy * mix(1.0, far_frac, interp);
	interior_UV = interior_UV * 0.5 + 0.5;
	
	// sample room atlas texture
	vec4 room = texture(_room_tex, (room_index_UV + interior_UV.xy) / _room_variations.xy);
	
	ALBEDO = room.rgb;
}
