//breakout.odin

package main;

import "core:fmt"
import "core:sys/win32"
import "core:os"
import "core:math"
import "core:mem"



WINDOW_WIDTH: i32 = 500;
WINDOW_HEIGHT: i32 = 500;
running: bool = true;

frame_buffer: Win32_Buffer;


Image_Buffer :: struct {
	width: i32,
	height: i32,
	pitch: i32,
	data: ^byte,
}


Win32_Buffer :: struct {
	bitmap_info: win32.Bitmap_Info,
	using buffer: Image_Buffer
}


initialize_buffer :: proc (buffer: ^Win32_Buffer, width: i32, height: i32) {
	bytes_per_pixel : i32 = 4;
	buffer.bitmap_info.size = size_of(win32.Bitmap_Info_Header);
	buffer.bitmap_info.width = width;
	buffer.bitmap_info.height = height;
	buffer.bitmap_info.planes = 1;
	buffer.bitmap_info.bit_count = 32;
	buffer.bitmap_info.compression = win32.BI_RGB;

	buffer.width = width;
	buffer.height = height;
	buffer.pitch = width * bytes_per_pixel;
	buffer.data = cast(^byte)mem.alloc(int(width * height * bytes_per_pixel));
	buffer.data = cast(^byte)mem.set(buffer.data, 0x55, int(width * height * bytes_per_pixel));


	draw_rect(buffer, 10, 40, 100, 100);



}


push_buffer_to_window :: proc (hdc: win32.Hdc, buffer: ^Win32_Buffer, 
							   window_width: i32, window_height: i32) -> i32 {

	// fmt.printf("%d, %d, %d, %d\n",
	// 	mem.ptr_offset(buffer.data,0),
	// 	mem.ptr_offset(buffer.data,2),
	// 	mem.ptr_offset(buffer.data,3),
	// 	mem.ptr_offset(buffer.data,4));

	return win32.stretch_dibits(
		hdc,
		0, 0, window_width, window_height,
		0, 0, buffer.width, buffer.height,
		buffer.data,
		&(buffer.bitmap_info),
		win32.DIB_RGB_COLORS,
		win32.SRCCOPY);
}




window_proc :: proc "c" (hwnd: win32.Hwnd, uMsg: u32, wParam: win32.Wparam, lParam: win32.Lparam) -> win32.Lresult {
	switch uMsg {
		case win32.WM_DESTROY, win32.WM_QUIT:
			running = false;
	}

	dc: win32.Hdc = win32.get_dc(hwnd);
	res: i32 = push_buffer_to_window(dc, &frame_buffer, WINDOW_WIDTH, WINDOW_HEIGHT);
	//fmt.printf("res: %d\n", res);
	win32.release_dc(hwnd, dc);

	return win32.def_window_proc_a(hwnd, uMsg, wParam, lParam);
}



main :: proc() {
	instance: win32.Hinstance = cast(win32.Hinstance) win32.get_module_handle_a(nil);
	fmt.printf("hande: %d\n", instance);

	wc: win32.Wnd_Class_Ex_A;
	wc.size = size_of(win32.Wnd_Class_Ex_A);
	wc.instance = instance;
	wc.wnd_proc = window_proc;
	wc.class_name = "ray";

	res: i16 = win32.register_class_ex_a(&wc);

	if(res == 0) {
		fmt.printf("Class was not registered correctly\n");
		os.exit(1);
	}

	style: u32 = win32.WS_CAPTION | win32.WS_SYSMENU | win32.WS_MINIMIZEBOX | win32.WS_VISIBLE;

	r: win32.Rect;
	r.right = WINDOW_WIDTH;
	r.bottom = WINDOW_HEIGHT;
	win32.adjust_window_rect(&r, style, false);

	window: win32.Hwnd = win32.create_window_ex_a(
		0, 
		"ray", 
		"Elon Musk in the Title", 
		style,
		100, 100, r.right - r.left, r.bottom - r.top,
		nil,
		nil,
		instance,
		nil
		);

	
	if (window == nil) {
		fmt.printf("Window was not created successfully\n");
		os.exit(1);
	}

	fmt.printf("%d\n", frame_buffer.data);
	initialize_buffer(&frame_buffer, WINDOW_WIDTH, WINDOW_HEIGHT);
	fmt.print(frame_buffer);

	win32.show_window(window, win32.SW_SHOW);

	//game loop
	for ; running ; {

		//message loop
		message: win32.Msg;
    	for ; win32.peek_message_a(&message, nil, 0, 0, win32.PM_REMOVE); {
        	win32.translate_message(&message);
       	 	win32.dispatch_message_a(&message);
    	}
	}
}