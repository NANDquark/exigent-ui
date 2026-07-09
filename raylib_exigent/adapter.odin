package raylib_exigent

import ui "../"
import "core:c"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

when ODIN_OS == .JS {
	foreign import env "env"
	foreign env {
		emscripten_notify_memory_growth :: proc "c" (memory_index: int) ---
	}
}

Renderer :: struct {
	textures:            map[ui.Texture_Handle]rl.Texture2D,
	next_texture_handle: ui.Texture_Handle,
	clip_stack:          [dynamic]rl.Rectangle,
	allocator:           mem.Allocator,
}

init :: proc(renderer: ^Renderer, allocator := context.allocator) {
	renderer.allocator = allocator
	renderer.textures = make(map[ui.Texture_Handle]rl.Texture2D, allocator)
	renderer.clip_stack = make([dynamic]rl.Rectangle, allocator)
	renderer.next_texture_handle = ui.Texture_Handle(1)
}

destroy :: proc(renderer: ^Renderer, destroy_textures := false) {
	if destroy_textures {
		for _, texture in renderer.textures {
			if rl.IsTextureValid(texture) {
				rl.UnloadTexture(texture)
			}
		}
	}
	delete(renderer.textures)
	delete(renderer.clip_stack)
	renderer^ = {}
}

register_texture :: proc(renderer: ^Renderer, texture: rl.Texture2D) -> ui.Texture_Handle {
	handle := renderer.next_texture_handle
	renderer.next_texture_handle = ui.Texture_Handle(u64(renderer.next_texture_handle) + 1)
	renderer.textures[handle] = texture
	return handle
}

load_sprite_from_file :: proc(renderer: ^Renderer, filename: string) -> ui.Sprite {
	c_filename := strings.clone_to_cstring(filename, context.temp_allocator)
	notify_memory_growth()
	texture := rl.LoadTexture(c_filename)
	if !rl.IsTextureValid(texture) {
		return {}
	}
	return sprite_from_texture(renderer, texture)
}

load_sprite_from_bytes :: proc(
	renderer: ^Renderer,
	bytes: []u8,
	file_type: cstring = ".png",
) -> ui.Sprite {
	if len(bytes) == 0 {
		return {}
	}

	image := rl.LoadImageFromMemory(file_type, raw_data(bytes), c.int(len(bytes)))
	if !rl.IsImageValid(image) {
		return {}
	}
	defer rl.UnloadImage(image)

	texture := rl.LoadTextureFromImage(image)
	if !rl.IsTextureValid(texture) {
		return {}
	}
	return sprite_from_texture(renderer, texture)
}

sprite_from_texture :: proc(renderer: ^Renderer, texture: rl.Texture2D) -> ui.Sprite {
	handle := register_texture(renderer, texture)
	return sprite_from_registered_texture(handle, texture)
}

sprite_from_texture_region :: proc(
	renderer: ^Renderer,
	texture: rl.Texture2D,
	region: ui.Rect,
) -> ui.Sprite {
	handle := register_texture(renderer, texture)
	return sprite_from_registered_texture(handle, texture, region)
}

sprite_from_registered_texture :: proc(
	handle: ui.Texture_Handle,
	texture: rl.Texture2D,
	region: ui.Rect = {},
) -> ui.Sprite {
	if texture.width <= 0 || texture.height <= 0 {
		return ui.Sprite{texture = handle}
	}

	r := region
	if r == {} {
		r = ui.Rect {
			x = 0,
			y = 0,
			w = f32(texture.width),
			h = f32(texture.height),
		}
	}

	return ui.Sprite {
		texture = handle,
		uv = ui.Rect {
			x = r.x / f32(texture.width),
			y = r.y / f32(texture.height),
			w = r.w / f32(texture.width),
			h = r.h / f32(texture.height),
		},
		width = int(r.w),
		height = int(r.h),
	}
}

