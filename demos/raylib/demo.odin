package demo

import "base:runtime"
import "core:fmt"
import ui "exigent:."
import rlx "exigent:raylib_exigent"
import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 600

State :: struct {
	input1:   ui.Text_Input,
	scroll1:  ui.Scrollbox,
	scroll2:  ui.Scrollbox,
	renderer: rlx.Renderer,
}

state := State{}

sprite_map: map[Sprite_Type]ui.Sprite

main :: proc() {
	prof_init()
	defer prof_deinit()

	rl.InitWindow(WIDTH, HEIGHT, "Exigent UI Demo")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)
	default_font: rl.Font = rl.GetFontDefault()

	rlx.init(&state.renderer)
	defer rlx.destroy(&state.renderer, true)

	sprite_map = preload_sprites()
	defer delete(sprite_map)

	// Initialize UI related context and defaults
	ctx := &ui.Context{}
	theme := ui.theme_dark(&default_font)
	ui.init(ctx, theme = theme)
	defer ui.destroy(ctx)
	ui.text_measure_init(ctx, nil, rlx.measure_text)

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

	rl.CloseWindow()
}

input :: proc(ctx: ^ui.Context) {
	prof_frame_part()
	rlx.feed_input(ctx)
}

update :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	ui.begin(ctx, WIDTH, HEIGHT, ui.layout_fixed(WIDTH, HEIGHT, .Column, .Center, .Center)) // Update - Build UI
	defer ui.end(ctx)

	{
		th := ctx.theme

		ui.panel_begin(
			ctx,
			ui.layout_auto(
				.Column,
				.Start,
				.Center,
				padding = ui.Inset {
					top = th.spacing.xl,
					right = 28,
					bottom = th.spacing.xl,
					left = 28,
				},
				gap = th.spacing.xl,
			),
		)
		defer ui.panel_end(ctx)

		title_label(ctx, "Layout showcase")
		controls_section(ctx)
		scrollboxes_section(ctx)
	}
}

title_label :: proc(ctx: ^ui.Context, txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.label(ctx, txt, .Left, .Top, caller, sub_id, role = .Title)
}

section_label :: proc(ctx: ^ui.Context, txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.label(ctx, txt, .Left, .Top, caller, sub_id, role = .Section)
}

field_label :: proc(
	ctx: ^ui.Context,
	width: f32,
	txt: string,
	caller := #caller_location,
	sub_id: int = 0,
) {
	ui.label_sized(ctx, ui.layout_fixed(width, 34), txt, .Right, .Center, caller, sub_id)
}

controls_section :: proc(ctx: ^ui.Context) {
	{
		th := ctx.theme
		ui.container_begin(ctx, ui.layout_auto(.Column, gap = th.spacing.lg))
		defer ui.container_end(ctx)

		section_label(ctx, "Controls")

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = th.spacing.lg))
			defer ui.container_end(ctx)

			field_label(ctx, 145, "Button:")
			ui.button(ctx, ui.layout_fixed(170, 42), "Click me!")
		}

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = th.spacing.lg))
			defer ui.container_end(ctx)

			field_label(ctx, 145, "Text Input:")
			ui.text_input(ctx, ui.layout_fixed(220, 36), &state.input1)
		}

		section_label(ctx, "Images")

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Center, .Center, gap = th.spacing.sm))
			defer ui.container_end(ctx)

			for st, sp in sprite_map {
				ui.image(ctx, ui.layout_fixed(42, 42), sp)
			}
		}
	}
}

scrollboxes_section :: proc(ctx: ^ui.Context) {
	{
		th := ctx.theme
		ui.container_begin(ctx, ui.layout_auto(.Column, gap = th.spacing.lg))
		defer ui.container_end(ctx)

		section_label(ctx, "Scrollboxes")

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = th.spacing.lg))
			defer ui.container_end(ctx)

			field_label(ctx, 170, "Content fits:")

			ui.scrollbox_begin(
				ctx,
				ui.layout_fixed(250, 92, .Column, .Center, .Center),
				&state.scroll1,
			)
			defer ui.scrollbox_end(ctx)

			{
				ui.container_begin(ctx, ui.layout_fixed(230, 34, .Column, .Center, .Center))
				defer ui.container_end(ctx)

				ui.label(ctx, "Line 1")
			}

			{
				ui.container_begin(ctx, ui.layout_fixed(230, 34, .Column, .Center, .Center))
				defer ui.container_end(ctx)

				ui.label(ctx, "Line 2")
			}
		}

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = th.spacing.lg))
			defer ui.container_end(ctx)

			field_label(ctx, 170, "Content scrolls:")

			ui.scrollbox_begin(ctx, ui.layout_fixed(250, 92, .Column), &state.scroll2)
			defer ui.scrollbox_end(ctx)

			for i in 1 ..= 3 {
				ui.container_begin(
					ctx,
					ui.layout_fixed(230, 42, .Column, .Center, .Center),
					sub_id = i,
				)
				ui.button(
					ctx,
					ui.layout_fixed(200, 34),
					fmt.tprintf("Button %d", i),
					bg = ui.Color{140, 140, 140, 255},
					sub_id = i,
				)
				ui.container_end(ctx)
			}
		}
	}
}

my_draw :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rlx.draw(&state.renderer, ctx)

	rl.DrawFPS(10, 10)
}

Sprite_Type :: enum {
	Alert_Icon,
	Clock_Icon,
	Charts_Icon,
	Sun_Icon,
	Wrench_Icon,
	Crop_Icon,
}

preload_sprites :: proc() -> map[Sprite_Type]ui.Sprite {
	sprite_map := make(map[Sprite_Type]ui.Sprite)

	icons := map[Sprite_Type]string{}
	icons[.Alert_Icon] = "demos/raylib/res/icons/symbol alert.png"
	icons[.Clock_Icon] = "demos/raylib/res/icons/object clock time.png"
	icons[.Charts_Icon] = "demos/raylib/res/icons/object charts.png"
	icons[.Sun_Icon] = "demos/raylib/res/icons/object sun.png"
	icons[.Wrench_Icon] = "demos/raylib/res/icons/object wrench.png"
	icons[.Crop_Icon] = "demos/raylib/res/icons/symbol crop resize.png"

	for type, fp in icons {
		sprite_map[type] = rlx.load_sprite_from_file(&state.renderer, fp)
	}

	return sprite_map
}
