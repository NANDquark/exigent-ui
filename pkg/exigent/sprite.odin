package exigent

import "core:image"
import "core:math"
import "core:mem"

/*

# Example usage

// 1. Initialization
packer: Sprite_Packer
sprite_packer_init(&packer)
defer sprite_packer_destroy(&packer)

// 2. Packing
sprite_a := sprite_packer_add(&packer, img_a)
sprite_b := sprite_packer_add(&packer, img_b)

// 3. GPU Upload
texture_mapping := make(map[Atlas_Handle]GPU_Texture_Handle)
it := sprite_packer_make_iter(&packer)
for {
	tex, ok := sprite_packer_iter_next(&it)
	if !ok do break
	gpu_tex_id := upload_to_gpu(tex.handle, tex.texture)
	texture_mapping[tex.handle] = gpu_tex_id
}

// 4. Start the main loop and use the sprites as args to image functions

*/

Sprite :: struct {
	atlas:         Atlas_Handle,
	uv_min:        [2]f32, // normalized to (0,1) inclusive across the whole texture
	uv_max:        [2]f32, // normalized to (0,1) inclusive across the whole texture
	width, height: int, // size of the original image in pixels
}

// Used on program init to build one or more packed texture atlases which
// can then be uploaded to the GPU. When completed, all textures are destroyed
// and unloaded to save memory.
Sprite_Packer :: struct {
	next_handle: int,
	entries:     [dynamic]Sprite_Packer_Entry,
	atlas_size:  int,
	min_padding: int,
	allocator:   mem.Allocator,
}

Sprite_Packer_Entry :: struct {
	handle: Atlas_Handle,
	atlas:  Atlas,
}

sprite_packer_init :: proc(
	sp: ^Sprite_Packer,
	atlas_size := 4096,
	min_padding := 1,
	allocator := context.allocator,
) {
	sp.entries.allocator = allocator
	sp.allocator = allocator
	sp.atlas_size = atlas_size
	sp.min_padding = min_padding
}

sprite_packer_destroy :: proc(sp: ^Sprite_Packer) {
	for &e in sp.entries {
		atlas_destroy(&e.atlas)
	}
	delete(sp.entries)
}

// Copy the pixels from the image into the texture atlas(es). Depending on the
// number of images and the size of the images this will produce one or more
// atlas (spritesheet) textures of combined images. The provided image can be
// destroyed/freed afterwards.
sprite_packer_add :: proc(sp: ^Sprite_Packer, i: Image) -> Sprite {
	context.allocator = sp.allocator

	required_width := i.width + 2 * sp.min_padding
	required_height := i.height + 2 * sp.min_padding
	target_slot_size := math.next_power_of_two(max(required_width, required_height))
	target_atlas: ^Atlas

	// find an existing atlas of the target size
	for &e in sp.entries {
		if e.atlas.slot_size == target_slot_size && !atlas_is_full(e.atlas) {
			target_atlas = &e.atlas
		}
	}

	// create a new atlas of the target size when one doesn't exist yet
	if target_atlas == nil {
		handle := Atlas_Handle(sp.next_handle)
		sp.next_handle += 1
		append(
			&sp.entries,
			Sprite_Packer_Entry {
				handle = handle,
				atlas = atlas_create(handle, sp.atlas_size, target_slot_size),
			},
		)
		target_atlas = &sp.entries[len(sp.entries) - 1].atlas
	}

	i_origin := atlas_append(target_atlas, i, sp.min_padding)
	inv_w := 1.0 / f32(sp.atlas_size)
	inv_h := 1.0 / f32(sp.atlas_size)
	// Here 0.5 is added or subtracted to target the center of the outside pixel
	// of the new image to avoid texture bleeding or shimmering on the edges
	// This combined with the min_padding added around should solve the problem.
	uv_min := [2]f32{(f32(i_origin.x) + 0.5) * inv_w, (f32(i_origin.y) + 0.5) * inv_h}
	uv_max := [2]f32 {
		(f32(i_origin.x) + f32(i.width) - 0.5) * inv_w,
		(f32(i_origin.y) + f32(i.height) - 0.5) * inv_h,
	}

	return Sprite {
		atlas = target_atlas.handle,
		uv_min = uv_min,
		uv_max = uv_max,
		width = i.width,
		height = i.height,
	}
}

Sprite_Packer_Iterator :: struct {
	sp:       ^Sprite_Packer,
	next_idx: int,
}

sprite_packer_make_iter :: proc(sp: ^Sprite_Packer) -> Sprite_Packer_Iterator {
	return Sprite_Packer_Iterator{sp = sp, next_idx = 0}
}

