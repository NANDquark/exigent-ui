package demo

import ui "../.."
import "base:runtime"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:log"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 600

State :: struct {
	input1:  ui.Text_Input,
	scroll1: ui.Scrollbox,
	scroll2: ui.Scrollbox,
}

state := State{}

textures: [dynamic]rl.Texture2D
sprite_map: map[Sprite_Type]ui.Sprite

main :: proc() {
	prof_init()
	defer prof_deinit()

	rl.InitWindow(WIDTH, HEIGHT, "Exigent UI Demo")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)
	default_font: rl.Font = rl.GetFontDefault()

	textures, sprite_map = preload_sprites()

	// Initialize UI related context and defaults
	ctx := &ui.Context{}
	theme := ui.theme_dark(&default_font)
	ui.init(ctx, theme = theme)
	ui.text_measure_init(ctx, nil, measure_width)

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

	ui.destroy(ctx)
	rl.CloseWindow()
}

input :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	events := make([dynamic]ui.Input_Event, 0, 16, context.temp_allocator)

	// Input - Check for released keys.
	it := ui.input_key_down_iterator(ctx)
	for key in ui.input_key_down_iterator_next(&it) {
		rl_key := ui_to_rl_key(key)
		if rl_key != .KEY_NULL && rl.IsKeyReleased(rl_key) {
			append(&events, ui.Key_Event{key = key, type = .Released})
		}
	}

	// Input - Get all pressed keys this frame.
	for {
		rl_key := rl.GetKeyPressed()
		if rl_key == .KEY_NULL do break
		ui_key := rl_to_ui_key(rl_key)
		if ui_key != .None {
			append(&events, ui.Key_Event{key = ui_key, type = .Pressed})
		}
	}

	// Input - text.
	for {
		r := rl.GetCharPressed()
		if r == 0 do break
		append(&events, ui.Char_Event{c = r})
	}

	// Input - Mouse edge events.
	if rl.IsMouseButtonPressed(.LEFT) {
		append(&events, ui.Mouse_Event{button = .Left, type = .Pressed})
	}
	if rl.IsMouseButtonReleased(.LEFT) {
		append(&events, ui.Mouse_Event{button = .Left, type = .Released})
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		append(&events, ui.Mouse_Event{button = .Right, type = .Pressed})
	}
	if rl.IsMouseButtonReleased(.RIGHT) {
		append(&events, ui.Mouse_Event{button = .Right, type = .Released})
	}
	if rl.IsMouseButtonPressed(.MIDDLE) {
		append(&events, ui.Mouse_Event{button = .Middle, type = .Pressed})
	}
	if rl.IsMouseButtonReleased(.MIDDLE) {
		append(&events, ui.Mouse_Event{button = .Middle, type = .Released})
	}

	ui.input_feed_external(
		ctx,
		rl.GetMousePosition(),
		rl.GetMouseWheelMove(),
		nil,
		demo_input_is_key_down,
		demo_input_is_mouse_down,
		events[:],
	)
}

demo_input_is_key_down :: proc(user_data: rawptr, key: ui.Key) -> bool {
	rl_key := ui_to_rl_key(key)
	if rl_key == .KEY_NULL do return false
	return rl.IsKeyDown(rl_key)
}

