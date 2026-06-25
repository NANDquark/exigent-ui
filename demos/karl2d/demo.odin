package demo_karl2d

import "core:fmt"
import ui "exigent:."
import k2 "karl2d:."
import k2e "karl2d_exigent:."

WIDTH :: 800
HEIGHT :: 600

TEXT_STYLE_DEFAULT :: ui.Text_Style_Type("default")
TEXT_STYLE_TITLE :: ui.Text_Style_Type("title")
TEXT_STYLE_SECTION :: ui.Text_Style_Type("section")

State :: struct {
	input:     ui.Text_Input,
	input_buf: [32]u8,
	scroll:    ui.Scrollbox,
	renderer:  k2e.Renderer,
	ctx:       ui.Context,
	sprites:   [dynamic]ui.Sprite,
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
	ui.init(&state.ctx)
	k2e.init(&state.renderer)
	state.sprites = make([dynamic]ui.Sprite)

	ui.text_style_init(
		TEXT_STYLE_DEFAULT,
		ui.Text_Style {
			type = TEXT_STYLE_DEFAULT,
			size = 20,
			spacing = 1,
			line_height = 22,
			color = ui.Color{0, 0, 0, 255},
		},
		nil,
		k2e.measure_text,
	)
	ui.text_style_register(
		ui.Text_Style {
			type = TEXT_STYLE_TITLE,
			size = 30,
			spacing = 1,
			line_height = 32,
			color = ui.Color{0, 0, 0, 255},
		},
	)
	ui.text_style_register(
		ui.Text_Style {
			type = TEXT_STYLE_SECTION,
			size = 24,
			spacing = 1,
			line_height = 26,
			color = ui.Color{0, 0, 0, 255},
		},
	)

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
	ui.begin(
		&state.ctx,
		width,
		height,
		ui.layout_fixed(f32(width), f32(height), .Column, .Center, .Center),
	)
	defer ui.end(&state.ctx)

	panel_style := ui.style_get(&state.ctx, ui.Widget_Type_PANEL)
	panel_style.base.background = ui.Color{210, 210, 210, 255}
	ui.style_push(&state.ctx, ui.Widget_Type_PANEL, panel_style)
	defer ui.style_pop(&state.ctx)

	ui.panel_begin(
		&state.ctx,
		ui.layout_auto(
			.Column,
			.Start,
			.Center,
			padding = ui.Inset{top = 22, right = 28, bottom = 22, left = 28},
			gap = 22,
		),
	)
	defer ui.panel_end(&state.ctx)

	title_label("Karl2D adapter demo")
	controls_section()
	image_section()
	scroll_section()
}

title_label :: proc(txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.text_style_push(&state.ctx, TEXT_STYLE_TITLE)
	defer ui.text_style_pop(&state.ctx)
	ui.label(&state.ctx, txt, .Left, .Top, caller, sub_id)
}

section_label :: proc(txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.text_style_push(&state.ctx, TEXT_STYLE_SECTION)
	defer ui.text_style_pop(&state.ctx)
	ui.label(&state.ctx, txt, .Left, .Top, caller, sub_id)
}

field_label :: proc(width: f32, txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.label_sized(&state.ctx, ui.layout_fixed(width, 34), txt, .Right, .Center, caller, sub_id)
}

controls_section :: proc() {
	ui.container_begin(&state.ctx, ui.layout_auto(.Column, gap = 14))
	defer ui.container_end(&state.ctx)

	section_label("Controls")

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Start, .Center, gap = 14))
	field_label(145, "Button:")
	ui.button(&state.ctx, ui.layout_fixed(170, 42), "Click me!")
	ui.container_end(&state.ctx)

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Start, .Center, gap = 14))
	field_label(145, "Text Input:")
	ui.text_input(&state.ctx, ui.layout_fixed(220, 36), &state.input)
	ui.container_end(&state.ctx)
}

image_section :: proc() {
	section_label("Images")

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Center, .Center, gap = 8))
	defer ui.container_end(&state.ctx)

	for sprite, idx in state.sprites {
		ui.image(&state.ctx, ui.layout_fixed(42, 42), sprite, sub_id = idx)
	}
}

scroll_section :: proc() {
	section_label("Scrollbox")

	ui.container_begin(&state.ctx, ui.layout_auto(.Row, .Start, .Center, gap = 14))
	defer ui.container_end(&state.ctx)

	field_label(145, "Scrollable:")

	ui.scrollbox_begin(&state.ctx, ui.layout_fixed(250, 100, .Column), &state.scroll)
	defer ui.scrollbox_end(&state.ctx)

	button_style := ui.style_get(&state.ctx, ui.Widget_Type_BUTTON)
	button_style.base.background = ui.Color{140, 140, 140, 255}
	ui.style_push(&state.ctx, ui.Widget_Type_BUTTON, button_style)
	defer ui.style_pop(&state.ctx)

	for i in 1 ..= 5 {
		ui.container_begin(
			&state.ctx,
			ui.layout_fixed(230, 42, .Column, .Center, .Center),
			sub_id = i,
		)
		ui.button(&state.ctx, ui.layout_fixed(200, 34), fmt.tprintf("Button %d", i), sub_id = i)
		ui.container_end(&state.ctx)
	}
}