// A single sprite atlas (spritesheet) of packed images. The Atlas_Handle must
// be tracked for future reference when Sprites are rendered.
Atlas_Texture :: struct {
	handle:  Atlas_Handle,
	texture: Image,
}

sprite_packer_iter_next :: proc(spi: ^Sprite_Packer_Iterator) -> (at: Atlas_Texture, ok: bool) {
	idx := spi.next_idx
	if idx >= len(spi.sp.entries) {
		return Atlas_Texture{}, false
	}

	spi.next_idx += 1
	entry := spi.sp.entries[idx]

	return Atlas_Texture{handle = entry.handle, texture = entry.atlas.texture}, true
}

// TODO: Implement a more efficient texture packing solution. This one creates
// one texture for each closest higher power-of-two sized images.

// Simple atlas (spritesheet) solution using fixed size slots per texture
Atlas :: struct {
	handle:      Atlas_Handle,
	texture:     Image,
	slot_size:   int, // width and height for the individual sub-sections (slots)
	slots:       []Sprite,
	free_slot:   int, // the next unused slot within the atlas
	min_padding: int, // minimum empty space around each sprite inside a slot
	allocator:   mem.Allocator,
}

Atlas_Handle :: distinct int

atlas_create :: proc(
	handle: Atlas_Handle,
	atlas_size: int,
	slot_size: int,
	min_padding := 1,
	allocator := context.allocator,
) -> Atlas {
	assert(
		atlas_size % slot_size == 0,
		"slot_size must evenly divide into atlas_size (use powers of 2)",
	)
	slots_per_row := atlas_size / slot_size
	num_rows := atlas_size / slot_size
	return Atlas {
		handle = handle,
		texture = image_create_empty(atlas_size, atlas_size, allocator),
		slot_size = slot_size,
		slots = make([]Sprite, slots_per_row * num_rows),
		free_slot = 0,
		min_padding = min_padding,
		allocator = allocator,
	}
}

atlas_destroy :: proc(a: ^Atlas) {
	image_destroy(a.texture)
	delete(a.slots, a.allocator)
}

// All slots in the atlas texture have sprites
atlas_is_full :: proc(a: Atlas) -> bool {
	return a.free_slot >= len(a.slots)
}

// Add the image to the atlas and get it's topleft x, y coordinate
atlas_append :: proc(a: ^Atlas, i: Image, min_padding: int) -> [2]int {
	width := i.width + 2 * min_padding
	height := i.height + 2 * min_padding

	next_slot := a.free_slot
	a.free_slot += 1

	slot_origin := atlas_slot_origin(a^, next_slot)
	overlay_origin := [2]int{slot_origin.x + min_padding, slot_origin.y + min_padding}

	image_overlay(&a.texture, i, overlay_origin)

	return overlay_origin
}

atlas_slot_origin :: proc(a: Atlas, slot: int) -> [2]int {
	assert(slot >= 0 && slot < len(a.slots), "invalid slot index")

	slots_width := a.texture.width / a.slot_size
	x := slot % slots_width
	y := slot / slots_width
	return [2]int{x * a.slot_size, y * a.slot_size}
}

Image :: struct {
	pixels:        [dynamic]Color,
	width, height: int,
}

image_create_empty :: proc(width, height: int, allocator := context.allocator) -> Image {
	return Image {
		pixels = make([dynamic]Color, width * height, allocator),
		width = width,
		height = height,
	}
}

image_convert_from_image :: proc(in_img: ^image.Image, allocator := context.allocator) -> Image {
	// Ensure the incoming image has the correct byte layout
	if in_img.channels < 4 {
		image.alpha_add_if_missing(in_img)
	}
	if in_img.depth != 8 {
		panic("only 8 bit images supported for now")
		// TODO convert
	}

	// Now copy those bytes into our Image struct
	img := image_create_empty(in_img.width, in_img.height, allocator)
	in_pixels := mem.slice_data_cast([]Color, in_img.pixels.buf[:])
	assert(len(img.pixels) == len(in_pixels), "unexpected image byte format")
	copy(img.pixels[:], in_pixels)

	return img
}

image_destroy :: proc(i: Image) {
	delete(i.pixels)
}

// Draw the top image on top of the base image, assuming the top image
// fits within the base image for simplicity.
image_overlay :: proc(base: ^Image, top: Image, pos: [2]int) {
	assert(
		pos.x >= 0 &&
		pos.y >= 0 &&
		pos.x + top.width <= base.width &&
		pos.y + top.height <= base.height,
		"top image must fit within base image",
	)

	for y in 0 ..< top.height {
		dest_start := (pos.y + y) * base.width + pos.x
		src_start := y * top.width
		// copy an entire row at once
		mem.copy(&base.pixels[dest_start], &top.pixels[src_start], top.width * size_of(Color))
	}
}
