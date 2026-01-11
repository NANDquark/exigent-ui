package exigent

import "core:testing"

@(test)
test_image_overlay :: proc(t: ^testing.T) {
	Test_Case :: struct {
		desc:           string,
		base_w, base_h: int,
		top_w, top_h:   int,
		pos:            [2]int,
		base_color:     Color,
		top_color:      Color,
	}

	cases := []Test_Case {
		{
			desc = "overlay at origin",
			base_w = 4,
			base_h = 4,
			top_w = 2,
			top_h = 2,
			pos = {0, 0},
			base_color = Color{0, 0, 0, 255},
			top_color = Color{255, 255, 255, 255},
		},
		{
			desc = "overlay at offset",
			base_w = 4,
			base_h = 4,
			top_w = 2,
			top_h = 2,
			pos = {1, 1},
			base_color = Color{0, 0, 0, 255},
			top_color = Color{255, 0, 0, 255},
		},
		{
			desc = "overlay full size",
			base_w = 2,
			base_h = 2,
			top_w = 2,
			top_h = 2,
			pos = {0, 0},
			base_color = Color{0, 255, 0, 255},
			top_color = Color{0, 0, 255, 255},
		},
	}

	for c in cases {
		base := image_create_empty(c.base_w, c.base_h, context.allocator)
		defer image_destroy(base)
		for i in 0 ..< len(base.pixels) {
			base.pixels[i] = c.base_color
		}

		top := image_create_empty(c.top_w, c.top_h, context.allocator)
		defer image_destroy(top)
		for i in 0 ..< len(top.pixels) {
			top.pixels[i] = c.top_color
		}

		image_overlay(&base, top, c.pos)

		// Verify overlay
		for y in 0 ..< c.base_h {
			for x in 0 ..< c.base_w {
				idx := y * c.base_w + x
				is_inside_top :=
					x >= c.pos.x && x < c.pos.x + c.top_w && y >= c.pos.y && y < c.pos.y + c.top_h

				expected := is_inside_top ? c.top_color : c.base_color
				actual := base.pixels[idx]

				testing.expectf(
					t,
					actual == expected,
					"\n%s\nPixel at (%d, %d) mismatch.\nexpected: %v,\nactual: %v",
					c.desc,
					x,
					y,
					expected,
					actual,
				)
			}
		}
	}
}

@(test)
test_atlas_slot_origin :: proc(t: ^testing.T) {
	atlas := atlas_create(0, 128, 32, 0, context.allocator)
	defer atlas_destroy(&atlas)

	// 128 / 32 = 4 slots per row

	// Slot 0 (Top-left)
	testing.expect_value(t, atlas_slot_origin(atlas, 0), [2]int{0, 0})

	// Slot 3 (End of first row)
	testing.expect_value(t, atlas_slot_origin(atlas, 3), [2]int{96, 0})

	// Slot 4 (Start of second row)
	testing.expect_value(t, atlas_slot_origin(atlas, 4), [2]int{0, 32})

	// Slot 15 (Last slot: 4x4 grid)
	testing.expect_value(t, atlas_slot_origin(atlas, 15), [2]int{96, 96})
}

@(test)
test_atlas_append :: proc(t: ^testing.T) {
	atlas := atlas_create(0, 128, 64, 2, context.allocator)
	defer atlas_destroy(&atlas)

	img := image_create_empty(10, 10, context.allocator)
	defer image_destroy(img)

	// First append
	pos1 := atlas_append(&atlas, img, 2)
	// slot 0 is at (0,0), padding is 2
	testing.expect_value(t, pos1, [2]int{2, 2})
	testing.expect_value(t, atlas.free_slot, 1)

	// Second append
	pos2 := atlas_append(&atlas, img, 2)
	// slot 1 is at (64, 0), padding is 2
	testing.expect_value(t, pos2, [2]int{66, 2})
	testing.expect_value(t, atlas.free_slot, 2)
}

@(test)
test_atlas_builder_add :: proc(t: ^testing.T) {
	ab: Sprite_Packer
	sprite_packer_init(&ab, 512, 1)
	defer sprite_packer_destroy(&ab)

	img := image_create_empty(30, 30, context.allocator)
	defer image_destroy(img)

	// 30 + 2*1 = 32. next_power_of_two(32) = 32.
	sprite := sprite_packer_add(&ab, img)

	testing.expect_value(t, sprite.width, 30)
	testing.expect_value(t, sprite.height, 30)

	// UV calculation check:
	// origin is (1, 1) because of padding
	// uv_min = (1 + 0.5) / 512 = 1.5 / 512
	// uv_max = (1 + 30 - 0.5) / 512 = 30.5 / 512
	inv := 1.0 / f32(512)
	expected_min := [2]f32{1.5 * inv, 1.5 * inv}
	expected_max := [2]f32{30.5 * inv, 30.5 * inv}

	testing.expect_value(t, sprite.uv_min, expected_min)
	testing.expect_value(t, sprite.uv_max, expected_max)

	// Test atlas reuse
	sprite2 := sprite_packer_add(&ab, img)
	testing.expect_value(t, sprite2.atlas, sprite.atlas)
	testing.expect_value(t, len(ab.entries), 1)

	// Test new atlas for different size
	img_large := image_create_empty(100, 100, context.allocator)
	defer image_destroy(img_large)
	// 100 + 2 = 102 -> 128 slot size
	sprite3 := sprite_packer_add(&ab, img_large)
	testing.expect(t, sprite3.atlas != sprite.atlas)
	testing.expect_value(t, len(ab.entries), 2)
}
