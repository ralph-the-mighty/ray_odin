package main

import "core:mem"




draw_rect :: proc(buffer: ^Image_Buffer, x: int, y: int, width: int, height: int) {
	for yy := y ; yy < y + height; yy += 1 {
		for xx := x; xx < x + width; xx += 1 {
			row: ^u32 = cast(^u32)(mem.ptr_offset(buffer.data, yy * int(buffer.pitch)));
			pixel: ^u32 = cast(^u32)(mem.ptr_offset(row, xx));
			pixel^ = 0x000000ff;
		}
	}

}
