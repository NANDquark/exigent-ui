package main_web

import "base:runtime"
import "core:c"
import "core:fmt"
import ui "exigent:."
import rlx "raylib_exigent:."
import rl "vendor:raylib"

when ODIN_OS == .JS {
	foreign import env "env"
	foreign env {
		emscripten_notify_memory_growth :: proc "c" (memory_index: int) ---
	}
}

WIDTH :: 800
HEIGHT :: 600

State :: struct {
	ctx:       ui.Context,
	renderer:  rlx.Renderer,
	font:      rl.Font,
	input:     ui.Text_Input,
	input_buf: [64]u8,
	scroll:    ui.Scrollbox,
	clicks:    int,
}

state: State
web_context: runtime.Context

@(export, link_name = "main_start")
main_start :: proc "c" () {
	context = runtime.default_context()
	web_context = context

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WIDTH, HEIGHT, "Exigent Raylib Web Demo")
	rl.SetExitKey(.KEY_NULL)

	rlx.init(&state.renderer)

	state.font = rl.GetFontDefault()
	theme := ui.theme_dark(&state.font)
	ui.init(&state.ctx, theme = theme)
	ui.text_measure_init(&state.ctx, nil, rlx.measure_text)

	state.input = ui.Text_Input {
		text = ui.text_buffer_create(state.input_buf[:]),
	}

	prime_wasm_allocator()
	notify_memory_growth()
}

@(export, link_name = "main_update")
main_update :: proc "c" () -> bool {
	context = web_context

	when ODIN_OS != .JS {
		if rl.WindowShouldClose() {
			return false
		}
	}

	rlx.feed_input(&state.ctx)

	width := int(rl.GetScreenWidth())
	height := int(rl.GetScreenHeight())
	ui.begin(&state.ctx, width, height, ui.layout_fixed(f32(width), f32(height), .Column, .Center, .Center))
	build_ui(&state.ctx)
	ui.end(&state.ctx)

	notify_memory_growth()

	rl.BeginDrawing()
	rl.ClearBackground(to_rl_color(state.ctx.theme.color.bg))
	rlx.draw(&state.renderer, &state.ctx)
	rl.PollInputEvents()

	free_all(context.temp_allocator)
	return true
}

notify_memory_growth :: proc() {
	when ODIN_OS == .JS {
		emscripten_notify_memory_growth(0)
	}
}

prime_wasm_allocator :: proc() {
	when ODIN_OS == .JS {
		_ = make([]u8, 4 * 1024 * 1024, context.temp_allocator)
		free_all(context.temp_allocator)
	}
}

@(export, link_name = "main_end")
main_end :: proc "c" () {
	context = web_context
	ui.destroy(&state.ctx)
	rlx.destroy(&state.renderer, true)
	rl.CloseWindow()
}

@(export, link_name = "web_window_size_changed")
web_window_size_changed :: proc "c" (width, height: c.int) {
	context = web_context
	if width > 0 && height > 0 {
		rl.SetWindowSize(width, height)
	}
}

build_ui :: proc(ctx: ^ui.Context) {
	th := ctx.theme

	ui.panel_begin(
		ctx,
		ui.layout_auto(
			.Column,
			.Center,
			.Center,
			padding = ui.Inset{top = th.spacing.xl, right = th.spacing.xl, bottom = th.spacing.xl, left = th.spacing.xl},
			gap = th.spacing.lg,
		),
	)
	defer ui.panel_end(ctx)

	ui.label(ctx, "Exigent Raylib Web", .Center, .Top, role = .Title)
	ui.label(ctx, "Type below, click the button, and scroll the list.", .Center, .Top, role = .Muted)

	if ui.button(ctx, ui.layout_fixed(220, 42), fmt.tprintf("Clicks: %d", state.clicks)).released {
		state.clicks += 1
	}

	ui.text_input(ctx, ui.layout_fixed(260, 38), &state.input)

	ui.scrollbox_begin(ctx, ui.layout_fixed(300, 116, .Column, .Start, .Center), &state.scroll)
	defer ui.scrollbox_end(ctx)

	for i in 1 ..= 6 {
		ui.container_begin(ctx, ui.layout_fixed(270, 34, .Column, .Center, .Center), sub_id = i)
		ui.label(ctx, fmt.tprintf("Scrollable row %d", i), .Center, .Center, sub_id = i)
		ui.container_end(ctx)
	}
}

to_rl_color :: proc(color: ui.Color) -> rl.Color {
	return rl.Color{color.r, color.g, color.b, color.a}
}
