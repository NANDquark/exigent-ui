package demo_karl2d

import "core:fmt"
import ui "exigent:exigent"
import k2e "exigent:karl2d_exigent"
import k2 "karl2d:."

WIDTH :: 800
HEIGHT :: 600

State :: struct {
	input:     ui.Text_Input,
	input_buf: [32]u8,
	scroll:    ui.Scrollbox,
	renderer:  k2e.Renderer,
	ctx:       ui.Context,
	sprites:   [dynamic]ui.Sprite,
	font:      k2.Font,
}

state: State

main :: proc() {
	k2.init(WIDTH, HEIGHT, "Exigent Karl2D Demo", {window_mode = .Windowed_Resizable})
	defer k2.shutdown()

	init()
	defer shutdown()

	for k2.update() {
		step()
	}
}

init :: proc() {
	state.font = k2.FONT_DEFAULT
	theme := ui.theme_light(&state.font)
	theme.color.surface = ui.Color{210, 210, 210, 255}
	theme.font.size_md = 20
	theme.font.size_lg = 24
	theme.font.size_xl = 30
	theme.font.line_scale = 1.1
	ui.init(&state.ctx, theme = theme)
	k2e.init(&state.renderer)
	state.sprites = make([dynamic]ui.Sprite)
	ui.text_measure_init(&state.ctx, nil, k2e.measure_text)

	state.input = ui.Text_Input {
		text = ui.text_buffer_create(state.input_buf[:]),
	}

	load_icon("demos/raylib/res/icons/symbol alert.png")
	load_icon("demos/raylib/res/icons/object clock time.png")
	load_icon("demos/raylib/res/icons/object charts.png")
	load_icon("demos/raylib/res/icons/object sun.png")
	load_icon("demos/raylib/res/icons/object wrench.png")
	load_icon("demos/raylib/res/icons/symbol crop resize.png")
}

shutdown :: proc() {
	delete(state.sprites)
	k2e.destroy(&state.renderer, true)
	ui.destroy(&state.ctx)
}

step :: proc() -> bool {
	k2e.feed_input(&state.ctx)
	build_ui()

	k2.clear(k2.WHITE)
	k2e.draw(&state.renderer, &state.ctx)
	k2.present()

	return !k2.close_window_requested()
}

load_icon :: proc(filename: string) {
	append(&state.sprites, k2e.load_sprite_from_file(&state.renderer, filename))
}

build_ui :: proc() {
	width := k2.get_screen_width()
	height := k2.get_screen_height()
	th := state.ctx.theme
	ui.begin(
		&state.ctx,
		width,
		height,
	)
	defer ui.end(&state.ctx)
	ui.layer_begin(
		&state.ctx,
		ui.layout_fixed(f32(width), f32(height), .Column, .Center, .Center),
	)
	defer ui.layer_end(&state.ctx)

	ui.panel_begin(
		&state.ctx,
		ui.layout_auto(
			.Column,
			.Start,
			.Center,
			padding = ui.Inset{top = th.spacing.xl, right = 28, bottom = th.spacing.xl, left = 28},
			gap = th.spacing.xl,
		),
	)
	defer ui.panel_end(&state.ctx)

	title_label("Karl2D adapter demo")
	controls_section()
	image_section()
	scroll_section()
}

title_label :: proc(txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.label(&state.ctx, txt, .Left, .Top, role = .Title, caller = caller, sub_id = sub_id)
}

section_label :: proc(txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.label(&state.ctx, txt, .Left, .Top, role = .Section, caller = caller, sub_id = sub_id)

}

field_label :: proc(width: f32, txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.label_sized(
		&state.ctx,
		ui.layout_fixed(width, 34),
		txt,
		.Right,
		.Center,
		caller = caller,
		sub_id = sub_id,
	)
}

controls_section :: proc() {
	th := state.ctx.theme
	ui.container_begin(&state.ctx, ui.layout_auto(.Column, gap = th.spacing.lg))
	defer ui.container_end(&state.ctx)

	section_label("Controls")

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Start, .Center, gap = th.spacing.lg))
	field_label(145, "Button:")
	ui.button(&state.ctx, ui.layout_fixed(170, 42), "Click me!")
	ui.container_end(&state.ctx)

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Start, .Center, gap = th.spacing.lg))
	field_label(145, "Text Input:")
	ui.text_input(&state.ctx, ui.layout_fixed(220, 36), &state.input)
	ui.container_end(&state.ctx)
}

image_section :: proc() {
	th := state.ctx.theme
	section_label("Images")

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Center, .Center, gap = th.spacing.sm))
	defer ui.container_end(&state.ctx)

	for sprite, idx in state.sprites {
		ui.image(&state.ctx, ui.layout_fixed(42, 42), sprite, sub_id = idx)
	}
}

scroll_section :: proc() {
	th := state.ctx.theme
	section_label("Scrollbox")

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Start, .Center, gap = th.spacing.lg))
	defer ui.container_end(&state.ctx)

	field_label(145, "Scrollable:")

	ui.scrollbox_begin(&state.ctx, ui.layout_fixed(250, 100, .Column), &state.scroll)
	defer ui.scrollbox_end(&state.ctx)

	for i in 1 ..= 5 {
		ui.container_begin(
			&state.ctx,
			ui.layout_fixed(230, 42, .Column, .Center, .Center),
			sub_id = i,
		)
		ui.button(
			&state.ctx,
			ui.layout_fixed(200, 34),
			fmt.tprintf("Button %d", i),
			bg_color = ui.Color{140, 140, 140, 255},
			sub_id = i,
		)
		ui.container_end(&state.ctx)
	}
}
