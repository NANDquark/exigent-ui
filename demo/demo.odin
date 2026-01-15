package demo

import ui "../exigent"
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

	sprite_map, texture_map := preload_sprites()

	// Initialize UI related context and defaults
	ctx := &ui.Context{}
	ui.context_init(ctx)
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
			update(ctx, sprite_map)
			my_draw(ctx, texture_map)
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
	for {
		key, ok := ui.input_key_down_iterator_next(&it)
		if !ok do break
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

update :: proc(ctx: ^ui.Context, sprite_map: map[Sprite_Type]ui.Sprite) {
	prof_frame_part()

	ui.begin(ctx, WIDTH, HEIGHT) // Update - Build UI
	defer ui.end(ctx)

	r := ui.Rect{0, 0, WIDTH, HEIGHT}

	scrollbox := ui.rect_cut_top(&r, 300)
	scrollbox = ui.rect_inset(scrollbox, ui.Inset{20, 90, 20, 90})
	ui.scrollbox_begin(ctx, &scrollbox, &state.scroll1)

	scroll_line1 := ui.rect_take_top(&scrollbox, 100)
	scroll_line1 = ui.rect_inset(scroll_line1, 10)
	if (ui.button(ctx, scroll_line1, "One").released) {
		fmt.println("Scroll btn 1 clicked")
	}

	scroll_line2 := ui.rect_take_top(&scrollbox, 100)
	scroll_line2 = ui.rect_inset(scroll_line2, 10)
	if (ui.button(ctx, scroll_line2, "Two").released) {
		fmt.println("Scroll btn 2 clicked")
	}

	scroll_line3 := ui.rect_take_top(&scrollbox, 100)
	scroll_line3 = ui.rect_inset(scroll_line3, 10)
	if (ui.button(ctx, scroll_line3, "Three").released) {
		fmt.println("Scroll btn 3 clicked")
	}

	ui.scrollbox_end(ctx)

	line1 := ui.rect_cut_top(&r, 100)
	line1 = ui.rect_inset(line1, ui.Inset{20, 90, 20, 90})
	input_label := ui.rect_cut_left(&line1, line1.w / 2)
	ui.label(ctx, input_label, "Input: ")
	input := line1
	ui.text_input(ctx, input, &state.input1)

	line2 := ui.rect_cut_top(&r, 100)
	line2 = ui.rect_inset(line2, ui.Inset{20, 90, 20, 90})
	icon_width := math.floor(line2.w / f32(len(sprite_map)))
	for st, sp in sprite_map {
		icon := ui.rect_cut_left(&line2, icon_width)
		ui.draw_sprite(ctx, sp, icon)
	}
}

my_draw :: proc(ctx: ^ui.Context, texture_map: map[ui.Atlas_Handle]rl.Texture2D) {
	prof_frame_part()

	rl.BeginDrawing()
	rl.ClearBackground(rl.WHITE)

	ci := ui.cmd_iterator_create(ctx)
	draw_ui: for {
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
			texture := texture_map[c.sprite.atlas]
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

measure_width :: proc(style: ui.Text_Style, text: string) -> f32 {
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

preload_sprites :: proc() -> (map[Sprite_Type]ui.Sprite, map[ui.Atlas_Handle]rl.Texture2D) {
	sprite_map := make(map[Sprite_Type]ui.Sprite)
	texture_map := make(map[ui.Atlas_Handle]rl.Texture2D)

	sp := ui.Sprite_Packer{}
	ui.sprite_packer_init(&sp)

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
		sprite, add_err := ui.sprite_packer_add(&sp, ui_img)
		if add_err != nil {
			log.errorf("failed to add sprite, err=%v", add_err)
		}
		sprite_map[type] = sprite
	}

	it := ui.sprite_packer_make_iter(&sp)
	for {
		atlas_texture, ok := ui.sprite_packer_iter_next(&it)
		if !ok {
			break
		}
		rl_img := rl.Image {
			data    = raw_data(atlas_texture.texture.pixels),
			width   = i32(atlas_texture.texture.width),
			height  = i32(atlas_texture.texture.height),
			mipmaps = 1,
			format  = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8,
		}
		rl_texture := rl.LoadTextureFromImage(rl_img)
		texture_map[atlas_texture.handle] = rl_texture
	}

	return sprite_map, texture_map
}
