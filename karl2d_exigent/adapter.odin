package karl2d_exigent

import ui "exigent:."
import k2 "karl2d:."
import "core:mem"

Renderer :: struct {
	textures:            map[ui.Texture_Handle]k2.Texture,
	next_texture_handle: ui.Texture_Handle,
	clip_stack:          [dynamic]k2.Rect,
	allocator:           mem.Allocator,
}

init :: proc(renderer: ^Renderer, allocator := context.allocator) {
	renderer.allocator = allocator
	renderer.textures = make(map[ui.Texture_Handle]k2.Texture, allocator)
	renderer.clip_stack = make([dynamic]k2.Rect, allocator)
	renderer.next_texture_handle = ui.Texture_Handle(1)
}

destroy :: proc(renderer: ^Renderer, destroy_textures := false) {
	if destroy_textures {
		for _, texture in renderer.textures {
			k2.destroy_texture(texture)
		}
	}
	delete(renderer.textures)
	delete(renderer.clip_stack)
	renderer^ = {}
}

register_texture :: proc(renderer: ^Renderer, texture: k2.Texture) -> ui.Texture_Handle {
	handle := renderer.next_texture_handle
	renderer.next_texture_handle = ui.Texture_Handle(u64(renderer.next_texture_handle) + 1)
	renderer.textures[handle] = texture
	return handle
}

load_sprite_from_file :: proc(
	renderer: ^Renderer,
	filename: string,
	options := k2.Load_Texture_Options{},
) -> ui.Sprite {
	texture := k2.load_texture_from_file(filename, options)
	return sprite_from_texture(renderer, texture)
}

load_sprite_from_bytes :: proc(
	renderer: ^Renderer,
	bytes: []u8,
	options := k2.Load_Texture_Options{},
) -> ui.Sprite {
	texture := k2.load_texture_from_bytes(bytes, options)
	return sprite_from_texture(renderer, texture)
}

sprite_from_texture :: proc(renderer: ^Renderer, texture: k2.Texture) -> ui.Sprite {
	handle := register_texture(renderer, texture)
	return ui.Sprite {
		texture = handle,
		uv      = ui.Rect{0, 0, 1, 1},
		width   = texture.width,
		height  = texture.height,
	}
}

draw :: proc(renderer: ^Renderer, ctx: ^ui.Context) {
	clear(&renderer.clip_stack)
	k2.set_scissor_rect(nil)

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

	clear(&renderer.clip_stack)
	k2.set_scissor_rect(nil)
}

feed_input :: proc(ctx: ^ui.Context) {
	events := make([dynamic]ui.Input_Event, 0, 32, context.temp_allocator)

	for event in k2.get_events() {
		#partial switch e in event {
		case k2.Event_Key_Went_Down:
			key := k2_key_to_ui(e.key)
			if key != .None {
				append(&events, ui.Key_Event{key = key, type = .Pressed})
				if c, ok := key_to_char(key); ok {
					append(&events, ui.Char_Event{c = shifted_char(c)})
				}
			}
		case k2.Event_Key_Went_Up:
			key := k2_key_to_ui(e.key)
			if key != .None {
				append(&events, ui.Key_Event{key = key, type = .Released})
			}
		case k2.Event_Mouse_Button_Went_Down:
			append(&events, ui.Mouse_Event{button = k2_mouse_button_to_ui(e.button), type = .Pressed})
		case k2.Event_Mouse_Button_Went_Up:
			append(&events, ui.Mouse_Event{button = k2_mouse_button_to_ui(e.button), type = .Released})
		case k2.Event_Window_Focused:
			append(&events, ui.Focus_Event{focused = true})
		case k2.Event_Window_Unfocused:
			append(&events, ui.Focus_Event{focused = false})
		}
	}

	ui.input_feed_external(
		ctx,
		k2.get_mouse_position(),
		k2.get_mouse_wheel_delta(),
		nil,
		k2_input_is_key_down,
		k2_input_is_mouse_down,
		events[:],
	)
}

measure_text :: proc(data: rawptr, style: ui.Text_Style, text: string) -> f32 {
	font := k2.FONT_DEFAULT
	if style.font != nil {
		font = (cast(^k2.Font)style.font)^
	}
	return k2.measure_text(text, style.size, font).x
}

clip_push :: proc(renderer: ^Renderer, rect: ui.Rect) {
	append(&renderer.clip_stack, to_k2_rect(rect))
	k2.set_scissor_rect(renderer.clip_stack[len(renderer.clip_stack) - 1])
}

