package layers_demo

import "core:fmt"
import ui "exigent:exigent"
import rlx "exigent:raylib_exigent"
import rl "vendor:raylib"

WIDTH :: 960
HEIGHT :: 540

State :: struct {
	ctx:           ui.Context,
	renderer:      rlx.Renderer,
	menu_open:     bool,
	quit:          bool,
	selected_slot: int,
}

state := State{}

main :: proc() {
	rl.InitWindow(WIDTH, HEIGHT, "Exigent Layers + Anchors Demo")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)
	default_font := rl.GetFontDefault()

	ui.init(&state.ctx, ui.theme_dark(&default_font))
	defer ui.destroy(&state.ctx)
	ui.text_measure_init(&state.ctx, nil, rlx.measure_text)

	rlx.init(&state.renderer)
	defer rlx.destroy(&state.renderer, true)
	state.selected_slot = 1

	for !state.quit && !rl.WindowShouldClose() {
		rlx.feed_input(&state.ctx)
		update()
		draw()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}

update :: proc() {
	if ui.input_is_key_pressed(&state.ctx, .Escape) {
		state.menu_open = !state.menu_open
	}

	width := int(rl.GetScreenWidth())
	height := int(rl.GetScreenHeight())

	ui.begin(&state.ctx, width, height)
	defer ui.end(&state.ctx)

	hud_layer(width, height)
	if state.menu_open {
		menu_layer(width, height)
	}
}

draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.Color{12, 15, 20, 255})
	draw_world()
	rlx.draw(&state.renderer, &state.ctx)
}

draw_world :: proc() {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())

	grid_color := rl.Color{34, 41, 52, 255}
	for x := 0; x < int(width); x += 48 {
		rl.DrawLine(i32(x), 0, i32(x), i32(height), grid_color)
	}
	for y := 0; y < int(height); y += 48 {
		rl.DrawLine(0, i32(y), i32(width), i32(y), grid_color)
	}

	rl.DrawCircleGradient(
		i32(width * 0.35),
		i32(height * 0.48),
		height * 0.22,
		rl.Color{37, 80, 130, 180},
		rl.Color{12, 15, 20, 0},
	)
	rl.DrawRectangleV({width * 0.52, height * 0.34}, {width * 0.18, height * 0.26}, rl.Color{48, 57, 72, 255})
	rl.DrawRectangleLinesEx(
		rl.Rectangle{x = width * 0.52, y = height * 0.34, width = width * 0.18, height = height * 0.26},
		2,
		rl.Color{92, 104, 126, 255},
	)
}

hud_layer :: proc(width, height: int) {
	ctx := &state.ctx
	th := ctx.theme

	ui.layer_begin(ctx, ui.layout_fixed(f32(width), f32(height)))
	defer ui.layer_end(ctx)

	{
		ui.panel_begin(
			ctx,
			ui.layout_auto(
				.Row,
				.Center,
				.Center,
				padding = ui.Inset{top = th.spacing.sm, right = th.spacing.lg, bottom = th.spacing.sm, left = th.spacing.lg},
				gap = th.spacing.xl,
			),
			ui.Container_Options {
				positioning = .Anchored,
				anchor      = .Top_Center,
				offset      = {0, 12},
			},
		)
		defer ui.panel_end(ctx)
		resource_label("Wood", 128, 1)
		resource_label("Stone", 72, 2)
		resource_label("Food", 214, 3)
		resource_label("Gold", 38, 4)
	}

	{
		ui.panel_begin(
			ctx,
			ui.layout_auto(
				.Row,
				.Center,
				.Center,
				padding = ui.Inset{top = th.spacing.md, right = th.spacing.lg, bottom = th.spacing.md, left = th.spacing.lg},
				gap = th.spacing.md,
			),
			ui.Container_Options {
				positioning = .Anchored,
				anchor      = .Bottom_Center,
				offset      = {0, -18},
			},
		)
		defer ui.panel_end(ctx)

		for i in 1 ..= 8 {
			hotbar_slot(i)
		}
	}
}

resource_label :: proc(name: string, amount: int, sub_id: int) {
	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Center, .Center, gap = state.ctx.theme.spacing.xs), sub_id = sub_id)
	defer ui.container_end(&state.ctx)

	ui.label(&state.ctx, name, .Left, .Center, role = .Body, sub_id = sub_id * 2)
	ui.label(&state.ctx, fmt.tprintf("%d", amount), .Left, .Center, role = .Section, sub_id = sub_id * 2 + 1)
}

hotbar_slot :: proc(slot: int) {
	ctx := &state.ctx
	selected := state.selected_slot == slot

	bg := ui.Color{36, 41, 52, 230}
	if selected {
		bg = ctx.theme.color.primary
	}

	interaction := ui.button(
		ctx,
		ui.layout_fixed(54, 54),
		fmt.tprintf("%d", slot),
		bg_color = bg,
		sub_id = slot,
	)
	if interaction.released {
		state.selected_slot = slot
	}
}

menu_layer :: proc(width, height: int) {
	ctx := &state.ctx
	th := ctx.theme

	ui.layer_begin(ctx, ui.layout_fixed(f32(width), f32(height), .Column), ui.Layer_Options{capture_pointer_empty = true, capture_keyboard = true})
	defer ui.layer_end(ctx)

	ui.container_begin(ctx, ui.layout_fixed(f32(width), f32(height)), sub_id = 1)
	ui.background(ctx, ui.Color{0, 0, 0, 150})
	ui.container_end(ctx)

	ui.panel_begin(
		ctx,
		ui.layout_auto(
			.Column,
			.Start,
			.Center,
			padding = ui.Inset{top = th.spacing.xl, right = th.spacing.xl, bottom = th.spacing.xl, left = th.spacing.xl},
			gap = th.spacing.lg,
		),
		ui.Container_Options{positioning = .Anchored, anchor = .Center},
		sub_id = 2,
	)
	defer ui.panel_end(ctx)

	ui.label(ctx, "Menu", .Center, .Top, role = .Title, sub_id = 1)

	if ui.button(ctx, ui.layout_fixed(220, 42), "Back", sub_id = 2).released {
		state.menu_open = false
	}
	_ = ui.button(ctx, ui.layout_fixed(220, 42), "Settings", sub_id = 3)
	if ui.button(ctx, ui.layout_fixed(220, 42), "Exit", bg_color = ctx.theme.color.danger, sub_id = 4).released {
		state.quit = true
	}
}
