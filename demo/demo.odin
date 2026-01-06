package demo

import ui "../pkg/exigent"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

State :: struct {
	input1:  ui.Text_Input,
	scroll1: ui.Scrollbox,
}

state := State{}

main :: proc() {
	rl.InitWindow(800, 600, "Exigent UI Demo")
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
			color = ui.Color{},
		},
		measure_width,
	)

	// Initialize persistant widget state
	input1_buf: [164]u8
	state.input1 = ui.Text_Input {
		text = ui.text_buffer_create(input1_buf[:]),
	}
	state.scroll1.y_offset = 100

	for !rl.WindowShouldClose() {
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

		// Update - Build UI
		ui.begin(ctx, 800, 600)
		r := ui.Rect{0, 0, 800, 600}

		section := ui.rect_cut_top(&r, 500)
		section = ui.rect_inset(section, ui.Inset{20, 90, 20, 90})
		ui.scrollbox_begin(ctx, &section, &state.scroll1)

		line1 := ui.rect_take_top(&section, 200)
		line1 = ui.rect_inset(line1, 10)
		ui.button(ctx, line1, "One")
		line2 := ui.rect_take_top(&section, 200)
		line2 = ui.rect_inset(line2, 10)
		ui.button(ctx, line2, "Two")
		line3 := ui.rect_take_top(&section, 200)
		line3 = ui.rect_inset(line3, 10)
		ui.button(ctx, line3, "Three")

		ui.scrollbox_end(ctx)

		// line1 := ui.rect_cut_top(&r, 100)
		// line1 = ui.rect_inset(line1, ui.Inset{20, 90, 20, 90})
		// input_label := ui.rect_cut_left(&line1, line1.width / 2)
		// input := line1

		// ui.text_input(ctx, input, &state.input1.text)

		// t2 := ui.rect_cut_top(&r, 100)
		// t2 = ui.rect_inset(t2, ui.Inset{0, 90, 0, 90})
		// ui.label(ctx, t2, "Label: ")

		// t3 := ui.rect_cut_top(&r, 100)
		// t3 = ui.rect_inset(t3, ui.Inset{0, 90, 0, 90})
		// ui.label(ctx, t3, "Label: ")

		// bot := r
		// bot = ui.rect_inset(bot, ui.Inset{0, 90, 180, 90})
		// if ui.button(ctx, bot, "Click me!").clicked {
		// 	fmt.printfln("clicked!")
		// }
		ui.end(ctx)

		// Draw
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
				rl_color := rl.Color{c.color.r, c.color.g, c.color.b, c.alpha}
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
						rl.Color{c.border.color.r, c.border.color.g, c.border.color.b, c.alpha},
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
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	ui.context_destroy(ctx)
	rl.CloseWindow()
}

measure_width :: proc(style: ui.Text_Style, text: string) -> f32 {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	f := cast(^rl.Font)style.font
	m := rl.MeasureTextEx(f^, cstr, style.size, style.spacing)
	return m.x
}