clip_pop :: proc(renderer: ^Renderer) {
	if len(renderer.clip_stack) > 0 {
		pop(&renderer.clip_stack)
	}
	if len(renderer.clip_stack) == 0 {
		k2.set_scissor_rect(nil)
		return
	}
	k2.set_scissor_rect(renderer.clip_stack[len(renderer.clip_stack) - 1])
}

draw_rect :: proc(cmd: ui.Command_Rect) {
	rect := to_k2_rect(cmd.rect)
	k2.draw_rect(rect, to_k2_color(cmd.color))

	switch cmd.border.type {
	case .None:
	case .Square:
		border_rect := k2.Rect {
			x = cmd.rect.x - cmd.border.thickness,
			y = cmd.rect.y - cmd.border.thickness,
			w = cmd.rect.w + cmd.border.thickness * 2,
			h = cmd.rect.h + cmd.border.thickness * 2,
		}
		k2.draw_rect_outline(border_rect, cmd.border.thickness, to_k2_color(cmd.border.color))
	}
}

draw_text :: proc(cmd: ui.Command_Text) {
	font := k2.FONT_DEFAULT
	if cmd.style.font != nil {
		font = (cast(^k2.Font)cmd.style.font)^
	}
	k2.draw_text(cmd.text, k2.Vec2(cmd.pos), cmd.style.size, to_k2_color(cmd.style.color), font)
}

draw_sprite :: proc(renderer: ^Renderer, cmd: ui.Command_Sprite) {
	texture, ok := renderer.textures[cmd.sprite.texture]
	if !ok {
		return
	}
	k2.draw_texture_fit(texture, sprite_source_rect(cmd.sprite, texture), to_k2_rect(cmd.rect))
}

k2_input_is_key_down :: proc(user_data: rawptr, key: ui.Key) -> bool {
	k2_key := ui_key_to_k2(key)
	if k2_key == .None {
		return false
	}
	return k2.key_is_held(k2_key)
}

k2_input_is_mouse_down :: proc(user_data: rawptr, button: ui.Mouse_Button) -> bool {
	return k2.mouse_button_is_held(ui_mouse_button_to_k2(button))
}

sprite_source_rect :: proc(sprite: ui.Sprite, texture: k2.Texture) -> k2.Rect {
	return k2.Rect {
		x = sprite.uv.x * f32(texture.width),
		y = sprite.uv.y * f32(texture.height),
		w = sprite.uv.w * f32(texture.width),
		h = sprite.uv.h * f32(texture.height),
	}
}

to_k2_rect :: proc(r: ui.Rect) -> k2.Rect {
	return k2.Rect{x = r.x, y = r.y, w = r.w, h = r.h}
}

to_k2_color :: proc(c: ui.Color) -> k2.Color {
	return k2.Color{c.r, c.g, c.b, c.a}
}

k2_mouse_button_to_ui :: proc(button: k2.Mouse_Button) -> ui.Mouse_Button {
	#partial switch button {
	case .Left:
		return .Left
	case .Right:
		return .Right
	case .Middle:
		return .Middle
	}
	return .Left
}

ui_mouse_button_to_k2 :: proc(button: ui.Mouse_Button) -> k2.Mouse_Button {
	switch button {
	case .Left:
		return .Left
	case .Right:
		return .Right
	case .Middle:
		return .Middle
	}
	return .Left
}