draw :: proc(renderer: ^Renderer, ctx: ^ui.Context) {
	clear(&renderer.clip_stack)

	it := ui.cmd_iterator_create(ctx)
	for cmd in ui.cmd_iterator_next(&it) {
		switch c in cmd {
		case ui.Command_Clip:
			clip_push(renderer, c.rect)
		case ui.Command_Unclip:
			clip_pop(renderer)
		case ui.Command_Rect:
			draw_rect(c)
		case ui.Command_Text:
			draw_text(c)
		case ui.Command_Sprite:
			draw_sprite(renderer, c)
		}
	}

	for len(renderer.clip_stack) > 0 {
		rl.EndScissorMode()
		pop(&renderer.clip_stack)
	}
}

feed_input :: proc(ctx: ^ui.Context) {
	events := make([dynamic]ui.Input_Event, 0, 32, context.temp_allocator)

	it := ui.input_key_down_iterator(ctx)
	for key in ui.input_key_down_iterator_next(&it) {
		rl_key := ui_key_to_rl(key)
		if rl_key != .KEY_NULL && rl.IsKeyReleased(rl_key) {
			append(&events, ui.Key_Event{key = key, type = .Released})
		}
	}

	for {
		rl_key := rl.GetKeyPressed()
		if rl_key == .KEY_NULL do break
		ui_key := rl_key_to_ui(rl_key)
		if ui_key != .None {
			append(&events, ui.Key_Event{key = ui_key, type = .Pressed})
		}
	}

	for {
		r := rl.GetCharPressed()
		if r == 0 do break
		append(&events, ui.Char_Event{c = r})
	}

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
		input_is_key_down,
		input_is_mouse_down,
		events[:],
	)
}

measure_text :: proc(data: rawptr, style: ui.Text_Style, text: string) -> f32 {
	c_text := strings.clone_to_cstring(text, context.temp_allocator)
	notify_memory_growth()
	font := rl.GetFontDefault()
	if style.font != nil {
		font = (cast(^rl.Font)style.font)^
	}
	return rl.MeasureTextEx(font, c_text, style.size, style.spacing).x
}

input_is_key_down :: proc(user_data: rawptr, key: ui.Key) -> bool {
	rl_key := ui_key_to_rl(key)
	if rl_key == .KEY_NULL {
		return false
	}
	return rl.IsKeyDown(rl_key)
}

input_is_mouse_down :: proc(user_data: rawptr, button: ui.Mouse_Button) -> bool {
	return rl.IsMouseButtonDown(ui_mouse_button_to_rl(button))
}

clip_push :: proc(renderer: ^Renderer, rect: ui.Rect) {
	new_rect := scissor_rect(rect)
	if len(renderer.clip_stack) > 0 {
		new_rect = rect_intersect_rl(renderer.clip_stack[len(renderer.clip_stack) - 1], new_rect)
		rl.EndScissorMode()
	}

	append(&renderer.clip_stack, new_rect)
	rl.BeginScissorMode(
		c.int(new_rect.x),
		c.int(new_rect.y),
		c.int(new_rect.width),
		c.int(new_rect.height),
	)
}

clip_pop :: proc(renderer: ^Renderer) {
	if len(renderer.clip_stack) == 0 {
		return
	}

	pop(&renderer.clip_stack)
	rl.EndScissorMode()
	if len(renderer.clip_stack) == 0 {
		return
	}

	rect := renderer.clip_stack[len(renderer.clip_stack) - 1]
	rl.BeginScissorMode(c.int(rect.x), c.int(rect.y), c.int(rect.width), c.int(rect.height))
}

draw_rect :: proc(cmd: ui.Command_Rect) {
	rect := to_rl_rect(cmd.rect)
	rl.DrawRectangleRec(rect, to_rl_color(cmd.color))

	switch cmd.border.type {
	case .None:
	case .Square:
		border_rect := rl.Rectangle {
			x      = cmd.rect.x - cmd.border.thickness,
			y      = cmd.rect.y - cmd.border.thickness,
			width  = cmd.rect.w + cmd.border.thickness * 2,
			height = cmd.rect.h + cmd.border.thickness * 2,
		}
		rl.DrawRectangleLinesEx(border_rect, cmd.border.thickness, to_rl_color(cmd.border.color))
	}
}

