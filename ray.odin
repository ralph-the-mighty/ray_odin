package main

import "core:mem"
import "core:math"
import "core:fmt"
import "core:math/rand"
import "pl"




Material :: struct {
	color: math.Vec3
}



Camera :: struct {
	pos: math.Vec3,
	dir: math.Vec3
}

Sphere :: struct {
	center: math.Vec3,
	radius: f32,
	mat: Material
}

World :: struct {
	spheres: [dynamic]Sphere,
	camera: Camera
}




v3_to_u32 :: proc(v: math.Vec3) -> u32 {
	pixel: u32 = (u32(v.x * 255) << 16) |
				 (u32(v.y * 255) << 8) |
				 (u32(v.z * 255));
	return pixel;
}


rand_v3 :: proc() -> math.Vec3 {
	return math.Vec3{rand.float32_range(0, 1),
				     rand.float32_range(0, 1),
				     rand.float32_range(0, 1)};
				     

}




generate_spheres :: proc (spheres: ^[dynamic]Sphere, range: f32, count: int){
	for i := 0; i < count; i += 1 {
		s : Sphere = {
			math.Vec3{
				rand.float32_range(-range, range),
				rand.float32_range(-range, range),
				rand.float32_range(-range, range)
			}, 1, Material{rand_v3()}};
		append(spheres, s);
	}
}





initialize_world :: proc (world: ^World) {


	generate_spheres(&world.spheres, 7, 10);


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

buffer_coords_to_film_point :: proc(buffer: ^pl.Image_Buffer, camera: ^Camera, x: int, y: int) -> math.Vec3 {
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


ray_cast :: proc (origin: math.Vec3, dir: math.Vec3, world: ^World) -> math.Vec3 {
	t0: f32 = math.F32_MAX;
	t1: f32 = math.F32_MAX;
	hit_distance: f32 = math.F32_MAX;
	hit: bool;
	hit_color: math.Vec3;
	//cast against spheres
	for i := 0; i < len(world.spheres); i += 1 {
		if(intersect_sphere(world.spheres[i], origin, dir, &t0, &t1)) {
			if(!hit) {
				//first hit does not merge with black
				hit = true;
				hit_color = world.spheres[i].mat.color;
			} else {
				hit_color = (hit_color + world.spheres[i].mat.color) / 2;
			}

			if(t0 < 0) do t0 = t1;
			if(t0 < hit_distance) {
				hit_distance = t0;
			}
			
		}
	}
	
	if(hit) {
		return hit_color;
	} else {
		return {0, 0, 0};
	}
}


draw_rect :: proc(buffer: ^pl.Image_Buffer, x: int, y: int, width: int, height: int) {
	for yy := y ; yy < y + height; yy += 1 {
		for xx := x; xx < x + width; xx += 1 {
			row: ^u32 = cast(^u32)(mem.ptr_offset(buffer.data, yy * int(buffer.pitch)));
			pixel: ^u32 = cast(^u32)(mem.ptr_offset(row, xx));
			pixel^ = 0x0000ffff;
		}
	}
}



update :: proc (world: ^World, pl_ctx: ^pl.PL) {
	if(pl_ctx.mouse.left.isDown) {
		dist: f32 = math.length(main_world.camera.pos);
		horiz_theta: f32 = 0.005 * f32(pl_ctx.mouse.delta_x);
		vert_theta:  f32 = 0.005 * f32(pl_ctx.mouse.delta_y);

		{
			x := main_world.camera.pos.x;
			z := main_world.camera.pos.z;
			newx := x * math.cos(horiz_theta) - z * math.sin(horiz_theta);
			newz := z * math.cos(horiz_theta) + x * math.sin(horiz_theta);

			main_world.camera.pos.x = newx;
			main_world.camera.pos.z = newz;
			main_world.camera.dir.x = -newx / dist;
			main_world.camera.dir.z = -newz / dist;
		}

		when false {
			x := main_world.camera.pos.x;
			y := main_world.camera.pos.y;
			newx := x * math.cos(vert_theta) - y * math.sin(vert_theta);
			newy := y * math.cos(vert_theta) + x * math.sin(vert_theta);

			main_world.camera.pos.x = newx;
			main_world.camera.pos.y = newy;
			main_world.camera.dir.x = -newx / dist;
			main_world.camera.dir.y = -newy / dist;
		}
	}


	if(pl_ctx.keys[0].isDown && !pl_ctx.keys[0].wasDown) {
		generate_spheres(&world.spheres, 7, 1);
	}


}



render :: proc (world: ^World, buffer: ^pl.Image_Buffer) {

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

	base_ptr: ^u32 = cast(^u32)buffer.data;
	for y: i32 = 0; y < buffer.height; y += 1 {
		film_y := 2.0 * (f32(y) / f32(buffer.height)) - 1.0;
		for x: i32 = 0; x < buffer.width; x += 1 {

			pixel: ^u32 = mem.ptr_offset(base_ptr, int(x + y * buffer.width));


			film_x := 2.0 * (f32(x) / f32(buffer.width)) - 1.0;
			film_p := film_center + (camera_y * film_y * half_film_h) + (film_x * half_film_w * camera_x);

			ray_dir: math.Vec3 = math.norm(film_p - origin);
			pixel^ = v3_to_u32(ray_cast(origin, ray_dir, world));
		}
	}
}