k2_key_to_ui :: proc(key: k2.Keyboard_Key) -> ui.Key {
	#partial switch key {
	case .N0: return .Zero
	case .N1: return .One
	case .N2: return .Two
	case .N3: return .Three
	case .N4: return .Four
	case .N5: return .Five
	case .N6: return .Six
	case .N7: return .Seven
	case .N8: return .Eight
	case .N9: return .Nine
	case .A: return .A
	case .B: return .B
	case .C: return .C
	case .D: return .D
	case .E: return .E
	case .F: return .F
	case .G: return .G
	case .H: return .H
	case .I: return .I
	case .J: return .J
	case .K: return .K
	case .L: return .L
	case .M: return .M
	case .N: return .N
	case .O: return .O
	case .P: return .P
	case .Q: return .Q
	case .R: return .R
	case .S: return .S
	case .T: return .T
	case .U: return .U
	case .V: return .V
	case .W: return .W
	case .X: return .X
	case .Y: return .Y
	case .Z: return .Z
	case .Apostrophe: return .Apostrophe
	case .Comma: return .Comma
	case .Minus: return .Minus
	case .Period: return .Period
	case .Slash: return .Slash
	case .Semicolon: return .Semicolon
	case .Equal: return .Equal
	case .Left_Bracket: return .LeftBracket
	case .Backslash: return .Backslash
	case .Right_Bracket: return .RightBracket
	case .Backtick: return .Backtick
	case .Space: return .Space
	case .Escape: return .Escape
	case .Enter: return .Enter
	case .Tab: return .Tab
	case .Backspace: return .Backspace
	case .Insert: return .Insert
	case .Delete: return .Delete
	case .Right: return .Right
	case .Left: return .Left
	case .Down: return .Down
	case .Up: return .Up
	case .Page_Up: return .PageUp
	case .Page_Down: return .PageDown
	case .Home: return .Home
	case .End: return .End
	case .Caps_Lock: return .CapsLock
	case .Scroll_Lock: return .ScrollLock
	case .Num_Lock: return .NumLock
	case .Print_Screen: return .PrintScreen
	case .Pause: return .Pause
	case .F1: return .F1
	case .F2: return .F2
	case .F3: return .F3
	case .F4: return .F4
	case .F5: return .F5
	case .F6: return .F6
	case .F7: return .F7
	case .F8: return .F8
	case .F9: return .F9
	case .F10: return .F10
	case .F11: return .F11
	case .F12: return .F12
	case .Left_Shift: return .LShift
	case .Right_Shift: return .RShift
	case .Left_Control: return .LCtrl
	case .Right_Control: return .RCtrl
	case .Left_Alt: return .LAlt
	case .Right_Alt: return .RAlt
	case .Left_Super: return .LSuper
	case .Right_Super: return .RSuper
	case .Menu: return .Menu
	case .NP_0: return .KP_0
	case .NP_1: return .KP_1
	case .NP_2: return .KP_2
	case .NP_3: return .KP_3
	case .NP_4: return .KP_4
	case .NP_5: return .KP_5
	case .NP_6: return .KP_6
	case .NP_7: return .KP_7
	case .NP_8: return .KP_8
	case .NP_9: return .KP_9
	case .NP_Decimal: return .KP_Decimal
	case .NP_Divide: return .KP_Divide
	case .NP_Multiply: return .KP_Multiply
	case .NP_Subtract: return .KP_Subtract
	case .NP_Add: return .KP_Add
	case .NP_Enter: return .KP_Enter
	}
	return .None
}

ui_key_to_k2 :: proc(key: ui.Key) -> k2.Keyboard_Key {
	#partial switch key {
	case .Zero: return .N0
	case .One: return .N1
	case .Two: return .N2
	case .Three: return .N3
	case .Four: return .N4
	case .Five: return .N5
	case .Six: return .N6
	case .Seven: return .N7
	case .Eight: return .N8
	case .Nine: return .N9
	case .A: return .A
	case .B: return .B
	case .C: return .C
	case .D: return .D
	case .E: return .E
	case .F: return .F
	case .G: return .G
	case .H: return .H
	case .I: return .I
	case .J: return .J
	case .K: return .K
	case .L: return .L
	case .M: return .M
	case .N: return .N
	case .O: return .O
	case .P: return .P
	case .Q: return .Q
	case .R: return .R
	case .S: return .S
	case .T: return .T
	case .U: return .U
	case .V: return .V
	case .W: return .W
	case .X: return .X
	case .Y: return .Y
	case .Z: return .Z
	case .Apostrophe: return .Apostrophe
	case .Comma: return .Comma
	case .Minus: return .Minus
	case .Period: return .Period
	case .Slash: return .Slash
	case .Semicolon: return .Semicolon
	case .Equal: return .Equal
	case .LeftBracket: return .Left_Bracket
	case .Backslash: return .Backslash
	case .RightBracket: return .Right_Bracket
	case .Backtick: return .Backtick
	case .Space: return .Space
	case .Escape: return .Escape
	case .Enter: return .Enter
	case .Tab: return .Tab
	case .Backspace: return .Backspace
	case .Insert: return .Insert
	case .Delete: return .Delete
	case .Right: return .Right
	case .Left: return .Left
	case .Down: return .Down
	case .Up: return .Up
	case .PageUp: return .Page_Up
	case .PageDown: return .Page_Down
	case .Home: return .Home
	case .End: return .End
	case .CapsLock: return .Caps_Lock
	case .ScrollLock: return .Scroll_Lock
	case .NumLock: return .Num_Lock
	case .PrintScreen: return .Print_Screen
	case .Pause: return .Pause
	case .F1: return .F1
	case .F2: return .F2
	case .F3: return .F3
	case .F4: return .F4
	case .F5: return .F5
	case .F6: return .F6
	case .F7: return .F7
	case .F8: return .F8
	case .F9: return .F9
	case .F10: return .F10
	case .F11: return .F11
	case .F12: return .F12
	case .LShift: return .Left_Shift
	case .RShift: return .Right_Shift
	case .LCtrl: return .Left_Control
	case .RCtrl: return .Right_Control
	case .LAlt: return .Left_Alt
	case .RAlt: return .Right_Alt
	case .LSuper: return .Left_Super
	case .RSuper: return .Right_Super
	case .Menu: return .Menu
	case .KP_0: return .NP_0
	case .KP_1: return .NP_1
	case .KP_2: return .NP_2
	case .KP_3: return .NP_3
	case .KP_4: return .NP_4
	case .KP_5: return .NP_5
	case .KP_6: return .NP_6
	case .KP_7: return .NP_7
	case .KP_8: return .NP_8
	case .KP_9: return .NP_9
	case .KP_Decimal: return .NP_Decimal
	case .KP_Divide: return .NP_Divide
	case .KP_Multiply: return .NP_Multiply
	case .KP_Subtract: return .NP_Subtract
	case .KP_Add: return .NP_Add
	case .KP_Enter: return .NP_Enter
	}
	return .None
}