draw_text :: proc(cmd: ui.Command_Text) {
	c_text := strings.clone_to_cstring(cmd.text, context.temp_allocator)
	notify_memory_growth()
	font := rl.GetFontDefault()
	if cmd.style.font != nil {
		font = (cast(^rl.Font)cmd.style.font)^
	}
	rl.DrawTextEx(
		font,
		c_text,
		rl.Vector2(cmd.pos),
		cmd.style.size,
		cmd.style.spacing,
		to_rl_color(cmd.style.color),
	)
}

draw_sprite :: proc(renderer: ^Renderer, cmd: ui.Command_Sprite) {
	texture, ok := renderer.textures[cmd.sprite.texture]
	if !ok {
		return
	}
	rl.DrawTexturePro(
		texture,
		sprite_source_rect(cmd.sprite, texture),
		to_rl_rect(cmd.rect),
		{},
		0,
		rl.WHITE,
	)
}

sprite_source_rect :: proc(sprite: ui.Sprite, texture: rl.Texture2D) -> rl.Rectangle {
	return rl.Rectangle {
		x = sprite.uv.x * f32(texture.width),
		y = sprite.uv.y * f32(texture.height),
		width = sprite.uv.w * f32(texture.width),
		height = sprite.uv.h * f32(texture.height),
	}
}

to_rl_rect :: proc(r: ui.Rect) -> rl.Rectangle {
	return rl.Rectangle{x = r.x, y = r.y, width = r.w, height = r.h}
}

to_rl_color :: proc(color: ui.Color) -> rl.Color {
	return rl.Color{color.r, color.g, color.b, color.a}
}

notify_memory_growth :: proc() {
	when ODIN_OS == .JS {
		emscripten_notify_memory_growth(0)
	}
}

scissor_rect :: proc(r: ui.Rect) -> rl.Rectangle {
	x0 := math.floor(r.x)
	y0 := math.floor(r.y)
	x1 := math.ceil(r.x + r.w)
	y1 := math.ceil(r.y + r.h)
	return rl.Rectangle{x = x0, y = y0, width = x1 - x0, height = y1 - y0}
}

rect_intersect_rl :: proc(a, b: rl.Rectangle) -> rl.Rectangle {
	x0 := max(a.x, b.x)
	y0 := max(a.y, b.y)
	x1 := min(a.x + a.width, b.x + b.width)
	y1 := min(a.y + a.height, b.y + b.height)
	return rl.Rectangle{x = x0, y = y0, width = max(x1 - x0, 0), height = max(y1 - y0, 0)}
}

ui_mouse_button_to_rl :: proc(button: ui.Mouse_Button) -> rl.MouseButton {
	switch button {
	case .Left:
		return .LEFT
	case .Right:
		return .RIGHT
	case .Middle:
		return .MIDDLE
	}
	return .LEFT
}

rl_mouse_button_to_ui :: proc(button: rl.MouseButton) -> ui.Mouse_Button {
	#partial switch button {
	case .LEFT:
		return .Left
	case .RIGHT:
		return .Right
	case .MIDDLE:
		return .Middle
	}
	return .Left
}

