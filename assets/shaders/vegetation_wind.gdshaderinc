// Wind for vegetation, shared by vegetation_wind_leaves.gdshader and vegetation_wind_bark.gdshader.
//
// The sway is a vertex offset in world metres: nothing of it is stored in the meshes, so it works on
// every instance of a multimesh (the Terrain3D instancer) with no per-instance data. What a plant does depends
// only on where it stands (the instance's origin) and on the time, so a whole field moves as one wind:
//   - big, slow gust fronts roll across the land along the wind direction, with calm between them;
//   - plants lean downwind as a gust reaches them and spring back as it passes (a steady lean, with a
//     swing round it that grows with the gust);
//   - the swing is a wave through the field (grass ripples), and the tips lag behind the bases;
//   - the push is weighted by the vertex's height over the plant's base, so roots stay planted;
//   - leaves quiver, more in a gust.
//
// It is cheap on purpose (a vertex shader runs for every vertex of every plant, and trees cast shadows too):
// plants beyond `wind_distance` metres of the camera do no wind maths at all (a sway of a few centimetres cannot
// be seen from there), the sway fades out over the last third of that distance, and the instance's transform is
// undone with a transpose (instances are only turned and evenly scaled).

// Everything is in the plant's own scale (a plant instanced at twice the size sways twice as far).
uniform float wind_strength : hint_range(0.0, 2.0) = 1.0;
// The direction the wind blows toward, in the ground plane (x, z).
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_speed : hint_range(0.0, 4.0) = 1.0;
// How far the tip leans, in metres, at the bend height in a medium gust (before wind strength and the instance's scale).
uniform float sway_amount : hint_range(0.0, 2.0) = 0.2;
// The height (in the mesh's own units) at which the sway is at its full amount.
uniform float bend_height : hint_range(0.05, 40.0) = 1.0;
// How far single leaves quiver, in metres, in a medium gust.
uniform float flutter_amount : hint_range(0.0, 0.2) = 0.0;
// Beyond this distance from the camera the plant stands still.
uniform float wind_distance : hint_range(10.0, 300.0) = 70.0;

// The offset to add to a vertex (in the mesh's local space) at `time`. `model` is MODEL_MATRIX.
vec3 wind_local_offset(vec3 vertex, mat4 model, vec3 camera, float time) {
	vec3 origin = model[3].xyz;
	vec3 to_camera = origin - camera;
	float near_fade = 1.0 - smoothstep(wind_distance * 0.65, wind_distance, length(to_camera));
	if (near_fade <= 0.0 || wind_strength <= 0.0) {
		return vec3(0.0);
	}

	float height_ratio = clamp(vertex.y / bend_height, 0.0, 1.5);
	float height_weight = height_ratio * height_ratio;
	if (height_weight <= 0.0) {
		return vec3(0.0);
	}

	mat3 basis = mat3(model);
	float scale_squared = dot(basis[1], basis[1]);
	float scale = sqrt(scale_squared);

	vec2 dir = normalize(wind_direction);
	float t = time * wind_speed;
	float along = dot(origin.xz, dir);
	float across = dot(origin.xz, vec2(-dir.y, dir.x));

	// Gust fronts: broad waves rolling downwind (some 60 to 140 metres between crests), a faster, shorter set
	// riding on them. Mostly a steady breeze, with gusts that come and go: 0.2 in the lulls, about 1.5 at the crests.
	float front_big = sin(along * 0.05 - t * 0.85 + across * 0.014);
	float front_small = sin(along * 0.12 - t * 1.7 + across * 0.03 + 1.7);
	float gust = clamp(0.55 + 0.55 * front_big + 0.3 * front_small, 0.15, 1.6);

	// The plant leans downwind as much as the gust pushes it, and swings round that lean: a wave through the field
	// (the `along` term), the tip behind the base (the `height_ratio` term), the swing growing with the gust.
	float lean = gust;
	float swing = sin(t * 2.2 - along * 0.55 - height_ratio * 1.3 + origin.x * 0.35) * (0.2 + 0.4 * gust);
	float amount = sway_amount * scale * wind_strength * near_fade * height_weight * (lean + swing);

	vec3 world_push = vec3(dir.x, 0.0, dir.y) * amount;
	// A little sideways, out of step with the swing.
	world_push += vec3(-dir.y, 0.0, dir.x) * sway_amount * scale * wind_strength * near_fade * height_weight * 0.3 * sin(t * 2.9 - across * 0.4 + origin.z * 0.8 - height_ratio);
	// A bent stem is shorter: the more it leans the lower its tip.
	world_push.y -= amount * amount * 0.5 / max(vertex.y * scale, 0.2);

	if (flutter_amount > 0.0) {
		float quiver = sin(t * 8.1 + dot(vertex, vec3(11.0, 7.0, 13.0))) * flutter_amount * wind_strength * near_fade * min(height_weight, 1.0) * (0.4 + gust);
		world_push += vec3(quiver * 0.5, quiver * 0.3, quiver * 0.5);
	}

	// Into the mesh's own space: the transpose of a turned, evenly scaled basis, undone by its scale twice.
	return (transpose(basis) * world_push) / scale_squared;
}