demo_input_is_mouse_down :: proc(user_data: rawptr, button: ui.Mouse_Button) -> bool {
	switch button {
	case .Left:
		return rl.IsMouseButtonDown(.LEFT)
	case .Right:
		return rl.IsMouseButtonDown(.RIGHT)
	case .Middle:
		return rl.IsMouseButtonDown(.MIDDLE)
	}
	return false
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

	ci := ui.cmd_iterator_create(ctx)
	for cmd in ui.cmd_iterator_next(&ci) {
		switch c in cmd {
		case ui.Command_Clip:
			begin_scissor(c.rect)
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
					rl.Rectangle {
						c.rect.x - c.border.thickness,
						c.rect.y - c.border.thickness,
						c.rect.w + c.border.thickness * 2,
						c.rect.h + c.border.thickness * 2,
					},
					f32(c.border.thickness),
					rl.Color(c.border.color),
				)
			}
		case ui.Command_Text:
			cstr := strings.clone_to_cstring(c.text, context.temp_allocator)
			f := cast(^rl.Font)c.style.font
			rcolor := rl.Color{c.style.color.r, c.style.color.g, c.style.color.b, 255}
			rl.DrawTextEx(f^, cstr, c.pos, c.style.size, c.style.spacing, rcolor)
		case ui.Command_Sprite:
			texture := textures[c.sprite.texture]
			src := rl.Rectangle {
				x      = c.sprite.uv.x * f32(texture.width),
				y      = c.sprite.uv.y * f32(texture.height),
				width  = c.sprite.uv.w * f32(texture.width),
				height = c.sprite.uv.h * f32(texture.height),
			}
			dst := rl.Rectangle {
				x      = c.rect.x,
				y      = c.rect.y,
				width  = c.rect.w,
				height = c.rect.h,
			}
			rl.DrawTexturePro(texture, src, dst, rl.Vector2{}, 0, rl.WHITE)
		}
	}

	rl.DrawFPS(10, 10)
}

begin_scissor :: proc(r: ui.Rect) {
	x0 := i32(math.floor(r.x))
	y0 := i32(math.floor(r.y))
	x1 := i32(math.ceil(r.x + r.w))
	y1 := i32(math.ceil(r.y + r.h))
	rl.BeginScissorMode(x0, y0, x1 - x0, y1 - y0)
}

measure_width :: proc(data: rawptr, style: ui.Text_Style, text: string) -> f32 {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	f := cast(^rl.Font)style.font
	m := rl.MeasureTextEx(f^, cstr, style.size, style.spacing)
	return m.x
}

Sprite_Type :: enum {
	Alert_Icon,
	Clock_Icon,
	Charts_Icon,
	Sun_Icon,
	Wrench_Icon,
	Crop_Icon,
}

preload_sprites :: proc() -> ([dynamic]rl.Texture2D, map[Sprite_Type]ui.Sprite) {
	sprite_map := make(map[Sprite_Type]ui.Sprite)
	textures := make([dynamic]rl.Texture2D)

	icons := map[Sprite_Type]string{}
	icons[.Alert_Icon] = "demos/raylib/res/icons/symbol alert.png"
	icons[.Clock_Icon] = "demos/raylib/res/icons/object clock time.png"
	icons[.Charts_Icon] = "demos/raylib/res/icons/object charts.png"
	icons[.Sun_Icon] = "demos/raylib/res/icons/object sun.png"
	icons[.Wrench_Icon] = "demos/raylib/res/icons/object wrench.png"
	icons[.Crop_Icon] = "demos/raylib/res/icons/symbol crop resize.png"

	for type, fp in icons {
		img, load_err := png.load_from_file(fp, png.Options{})
		if load_err != nil {
			panic(fmt.tprintf("failed to load %s, err=%v", fp, load_err))
		}
		ui_img, convert_err := ui.image_convert_from_image(img)
		if convert_err != nil {
			log.errorf("failed to convert img, err=%v", convert_err)
		}
		image.destroy(img)
		rl_img := rl.Image {
			data    = raw_data(ui_img.pixels),
			width   = i32(ui_img.width),
			height  = i32(ui_img.height),
			mipmaps = 1,
			format  = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8,
		}
		rl_texture := rl.LoadTextureFromImage(rl_img)
		texture_idx := len(textures)
		append(&textures, rl_texture)
		sprite_map[type] = ui.Sprite {
			texture = ui.Texture_Handle(texture_idx),
			uv      = {0, 0, 1, 1},
			width   = ui_img.width,
			height  = ui_img.height,
		}
	}

	return textures, sprite_map
}