rl_key_to_ui :: proc(key: rl.KeyboardKey) -> ui.Key {
	#partial switch key {
	case .ZERO:
		return .Zero
	case .ONE:
		return .One
	case .TWO:
		return .Two
	case .THREE:
		return .Three
	case .FOUR:
		return .Four
	case .FIVE:
		return .Five
	case .SIX:
		return .Six
	case .SEVEN:
		return .Seven
	case .EIGHT:
		return .Eight
	case .NINE:
		return .Nine
	case .A:
		return .A
	case .B:
		return .B
	case .C:
		return .C
	case .D:
		return .D
	case .E:
		return .E
	case .F:
		return .F
	case .G:
		return .G
	case .H:
		return .H
	case .I:
		return .I
	case .J:
		return .J
	case .K:
		return .K
	case .L:
		return .L
	case .M:
		return .M
	case .N:
		return .N
	case .O:
		return .O
	case .P:
		return .P
	case .Q:
		return .Q
	case .R:
		return .R
	case .S:
		return .S
	case .T:
		return .T
	case .U:
		return .U
	case .V:
		return .V
	case .W:
		return .W
	case .X:
		return .X
	case .Y:
		return .Y
	case .Z:
		return .Z
	case .APOSTROPHE:
		return .Apostrophe
	case .COMMA:
		return .Comma
	case .MINUS:
		return .Minus
	case .PERIOD:
		return .Period
	case .SLASH:
		return .Slash
	case .SEMICOLON:
		return .Semicolon
	case .EQUAL:
		return .Equal
	case .LEFT_BRACKET:
		return .LeftBracket
	case .BACKSLASH:
		return .Backslash
	case .RIGHT_BRACKET:
		return .RightBracket
	case .GRAVE:
		return .Backtick
	case .SPACE:
		return .Space
	case .ESCAPE:
		return .Escape
	case .ENTER:
		return .Enter
	case .TAB:
		return .Tab
	case .BACKSPACE:
		return .Backspace
	case .INSERT:
		return .Insert
	case .DELETE:
		return .Delete
	case .RIGHT:
		return .Right
	case .LEFT:
		return .Left
	case .DOWN:
		return .Down
	case .UP:
		return .Up
	case .PAGE_UP:
		return .PageUp
	case .PAGE_DOWN:
		return .PageDown
	case .HOME:
		return .Home
	case .END:
		return .End
	case .CAPS_LOCK:
		return .CapsLock
	case .SCROLL_LOCK:
		return .ScrollLock
	case .NUM_LOCK:
		return .NumLock
	case .PRINT_SCREEN:
		return .PrintScreen
	case .PAUSE:
		return .Pause
	case .F1:
		return .F1
	case .F2:
		return .F2
	case .F3:
		return .F3
	case .F4:
		return .F4
	case .F5:
		return .F5
	case .F6:
		return .F6
	case .F7:
		return .F7
	case .F8:
		return .F8
	case .F9:
		return .F9
	case .F10:
		return .F10
	case .F11:
		return .F11
	case .F12:
		return .F12
	case .LEFT_SHIFT:
		return .LShift
	case .RIGHT_SHIFT:
		return .RShift
	case .LEFT_CONTROL:
		return .LCtrl
	case .RIGHT_CONTROL:
		return .RCtrl
	case .LEFT_ALT:
		return .LAlt
	case .RIGHT_ALT:
		return .RAlt
	case .LEFT_SUPER:
		return .LSuper
	case .RIGHT_SUPER:
		return .RSuper
	case .KB_MENU:
		return .Menu
	case .KP_0:
		return .KP_0
	case .KP_1:
		return .KP_1
	case .KP_2:
		return .KP_2
	case .KP_3:
		return .KP_3
	case .KP_4:
		return .KP_4
	case .KP_5:
		return .KP_5
	case .KP_6:
		return .KP_6
	case .KP_7:
		return .KP_7
	case .KP_8:
		return .KP_8
	case .KP_9:
		return .KP_9
	case .KP_DECIMAL:
		return .KP_Decimal
	case .KP_DIVIDE:
		return .KP_Divide
	case .KP_MULTIPLY:
		return .KP_Multiply
	case .KP_SUBTRACT:
		return .KP_Subtract
	case .KP_ADD:
		return .KP_Add
	case .KP_ENTER:
		return .KP_Enter
	}
	return .None
}