// A clearing along the walk of a camera that is not the player's (the recorded tape's, which goes through the forest at head height): a plant whose root is nearer the segment `clearing_a`..`clearing_b`
// than the radius is shrunk to nothing, one within the band beyond it part of the way. It is set once for a whole shot (the hard cut hides the change) so that no plant is ever seen to shrink, and no
// leaf passes through the lens. xyz of `clearing_a` is the start, its w the radius (0 is off); only the ground plane counts. Not saved; the scene's own plants are untouched.
uniform vec4 clearing_a = vec4(0.0);
uniform vec3 clearing_b = vec3(0.0);
uniform float clearing_band : hint_range(0.05, 3.0) = 0.4;

// A body going through the plants (the player): the plants near it are pushed away from it, bending from the root (the push is weighted by the vertex's height over its base, so the root stays planted), the more the
// closer they are and the faster it goes; the ones it touches shiver. This is what most games do (a position, or a few, given to the shader and no state): `actor` is where its feet are (xyz, world metres) and its
// speed in w (m/s), `actor_radius` how far it reaches (0 is off). Only plants as high as the body are moved (none above its head).
uniform vec4 actor = vec4(0.0, -10000.0, 0.0, 0.0);
uniform float actor_radius : hint_range(0.0, 3.0) = 0.0;

vec3 actor_local_offset(vec3 vertex, mat4 model, float time) {
	if (actor_radius <= 0.0) {
		return vec3(0.0);
	}

	float height_ratio = clamp(vertex.y / max(bend_height, 0.05), 0.0, 1.5);
	float weight = height_ratio * height_ratio;
	if (weight <= 0.0) {
		return vec3(0.0);
	}

	mat3 basis = mat3(model);
	float scale_squared = dot(basis[1], basis[1]);
	float scale = sqrt(scale_squared);
	vec3 root = model[3].xyz;
	vec3 world = root + basis * vertex;
	vec2 away = world.xz - actor.xz;
	float dist = length(away);
	float influence = 1.0 - smoothstep(actor_radius * 0.2, actor_radius, dist);
	float above = world.y - actor.y;
	influence *= 1.0 - smoothstep(1.3, 2.1, above);
	influence *= smoothstep(-0.6, -0.1, above);
	if (influence <= 0.0) {
		return vec3(0.0);
	}

	// Away from the body (a plant right under the feet is thrown the way its own position leans).
	vec2 dir = dist > 0.04 ? away / dist : normalize(vec2(sin(root.x * 12.9), cos(root.z * 7.3)) + vec2(0.001));
	float speed = clamp(actor.w / 3.0, 0.0, 1.0);
	// How far the tip goes: up to about half the plant's height at a standstill beside it, more when it is going by quickly.
	float reach = max(bend_height, 0.25) * scale * (0.45 + 0.25 * speed);
	vec3 push = vec3(dir.x, 0.0, dir.y) * reach * influence * weight;
	// A bent stem is shorter.
	push.y -= reach * influence * weight * 0.35;
	// The shiver of what has just been brushed.
	float shiver = sin(time * 17.0 + dot(root.xz, vec2(5.3, 8.1))) * 0.06 * reach * influence * weight * (0.3 + speed);
	push += vec3(shiver, 0.0, -shiver * 0.7);
	return (transpose(basis) * push) / scale_squared;
}

// A rectangle of ground (x min, z min, x max, z max, in world metres) under which no plant shows: the plants whose root lies in it, lower than `hide_below` (a height in world metres), are shrunk to nothing. Used for the ground under
// the waiting shed's slab, where the terrain's low plants would show through the concrete. Zero is off. Not saved: the terrain's own data is untouched.
uniform vec4 hide_rect = vec4(0.0);
uniform float hide_below = 1000.0;

vec3 clearing_apply(vec3 vertex, mat4 model) {
	if (hide_rect.z > hide_rect.x) {
		vec3 root = model[3].xyz;
		if (root.x > hide_rect.x && root.x < hide_rect.z && root.z > hide_rect.y && root.z < hide_rect.w && root.y < hide_below) {
			return vec3(0.0);
		}
	}
	if (clearing_a.w <= 0.0) {
		return vertex;
	}
	vec2 p = model[3].xz;
	vec2 a = clearing_a.xz;
	vec2 ab = clearing_b.xz - a;
	float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	float d = distance(p, a + ab * h);
	return vertex * smoothstep(clearing_a.w, clearing_a.w + clearing_band, d);
}
