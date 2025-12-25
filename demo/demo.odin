package demo

import ui "../pkg/exigent"
import "core:fmt"
import rl "vendor:raylib"

UI_ID :: enum uint {
	PANEL,
	BUTTON,
}

main :: proc() {
	rl.InitWindow(800, 600, "Exigent UI Demo")
	rl.SetTargetFPS(60)

	ctx := &ui.Context{}
	ui.context_init(ctx)

	for !rl.WindowShouldClose() {
		// Input - Check for released keys
		it := ui.input_key_down_iterator(ctx)
		for true {
			key, ok := ui.input_key_down_iterator_next(&it)
			if !ok {
				break
			}
			if rl.IsKeyReleased(rl.KeyboardKey(key)) {
				ui.input_key_up(ctx, key)
			}
		}
		// Input - Get all down keys
		for true {
			key := int(rl.GetKeyPressed())
			if key == 0 {
				break
			}
			ui.input_key_down(ctx, key)
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
		r = ui.rect_inset(r, ui.Inset{90, 90, 90, 90})
		// ui.style_push(ctx)
		// ui.style_set_color(ctx, ui.Color_Type_BACKGROUND_FOCUSED, ui.Color{0, 255, 0})
		// ui.panel(ctx, ui.key(UI_ID.PANEL), r)
		if ui.button(ctx, ui.key(UI_ID.BUTTON), r).clicked {
			fmt.printfln("clicked!")
		}
		// ui.style_pop(ctx)
		ui.end(ctx)

		// Draw
		rl.BeginDrawing()
		rl.ClearBackground(rl.DARKBLUE)

		ci := ui.cmd_iterator_create(
			ctx,
			ui.DEFAULT_CMDS_PER_WIDGET_HEURISTIC,
			context.temp_allocator,
		)
		draw_ui: for true {
			cmd := ui.cmd_iterator_next(&ci)
			switch c in cmd {
			case ui.Command_Done:
				break draw_ui
			case ui.Command_Rect:
				rl_color := rl.Color{c.color.r, c.color.g, c.color.b, c.alpha}
				switch c.border_style {
				case .None:
					rl.DrawRectangleV(
						rl.Vector2{c.rect.x, c.rect.y},
						rl.Vector2{c.rect.width, c.rect.height},
						rl_color,
					)
				case .Square:
					rl.DrawRectangleV(
						rl.Vector2{c.rect.x, c.rect.y},
						rl.Vector2{c.rect.width, c.rect.height},
						rl_color,
					)
					rl.DrawRectangleLinesEx(
						rl.Rectangle{c.rect.x, c.rect.y, c.rect.width, c.rect.height},
						f32(c.border_thickness),
						rl.Color{c.border_color.r, c.border_color.g, c.border_color.b, c.alpha},
					)
				}
			}
		}

		rl.DrawFPS(10, 10)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	ui.context_destroy(ctx)
	rl.CloseWindow()
}