ui_key_to_rl :: proc(key: ui.Key) -> rl.KeyboardKey {
	#partial switch key {
	case .Zero:
		return .ZERO
	case .One:
		return .ONE
	case .Two:
		return .TWO
	case .Three:
		return .THREE
	case .Four:
		return .FOUR
	case .Five:
		return .FIVE
	case .Six:
		return .SIX
	case .Seven:
		return .SEVEN
	case .Eight:
		return .EIGHT
	case .Nine:
		return .NINE
	case .A:
		return .A
	case .B:
		return .B
	case .C:
		return .C
	case .D:
		return .D
	case .E:
		return .E
	case .F:
		return .F
	case .G:
		return .G
	case .H:
		return .H
	case .I:
		return .I
	case .J:
		return .J
	case .K:
		return .K
	case .L:
		return .L
	case .M:
		return .M
	case .N:
		return .N
	case .O:
		return .O
	case .P:
		return .P
	case .Q:
		return .Q
	case .R:
		return .R
	case .S:
		return .S
	case .T:
		return .T
	case .U:
		return .U
	case .V:
		return .V
	case .W:
		return .W
	case .X:
		return .X
	case .Y:
		return .Y
	case .Z:
		return .Z
	case .Apostrophe:
		return .APOSTROPHE
	case .Comma:
		return .COMMA
	case .Minus:
		return .MINUS
	case .Period:
		return .PERIOD
	case .Slash:
		return .SLASH
	case .Semicolon:
		return .SEMICOLON
	case .Equal:
		return .EQUAL
	case .LeftBracket:
		return .LEFT_BRACKET
	case .Backslash:
		return .BACKSLASH
	case .RightBracket:
		return .RIGHT_BRACKET
	case .Backtick:
		return .GRAVE
	case .Space:
		return .SPACE
	case .Escape:
		return .ESCAPE
	case .Enter:
		return .ENTER
	case .Tab:
		return .TAB
	case .Backspace:
		return .BACKSPACE
	case .Insert:
		return .INSERT
	case .Delete:
		return .DELETE
	case .Right:
		return .RIGHT
	case .Left:
		return .LEFT
	case .Down:
		return .DOWN
	case .Up:
		return .UP
	case .PageUp:
		return .PAGE_UP
	case .PageDown:
		return .PAGE_DOWN
	case .Home:
		return .HOME
	case .End:
		return .END
	case .CapsLock:
		return .CAPS_LOCK
	case .ScrollLock:
		return .SCROLL_LOCK
	case .NumLock:
		return .NUM_LOCK
	case .PrintScreen:
		return .PRINT_SCREEN
	case .Pause:
		return .PAUSE
	case .F1:
		return .F1
	case .F2:
		return .F2
	case .F3:
		return .F3
	case .F4:
		return .F4
	case .F5:
		return .F5
	case .F6:
		return .F6
	case .F7:
		return .F7
	case .F8:
		return .F8
	case .F9:
		return .F9
	case .F10:
		return .F10
	case .F11:
		return .F11
	case .F12:
		return .F12
	case .LShift:
		return .LEFT_SHIFT
	case .RShift:
		return .RIGHT_SHIFT
	case .LCtrl:
		return .LEFT_CONTROL
	case .RCtrl:
		return .RIGHT_CONTROL
	case .LAlt:
		return .LEFT_ALT
	case .RAlt:
		return .RIGHT_ALT
	case .LSuper:
		return .LEFT_SUPER
	case .RSuper:
		return .RIGHT_SUPER
	case .Menu:
		return .KB_MENU
	case .KP_0:
		return .KP_0
	case .KP_1:
		return .KP_1
	case .KP_2:
		return .KP_2
	case .KP_3:
		return .KP_3
	case .KP_4:
		return .KP_4
	case .KP_5:
		return .KP_5
	case .KP_6:
		return .KP_6
	case .KP_7:
		return .KP_7
	case .KP_8:
		return .KP_8
	case .KP_9:
		return .KP_9
	case .KP_Decimal:
		return .KP_DECIMAL
	case .KP_Divide:
		return .KP_DIVIDE
	case .KP_Multiply:
		return .KP_MULTIPLY
	case .KP_Subtract:
		return .KP_SUBTRACT
	case .KP_Add:
		return .KP_ADD
	case .KP_Enter:
		return .KP_ENTER
	}
	return .KEY_NULL
}
