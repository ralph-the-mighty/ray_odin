package main

import "core:mem"
import "core:math"
import "core:fmt"
import "core:math/rand"

Camera :: struct {
	pos: math.Vec3,
	dir: math.Vec3
}

Sphere :: struct {
	center: math.Vec3,
	radius: f32,
	color: u32
}

World :: struct {
	spheres: [dynamic]Sphere,
	camera: Camera
}






initialize_world :: proc (world: ^World) {

	s: Sphere = {math.Vec3{-2,0,0}, 1, rand.uint32()};
	append(&world.spheres, s);

	s2: Sphere = {math.Vec3{2,0,0}, 1, rand.uint32()};
	append(&world.spheres, s2);

	// world.s[0].radius = 1;
	// world.s[0].center = math.Vec3{ 2, 0, -10};
	// world.s[1].radius = 1;
	// world.s[1].center = math.Vec3{-2, 0, -10};

	world.camera.pos = math.Vec3{0.0, 0.0, 20.0};
	world.camera.dir = math.Vec3{0.0, 0.0, -1.0};
}


intersect_sphere :: proc (s: Sphere, rayorig: math.Vec3, raydir: math.Vec3, t0: ^f32, t1: ^f32) -> bool {
	l: math.Vec3 = s.center - rayorig;
	tca: f32 = math.dot(l, raydir);
	if (tca < 0) do return false;
	d2: f32 = math.dot(l, l) - tca * tca;
	if (d2 > s.radius * s.radius) do return false;
	thc: f32 = math.sqrt((s.radius * s.radius) - d2);
	t0^ = tca - thc;
	t1^ = tca + thc;

	return true;
}

buffer_coords_to_film_point :: proc(buffer: ^Image_Buffer, camera: ^Camera, x: int, y: int) -> math.Vec3 {
	origin := camera.pos;
	camera_z := math.norm(camera.dir) * -1;
	camera_x : math.Vec3 = math.norm(math.cross(camera_z, math.Vec3{0, -1, 0}));
	camera_y := math.norm(math.cross(camera_z, camera_x));

	film_dist: f32 = 1.0;
	film_w: f32 = f32(buffer.width) / f32(buffer.height);
	film_h: f32 = 1.0;
	half_film_w := film_w * 0.5;
	half_film_h := film_h * 0.5;
	film_center := origin - camera_z * film_dist;

	film_x := 2.0 * (f32(x) / f32(buffer.width)) - 1.0;
	film_y := 2.0 * (f32(y) / f32(buffer.height)) - 1.0;
	film_p := film_center + (camera_y * film_y * half_film_h) + (film_x * half_film_w * camera_x);
	return film_p;
}


ray_cast :: proc (origin: math.Vec3, dir: math.Vec3, world: ^World) -> u32 {
	t0: f32 = math.F32_MAX;
	t1: f32 = math.F32_MAX;
	hit_distance: f32 = math.F32_MAX;
	hit: bool;
	hit_color: u32;
	//cast against spheres
	for i := 0; i < len(world.spheres); i += 1 {
		if(intersect_sphere(world.spheres[i], origin, dir, &t0, &t1)) {
			hit = true;
			if(t0 < 0) do t0 = t1;
			if(t0 < hit_distance) {
				hit_distance = t0;
				hit_color = world.spheres[i].color;
			}
		}
	}
	
	if(hit) {
		return hit_color;
	} else {
		return 0;
	}
}


draw_rect :: proc(buffer: ^Image_Buffer, x: int, y: int, width: int, height: int) {
	for yy := y ; yy < y + height; yy += 1 {
		for xx := x; xx < x + width; xx += 1 {
			row: ^u32 = cast(^u32)(mem.ptr_offset(buffer.data, yy * int(buffer.pitch)));
			pixel: ^u32 = cast(^u32)(mem.ptr_offset(row, xx));
			pixel^ = 0x0000ffff;
		}
	}
}



update :: proc (world: ^World) {
	//assuming camera desires to rotate around the world origin
	dist: f32 = math.length(world.camera.pos);
	fmt.printf("length: %f\n", dist);
	theta: f32 = 0.05;
	//world.camera.pos.x += 0.01;

	x := world.camera.pos.x;
	z := world.camera.pos.z;
	newx := x * math.cos(theta) - z * math.sin(theta);
	newz := z * math.cos(theta) + x * math.sin(theta);

	world.camera.pos.x = newx;
	world.camera.pos.z = newz;

	world.camera.dir.x = -newx / dist;
	world.camera.dir.z = -newz / dist;

}



render :: proc (buffer: ^Image_Buffer, world: ^World) {
	//draw_rect(buffer, 100, 100, 100, 100);
	origin := world.camera.pos;
	camera_z := math.norm(world.camera.dir) * -1;
	camera_x : math.Vec3 = math.norm(math.cross(camera_z, math.Vec3{0, -1, 0}));
	camera_y := math.norm(math.cross(camera_z, camera_x));

	film_dist: f32 = 1.0;
	film_w: f32 = f32(buffer.width) / f32(buffer.height);
	film_h: f32 = 1.0;
	half_film_w := film_w * 0.5;
	half_film_h := film_h * 0.5;
	film_center := origin - camera_z * film_dist;

	//pixel: ^u32 = cast(^u32)buffer.data;
	base_ptr: ^u32 = cast(^u32)buffer.data;
	for y: i32 = 0; y < buffer.height; y += 2 {
		film_y := 2.0 * (f32(y) / f32(buffer.height)) - 1.0;
		for x: i32 = 0; x < buffer.width; x += 2 {

			pixel: ^u32 = mem.ptr_offset(base_ptr, int(x + y * buffer.width));



			film_x := 2.0 * (f32(x) / f32(buffer.width)) - 1.0;
			film_p := film_center + (camera_y * film_y * half_film_h) + (film_x * half_film_w * camera_x);

			ray_dir: math.Vec3 = math.norm(film_p - origin);
			pixel^ = ray_cast(origin, ray_dir, world);
		}
	}
}
