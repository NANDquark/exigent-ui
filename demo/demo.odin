package demo

import ui ".."
import "base:runtime"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:log"
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

TEXT_STYLE_DEFAULT :: ui.Text_Style_Type("default")
TEXT_STYLE_TITLE :: ui.Text_Style_Type("title")
TEXT_STYLE_SECTION :: ui.Text_Style_Type("section")

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
	ui.init(ctx)
	ui.text_style_init(
		TEXT_STYLE_DEFAULT,
		ui.Text_Style {
			type = TEXT_STYLE_DEFAULT,
			size = 20,
			spacing = 1,
			line_height = 22,
			font = &default_font,
			color = ui.Color{0, 0, 0, 255},
		},
		nil,
		measure_width,
	)
	ui.text_style_register(
		ui.Text_Style {
			type = TEXT_STYLE_TITLE,
			size = 30,
			spacing = 1,
			line_height = 32,
			font = &default_font,
			color = ui.Color{0, 0, 0, 255},
		},
	)
	ui.text_style_register(
		ui.Text_Style {
			type = TEXT_STYLE_SECTION,
			size = 24,
			spacing = 1,
			line_height = 26,
			font = &default_font,
			color = ui.Color{0, 0, 0, 255},
		},
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

	ui.destroy(ctx)
	rl.CloseWindow()
}

input :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	// Input - Check for released keys
	it := ui.input_key_down_iterator(ctx)
	for key in ui.input_key_down_iterator_next(&it) {
		rl_key := ui_to_rl_key(key)
		if rl_key != .KEY_NULL && rl.IsKeyReleased(rl_key) {
			ui.input_key_up(ctx, key)
		}
	}

	// Input - Get all down keys
	for {
		rl_key := rl.GetKeyPressed()
		if rl_key == .KEY_NULL do break
		ui_key := rl_to_ui_key(rl_key)
		if ui_key != .None {
			ui.input_key_down(ctx, ui_key)
		}
	}

	// Input - text
	for {
		r := rl.GetCharPressed()
		if r == 0 do break
		ui.input_char(ctx, r)
	}

	// Input - Mouse
	ui.input_mouse_pos(ctx, rl.GetMousePosition())
	ui.input_scroll(ctx, rl.GetMouseWheelMove())
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
}

update :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	ui.begin(ctx, WIDTH, HEIGHT, ui.layout_fixed(WIDTH, HEIGHT, .Column, .Center, .Center)) // Update - Build UI
	defer ui.end(ctx)

	{
		panel_style := ui.style_get(ctx, ui.Widget_Type_PANEL)
		panel_style.base.background = ui.Color{210, 210, 210, 255}
		ui.style_push(ctx, ui.Widget_Type_PANEL, panel_style)
		defer ui.style_pop(ctx)

		ui.panel_begin(
			ctx,
			ui.layout_auto(
				.Column,
				.Start,
				.Center,
				padding = ui.Inset{Top = 22, Right = 28, Bottom = 22, Left = 28},
				gap = 22,
			),
		)
		defer ui.panel_end(ctx)

		title_label(ctx, "Layout showcase")
		controls_section(ctx)
		scrollboxes_section(ctx)
	}
}

title_label :: proc(ctx: ^ui.Context, txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.text_style_push(ctx, TEXT_STYLE_TITLE)
	defer ui.text_style_pop(ctx)
	ui.label(ctx, txt, .Left, .Top, caller, sub_id)
}

section_label :: proc(ctx: ^ui.Context, txt: string, caller := #caller_location, sub_id: int = 0) {
	ui.text_style_push(ctx, TEXT_STYLE_SECTION)
	defer ui.text_style_pop(ctx)
	ui.label(ctx, txt, .Left, .Top, caller, sub_id)
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
		ui.container_begin(ctx, ui.layout_auto(.Column, gap = 14))
		defer ui.container_end(ctx)

		section_label(ctx, "Controls")

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = 14))
			defer ui.container_end(ctx)

			field_label(ctx, 145, "Button:")
			ui.button(ctx, ui.layout_fixed(170, 42), "Click me!")
		}

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = 14))
			defer ui.container_end(ctx)

			field_label(ctx, 145, "Text Input:")
			ui.text_input(ctx, ui.layout_fixed(220, 36), &state.input1)
		}

		section_label(ctx, "Images")

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Center, .Center, gap = 8))
			defer ui.container_end(ctx)

			for st, sp in sprite_map {
				ui.image(ctx, ui.layout_fixed(42, 42), sp)
			}
		}
	}
}

scrollboxes_section :: proc(ctx: ^ui.Context) {
	{
		ui.container_begin(ctx, ui.layout_auto(.Column, gap = 14))
		defer ui.container_end(ctx)

		section_label(ctx, "Scrollboxes")

		{
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = 14))
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
			ui.container_begin(ctx, ui.layout_auto(.Row, .Start, .Center, gap = 14))
			defer ui.container_end(ctx)

			field_label(ctx, 170, "Content scrolls:")

			ui.scrollbox_begin(ctx, ui.layout_fixed(250, 92, .Column), &state.scroll2)
			defer ui.scrollbox_end(ctx)

			button_style := ui.style_get(ctx, ui.Widget_Type_BUTTON)
			button_style.base.background = ui.Color{140, 140, 140, 255}
			ui.style_push(ctx, ui.Widget_Type_BUTTON, button_style)
			defer ui.style_pop(ctx)

			for i in 1 ..= 3 {
				ui.container_begin(
					ctx,
					ui.layout_fixed(230, 42, .Column, .Center, .Center),
					sub_id = i,
				)
				ui.button(ctx, ui.layout_fixed(200, 34), fmt.tprintf("Button %d", i), sub_id = i)
				ui.container_end(ctx)
			}
		}
	}
}

my_draw :: proc(ctx: ^ui.Context) {
	prof_frame_part()

	rl.BeginDrawing()
	rl.ClearBackground(rl.WHITE)

	ci := ui.cmd_iterator_create(ctx)
	for cmd in ui.cmd_iterator_next(&ci) {
		switch c in cmd {
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
				x      = c.sprite.uv_min.x * f32(texture.width),
				y      = c.sprite.uv_min.y * f32(texture.height),
				width  = (c.sprite.uv_max.x - c.sprite.uv_min.x) * f32(texture.width),
				height = (c.sprite.uv_max.y - c.sprite.uv_min.y) * f32(texture.height),
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
	icons[.Alert_Icon] = "demo/res/icons/symbol alert.png"
	icons[.Clock_Icon] = "demo/res/icons/object clock time.png"
	icons[.Charts_Icon] = "demo/res/icons/object charts.png"
	icons[.Sun_Icon] = "demo/res/icons/object sun.png"
	icons[.Wrench_Icon] = "demo/res/icons/object wrench.png"
	icons[.Crop_Icon] = "demo/res/icons/symbol crop resize.png"

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
			uv_min  = {0, 0},
			uv_max  = {1, 1},
			width   = ui_img.width,
			height  = ui_img.height,
		}
	}

	return textures, sprite_map
}
