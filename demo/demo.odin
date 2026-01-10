package demo

import ui "../pkg/exigent"
import "base:runtime"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 600

State :: struct {
	input1:  ui.Text_Input,
	scroll1: ui.Scrollbox,
}

state := State{}

main :: proc() {
	prof_init()
	defer prof_deinit()

	rl.InitWindow(WIDTH, HEIGHT, "Exigent UI Demo")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)
	default_text_style_type := ui.Text_Style_Type("default")
	default_font: rl.Font = rl.GetFontDefault()

	key_map := map[int]ui.Special_Key{}
	key_map[int(rl.KeyboardKey.BACKSPACE)] = .Backspace
	key_map[int(rl.KeyboardKey.ENTER)] = .Enter
	key_map[int(rl.KeyboardKey.ESCAPE)] = .Escape

	// Initialize UI related context and defaults
	ctx := &ui.Context{}
	ui.context_init(ctx, key_map)
	ui.text_style_init(
		default_text_style_type,
		ui.Text_Style {
			type = default_text_style_type,
			size = 28,
			spacing = 2,
			line_height = 30,
			font = &default_font,
			color = ui.Color{0, 0, 0, 255},
		},
		measure_width,
	)

	// Initialize persistant widget state
	input1_buf: [16]u8
	state.input1 = ui.Text_Input {
		text = ui.text_buffer_create(input1_buf[:]),
	}

	for !rl.WindowShouldClose() {
		{
			prof_frame()
			input(ctx)
			update(ctx)
			my_draw(ctx)
		}

		// Raylib consumes the rest of the frame time to vsync to FPS so this
		// has to live outside the frame profiling which is not a perfect
		// solution but is workable for now
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	ui.context_destroy(ctx)
	rl.CloseWindow()
}

input :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	// Input - Check for released keys
	it := ui.input_key_down_iterator(ctx)
	for true {
		key, ok := ui.input_key_down_iterator_next(&it)
		if !ok do break
		if rl.IsKeyReleased(rl.KeyboardKey(key)) {
			ui.input_key_up(ctx, key)
		}
	}

	// Input - Get all down keys
	for true {
		key := int(rl.GetKeyPressed())
		if key == 0 do break
		ui.input_key_down(ctx, key)
	}

	// Input - text
	for true {
		r := rl.GetCharPressed()
		if r == 0 do break
		ui.input_char(ctx, r)
	}

	// Input - Mouse
	ui.input_mouse_pos(ctx, rl.GetMousePosition())
	// TODO: This could be optimized
	if rl.IsMouseButtonDown(.LEFT) {
		ui.input_mouse_down(ctx, .Left)
	}
	if rl.IsMouseButtonReleased(.LEFT) {
		ui.input_mouse_up(ctx, .Left)
	}
	if rl.IsMouseButtonDown(.RIGHT) {
		ui.input_mouse_down(ctx, .Right)
	}
	if rl.IsMouseButtonReleased(.RIGHT) {
		ui.input_mouse_up(ctx, .Right)
	}
	if rl.IsMouseButtonDown(.MIDDLE) {
		ui.input_mouse_down(ctx, .Middle)
	}
	if rl.IsMouseButtonReleased(.MIDDLE) {
		ui.input_mouse_up(ctx, .Middle)
	}

	// Input - scroll
	scroll_delta := rl.GetMouseWheelMove()
	if scroll_delta != 0 {
		ui.input_scroll(ctx, scroll_delta)
	}
}

update :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	ui.begin(ctx, WIDTH, HEIGHT) // Update - Build UI
	defer ui.end(ctx)

	r := ui.Rect{0, 0, WIDTH, HEIGHT}

	scrollbox := ui.rect_cut_top(&r, 300)
	scrollbox = ui.rect_inset(scrollbox, ui.Inset{20, 90, 20, 90})
	ui.scrollbox_begin(ctx, &scrollbox, &state.scroll1)

	scroll_line1 := ui.rect_take_top(&scrollbox, 100)
	scroll_line1 = ui.rect_inset(scroll_line1, 10)
	if (ui.button(ctx, scroll_line1, "One").clicked) {
		fmt.println("Scroll btn 1 clicked")
	}

	scroll_line2 := ui.rect_take_top(&scrollbox, 100)
	scroll_line2 = ui.rect_inset(scroll_line2, 10)
	if (ui.button(ctx, scroll_line2, "Two").clicked) {
		fmt.println("Scroll btn 2 clicked")
	}

	scroll_line3 := ui.rect_take_top(&scrollbox, 100)
	scroll_line3 = ui.rect_inset(scroll_line3, 10)
	if (ui.button(ctx, scroll_line3, "Three").clicked) {
		fmt.println("Scroll btn 3 clicked")
	}

	ui.scrollbox_end(ctx)

	line1 := ui.rect_cut_top(&r, 100)
	line1 = ui.rect_inset(line1, ui.Inset{20, 90, 20, 90})
	input_label := ui.rect_cut_left(&line1, line1.w / 2)
	input := line1
	ui.label(ctx, input_label, "Input: ")
	ui.text_input(ctx, input, &state.input1.text)
}

my_draw :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKBLUE)

	ci := ui.cmd_iterator_create(ctx)
	draw_ui: for true {
		cmd := ui.cmd_iterator_next(&ci)
		switch c in cmd {
		case ui.Command_Done:
			break draw_ui
		case ui.Command_Clip:
			rl.BeginScissorMode(i32(c.rect.x), i32(c.rect.y), i32(c.rect.w), i32(c.rect.h))
		case ui.Command_Unclip:
			rl.EndScissorMode()
		case ui.Command_Rect:
			rl_color := rl.Color(c.color)
			switch c.border.type {
			case .None:
				rl.DrawRectangleV(
					rl.Vector2{c.rect.x, c.rect.y},
					rl.Vector2{c.rect.w, c.rect.h},
					rl_color,
				)
			case .Square:
				rl.DrawRectangleV(
					rl.Vector2{c.rect.x, c.rect.y},
					rl.Vector2{c.rect.w, c.rect.h},
					rl_color,
				)
				rl.DrawRectangleLinesEx(
					rl.Rectangle{c.rect.x, c.rect.y, c.rect.w, c.rect.h},
					f32(c.border.thickness),
					rl.Color(c.border.color),
				)
			}
		case ui.Command_Text:
			cstr := strings.clone_to_cstring(c.text, context.temp_allocator)
			f := cast(^rl.Font)c.style.font
			rcolor := rl.Color{c.style.color.r, c.style.color.g, c.style.color.b, 255}
			rl.DrawTextEx(f^, cstr, c.pos, c.style.size, c.style.spacing, rcolor)
		}
	}

	rl.DrawFPS(10, 10)
}

measure_width :: proc(style: ui.Text_Style, text: string) -> f32 {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	f := cast(^rl.Font)style.font
	m := rl.MeasureTextEx(f^, cstr, style.size, style.spacing)
	return m.x
}