key_to_char :: proc(key: ui.Key) -> (rune, bool) {
	#partial switch key {
	case .A: return 'a', true
	case .B: return 'b', true
	case .C: return 'c', true
	case .D: return 'd', true
	case .E: return 'e', true
	case .F: return 'f', true
	case .G: return 'g', true
	case .H: return 'h', true
	case .I: return 'i', true
	case .J: return 'j', true
	case .K: return 'k', true
	case .L: return 'l', true
	case .M: return 'm', true
	case .N: return 'n', true
	case .O: return 'o', true
	case .P: return 'p', true
	case .Q: return 'q', true
	case .R: return 'r', true
	case .S: return 's', true
	case .T: return 't', true
	case .U: return 'u', true
	case .V: return 'v', true
	case .W: return 'w', true
	case .X: return 'x', true
	case .Y: return 'y', true
	case .Z: return 'z', true
	case .Zero, .KP_0: return '0', true
	case .One, .KP_1: return '1', true
	case .Two, .KP_2: return '2', true
	case .Three, .KP_3: return '3', true
	case .Four, .KP_4: return '4', true
	case .Five, .KP_5: return '5', true
	case .Six, .KP_6: return '6', true
	case .Seven, .KP_7: return '7', true
	case .Eight, .KP_8: return '8', true
	case .Nine, .KP_9: return '9', true
	case .Space: return ' ', true
	case .Minus, .KP_Subtract: return '-', true
	case .Equal: return '=', true
	case .LeftBracket: return '[', true
	case .RightBracket: return ']', true
	case .Backslash: return '\\', true
	case .Semicolon: return ';', true
	case .Apostrophe: return '\'', true
	case .Comma: return ',', true
	case .Period, .KP_Decimal: return '.', true
	case .Slash, .KP_Divide: return '/', true
	case .Backtick: return '`', true
	}
	return 0, false
}

shifted_char :: proc(c: rune) -> rune {
	if !k2.key_is_held(.Left_Shift) && !k2.key_is_held(.Right_Shift) {
		return c
	}
	if c >= 'a' && c <= 'z' {
		return c - ('a' - 'A')
	}
	switch c {
	case '0': return ')'
	case '1': return '!'
	case '2': return '@'
	case '3': return '#'
	case '4': return '$'
	case '5': return '%'
	case '6': return '^'
	case '7': return '&'
	case '8': return '*'
	case '9': return '('
	case '-': return '_'
	case '=': return '+'
	case '[': return '{'
	case ']': return '}'
	case '\\': return '|'
	case ';': return ':'
	case '\'': return '"'
	case ',': return '<'
	case '.': return '>'
	case '/': return '?'
	case '`': return '~'
	}
	return c
}
