package main

import "core:mem"
import "core:math"

Camera :: struct {
	pos: math.Vec3,
	dir: math.Vec3
}

Sphere :: struct {
	center: math.Vec3,
	radius: f32
}

World :: struct {
	s: Sphere,
	c: Camera
}




initialize_world :: proc (world: ^World) {
	world.s.radius = 1;
	world.s.center = math.Vec3{0.0, 0.0, -10};
	world.c.pos = math.Vec3{0.0, 0.0, 0.0};
	world.c.dir = math.Vec3{0.0, 0.0, -1.0};
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


ray_cast :: proc (origin: math.Vec3, dir: math.Vec3, world: ^World) -> bool {
	t0: f32 = math.F32_MAX;
	t1: f32 = math.F32_MAX;
	return intersect_sphere(world.s, origin, dir, &t0, &t1);
}


render :: proc (buffer: ^Image_Buffer, world: ^World) {
	//draw_rect(buffer, 100, 100, 100, 100);
	origin := world.c.pos;
	camera_z := math.norm(world.c.dir) * -1;
	camera_x : math.Vec3 = math.norm(math.cross(camera_z, math.Vec3{0, -1, 0}));
	camera_y := math.norm(math.cross(camera_z, camera_x));

	film_dist: f32 = 1.0;
	film_w: f32 = f32(buffer.width) / f32(buffer.height);
	film_h: f32 = 1.0;
	half_film_w := film_w * 0.5;
	half_film_h := film_h * 0.5;
	film_center := origin - camera_z * film_dist;

	pixel: ^u32 = cast(^u32)buffer.data;
	for y: i32 = 0; y < buffer.height; y += 1 {
		film_y := 2.0 * (f32(y) / f32(buffer.height)) - 1.0;
		for x: i32 = 0; x < buffer.width; x += 1 {
			film_x := 2.0 * (f32(x) / f32(buffer.width)) - 1.0;
			film_p := film_center + (camera_y * film_y * half_film_h) + (film_x * half_film_w * camera_x);

			ray_dir: math.Vec3 = math.norm(film_p - origin);
			if(ray_cast(origin, ray_dir, world)) do pixel^ = 0x0000ff00;
			pixel = mem.ptr_offset(pixel, 1);
		}
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
