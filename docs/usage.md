# Exigent Usage Guide

Exigent is an immediate-mode UI package. Build the complete UI every frame
between `begin` and `end`.

This guide uses `ui` as the package alias:

```odin
import ui "exigent:exigent"
```

The Raylib demo is a complete adapter example: `demos/raylib/demo.odin`.

## Setup and Frame Lifecycle

Create one `Context`, select a theme, and register a text-width callback from
your renderer. The callback is required for labels and text clipping.

```odin
ctx: ui.Context
theme := ui.theme_dark(font)
ui.init(&ctx, theme)
defer ui.destroy(&ctx)

ui.text_measure_init(&ctx, nil, measure_text)
```

Feed platform input before building the frame. Each frame has this shape:

```odin
feed_input(&ctx) // Calls ui.input_feed_external, or an adapter equivalent.

ui.begin(&ctx, screen_width, screen_height)

ui.layer_begin(&ctx, ui.layout_fixed(f32(screen_width), f32(screen_height)))
// Create this layer's child widgets here.
ui.layer_end(&ctx)

ui.end(&ctx)
```

`end` requires every `layer_begin`, `container_begin`, `panel_begin`, and
`scrollbox_begin` to have its matching end call. Declare widgets every frame,
including a focused `text_input`.

## Themes and Colors

`theme_dark(font)` and `theme_light(font)` provide complete starting themes.

For a custom theme, start with one of them and override as desired.

```odin
theme_studio :: proc(font: rawptr) -> ui.Theme {
    theme := ui.theme_dark(font)

    theme.color.bg = ui.rgb(0x15181d)
    theme.color.surface = ui.rgb(0x20242b)
    theme.color.elevated = ui.rgb(0x292f38)
    theme.color.border = ui.rgb(0x414956)
    theme.color.fg = ui.rgb(0xf2f4f7)
    theme.color.fg_muted = ui.rgb(0xaeb7c4)
    theme.color.primary = ui.rgb(0x00a6a6)
    theme.color.on_primary = ui.rgb(0x071313)
    theme.color.selection = ui.rgba(0x00a6a64d)
    theme.color.success = ui.rgb(0x3fb950)
    theme.color.warning = ui.rgb(0xd29922)
    theme.color.danger = ui.rgb(0xf85149)

    theme.spacing.md = 14
    theme.spacing.lg = 20
    theme.font.size_md = 15
    theme.font.size_lg = 20
    theme.font.size_xl = 28
    theme.font.line_scale = 1.2

    return theme
}

theme := theme_studio(font)
ui.theme_set(&ctx, theme)
```

Use color tokens by purpose rather than assigning raw colors throughout widget
code:

- `bg`, `surface`, `elevated`, and `border` define backgrounds and boundaries.
- `fg` and `fg_muted` define normal and secondary text.
- `primary`, `on_primary`, and `selection` define the primary action color,
  text on that color, and selection highlight.
- `success`, `warning`, and `danger` define status and destructive-action
  colors.

The spacing scale is `xs`, `sm`, `md`, `lg`, and `xl`. The font settings
include the renderer font handle, `spacing`, `line_scale`, and sizes from
`size_xs` through `size_display`. Keep the font handle compatible with the
text-measurement function registered by `text_measure_init`.

For an accent-only variation, use `theme_with_primary`. It updates `primary`,
chooses a contrasting `on_primary` color, and derives `selection` from the same
accent:

```odin
theme := ui.theme_with_primary(ui.theme_dark(font), ui.rgb(0x2ea043))
ui.theme_set(&ctx, theme)
```

Use `rgb(0xRRGGBB)` and `rgba(0xRRGGBBAA)` for colors. `color_blend`,
`color_darken`, `color_lighten`, and `color_contrast` help derive related
colors for custom widget states.

## Layers

`layer_begin` creates a top-level UI layer. Layers cannot be nested. Later
layers appear above earlier layers and receive pointer input first.

```odin
ui.layer_begin(
    &ctx,
    ui.layout_fixed(f32(screen_width), f32(screen_height)),
    ui.Layer_Options{
        capture_pointer_empty = true,
        capture_keyboard = true,
    },
)
// Create this layer's child widgets here.
ui.layer_end(&ctx)
```

`capture_pointer_empty` makes otherwise empty layer space block pointer input to
lower layers. `capture_keyboard` makes the layer own keyboard input and clears
text-input focus in lower layers; use it for modal overlays.

## Layout

Supply a `Layout` when creating a layer, container, or leaf widget. For
containers, it controls child flow, alignment, padding, and gaps. For leaf
widgets such as buttons and images, it primarily defines their size.

```odin
ui.layout_auto(
    .Column,           // .Column or .Row
    .Start,            // main-axis alignment: .Start, .Center, .End
    .Center,           // cross-axis alignment: .Start, .Center, .End
    padding = ui.Inset{top = 16, right = 16, bottom = 16, left = 16},
    gap = 8,
)

ui.layout_fixed(240, 120, .Row, .Center, .Center)
```

`layout_auto` sizes a container to its in-flow children plus padding. A
`layout_fixed` container has the supplied outer width and height; `main_align`
positions its children along the layout direction and `cross_align` positions
them on the other axis. Fixed leaves and intrinsic labels determine the size of
an automatic parent.

`padding` reserves space inside the container. `gap` applies only between
in-flow children. Layout leaves room for configured borders.

## Containers

`container_begin` is an unstyled layout node. `panel_begin` is a container that
also draws the theme surface color and a one-pixel square theme border.

```odin
ui.container_begin(&ctx, ui.layout_auto(.Row, .Start, .Center, gap = 8))
// Create this container's child widgets here.
ui.container_end(&ctx)

ui.panel_begin(&ctx, ui.layout_auto(.Column, padding = ui.Inset{top = 16, right = 16, bottom = 16, left = 16}))
// Create this panel's child widgets here.
ui.panel_end(&ctx)
```

### Anchored Containers

Normal children use `.Flow`. An anchored child is positioned relative to its
parent and does not take up normal layout space, so it does not move other
children.

```odin
ui.panel_begin(
    &ctx,
    ui.layout_auto(.Column, .Start, .Center, gap = 8),
    ui.Container_Options{
        positioning = .Anchored,
        anchor = .Bottom_Center,
        offset = {0, -24},
    },
)
// Create this anchored panel's child widgets here.
ui.panel_end(&ctx)
```

`anchor` names the parent point. By default, the same point on the child is its
`pivot`, so `.Bottom_Center` keeps the panel's bottom center at the parent's
bottom center. Set `pivot` explicitly when a different child point should meet
the anchor. `offset` is measured in pixels after anchoring.

For a fixed empty region inside a layout, use `spacer`. In a column its height
creates vertical space; in a row its width creates horizontal space. Pass `0`
for the other dimension when it should not affect the container size.

```odin
ui.button(&ctx, ui.layout_fixed(200, 42), "Continue")
ui.spacer(&ctx, 0, 160) // Bottom space when this is last in a bottom-anchored column.
```

Use an anchored container's `offset` for an outer screen-edge margin, and a
spacer or padding for space that belongs inside the container.

Use `sub_id` when the same call site creates multiple widgets, such as a loop.
It keeps each repeated widget's interaction state separate.

```odin
for i in 0 ..< 4 {
    _ = ui.button(&ctx, ui.layout_fixed(44, 44), "", sub_id = i)
}
```

## Built-in Widgets

### Button

`button` draws its background, border, and centered text.

The `Layout` defines the button rectangle and `txt` supplies its
centered label. Optional arguments customize its presentation:

- `background_image` draws a `Sprite` instead of the solid button background.
- `bg_color` overrides the theme primary color for a solid button.
- `text_color` overrides the theme `on_primary` color.
- `disabled = true` disables pointer interaction and applies muted styling.

It returns a `Widget_Interaction`.

```odin
interaction := ui.button(&ctx, ui.layout_fixed(160, 40), "Save")
if interaction.released {
    save()
}
```

- `disabled` is true when the button was created with `disabled = true`.
- `hovered` is true while the pointer is over the button.
- `down` is true while the left mouse button is held over the button.
- `pressed` is true only on the mouse-press frame.
- `released` is true only when the mouse button is released over the button.

### Labels

`label` measures itself from its single-line text and style. Choose a role with
`role`; the built-in roles are `.Body`, `.Muted`, `.Caption`, `.Section`,
`.Title`, and `.Display`.

```odin
ui.label(&ctx, "Project settings", .Center, .Top, role = .Title)
```

Use `label_sized` when the label must occupy a specific layout rectangle:

```odin
ui.label_sized(
    &ctx,
    ui.layout_fixed(220, 28),
    "A fixed-width label",
    .Right,
    .Center,
    role = .Muted,
)
```

Text is single line. It is shortened with an ellipsis when the available width
is too narrow.

### Text Input

Text input state is persistent application state. Back it with a byte buffer
that remains alive for as long as the input does.

```odin
name_storage: [64]u8
name_input := ui.Text_Input{
    text = ui.text_buffer_create(name_storage[:]),
}

// In every UI frame:
_ = ui.text_input(&ctx, ui.layout_fixed(260, 38), &name_input)
```

Clicking focuses the input. The focused input accepts typed characters;
Backspace removes the last character, Enter ends focus, and Escape clears the
buffer and ends focus. Input stops when its `Text_Buffer` is full.

### Image

`image` creates a widget and scales a `Sprite` to its layout rectangle.

```odin
ui.image(&ctx, ui.layout_fixed(96, 96), avatar_sprite)
```

Load or register sprites through the renderer adapter.

### Spacer

`spacer` reserves fixed layout space and draws nothing.

```odin
ui.spacer(&ctx, 24, 0)  // Horizontal gap in a row.
ui.spacer(&ctx, 0, 24)  // Vertical gap in a column.
```

Prefer a container's `gap` for uniform spacing between every child. Use a
spacer for one-off or edge space.

### Scrollbox

A scrollbox is a vertically scrolling container. Keep its `Scrollbox` state
between frames.

```odin
items_scroll: ui.Scrollbox

ui.scrollbox_begin(&ctx, ui.layout_fixed(280, 180), &items_scroll)
// Create scrollable child widgets here.
for item in items {
    ui.label(&ctx, item)
}
ui.scrollbox_end(&ctx)
```

It scrolls when the pointer is over its rectangle. Content outside its bounds is
hidden and a scrollbar appears automatically. Set `scroll_step_px` on the
persistent `Scrollbox` to override the default 20-pixel step.

## Custom Widgets

Build a custom widget by opening a `container`, drawing into that current
container with the helpers below, optionally creating child widgets, and then
calling `container_end`.

For example, this procedure composes a reusable status badge without needing a
built-in badge widget:

```odin
status_badge :: proc(c: ^ui.Context, txt: string, color: ui.Color) {
    ui.container_begin(c, ui.layout_fixed(120, 28))
    // Draw the custom widget and create any child widgets here.
    ui.background(c, color)
    ui.border(c, ui.Border_Style{type = .Square, thickness = 1, color = ui.color_contrast(color)})
    ui.text(c, txt, .Center, .Center, ui.text_style(c, .Caption, ui.color_contrast(color)))
    ui.container_end(c)
}
```

`panel_begin` is useful when the default surface background and border are a
good starting point. Use `container_begin` when the custom widget owns its
appearance.

### Background and Border

Use `background` to fill the custom widget. Use `border` to configure the
border around that fill. Call both when the widget needs a visible background
and border.

```odin
ui.container_begin(&ctx, ui.layout_fixed(240, 72))
// Draw and create child widgets within this container.
ui.background(&ctx, ctx.theme.color.elevated)
ui.border(&ctx, ui.Border_Style{
    type = .Square,
    thickness = 2,
    color = ctx.theme.color.primary,
})
ui.container_end(&ctx)
```

Layout leaves room for configured borders. The currently supported border types
are `.None` and `.Square`.

Use `style_get` and `style_set` when a custom widget needs to adjust its
background, border, or scrollbar settings as a group. Use `background` when
the widget also needs a full-area fill.

```odin
style := ui.style_get(&ctx)
style.border.thickness = 2
style.border.color = ctx.theme.color.warning
ui.style_set(&ctx, style)
```

### Scrollbar Style

For a custom scrollbox, call `scrollbar` inside the scrollbox scope to set the
scrollbar width and opacity.

```odin
ui.scrollbox_begin(&ctx, ui.layout_fixed(280, 180), &items_scroll)
// Create scrollable child widgets and configure this scrollbox here.
ui.scrollbar(&ctx, 12, 220)
ui.scrollbox_end(&ctx)
```

### Drawing Primitives

Use `rect`, `line_h`, and `line_v` for custom decorative and structural
elements. `rect` draws relative to the custom widget's bounds. An empty
`Rect{}` fills that widget. A nonempty `Rect` uses local `x` and `y`
coordinates. Its optional border applies only to that rectangle.

```odin
ui.rect(&ctx, ui.Rect{x = 8, y = 8, w = 40, h = 24}, ctx.theme.color.success)
ui.rect(&ctx, ui.Rect{}, ctx.theme.color.surface)
ui.line_h(&ctx, 8, 232, 36, 1, ctx.theme.color.border)
ui.line_v(&ctx, 8, 64, 120, 1, ctx.theme.color.border)
```

`line_h` and `line_v` use coordinates relative to the custom widget. The line
thickness is centered on the supplied `y` or `x`.

### Text

Use `text` for custom labels. It has two overloads: the aligned form positions
one line inside the full widget rect, and the offset form positions it from the
widget's top-left.

```odin
style := ui.text_style(&ctx, .Section, ctx.theme.color.warning)
ui.text(&ctx, "Centered", .Center, .Center, style)
ui.text(&ctx, "Inset text", {12, 8}, style)
```

Omit `style` to use the current body text style. Both forms accept only one
line; embedded newlines assert.

### Sprites

Use `sprite` for custom icons and images. It draws relative to the custom
widget. An empty destination fills the widget; otherwise the destination is a
local rectangle.

```odin
ui.sprite(&ctx, avatar_sprite, ui.Rect{})
ui.sprite(&ctx, badge_sprite, ui.Rect{x = 8, y = 8, w = 20, h = 20})
```

### Current Interaction

`is_hovered` and `is_active` inspect the custom container while it is being
declared. Use them to choose custom visual states. For ordinary buttons, prefer
the returned `Widget_Interaction`.

```odin
if ui.is_hovered(&ctx) {
    ui.background(&ctx, ui.color_lighten(ctx.theme.color.surface, 0.08))
}
```

## Cookbook

These recipes assume they run inside a `begin`/`end` frame after input has been
fed. Each recipe builds its own layer, so declare it in the order it should
appear: later layers render and receive pointer input above earlier ones.

### Game HUD: Top Resources and Bottom-Center Hotbar

Use one full-screen HUD layer and make each visible group an anchored child.
The negative bottom offset is an outer screen-edge margin; the hotbar itself
does not need a spacer.

```odin
game_hud :: proc(c: ^ui.Context, width, height: int) {
    th := c.theme

    ui.layer_begin(c, ui.layout_fixed(f32(width), f32(height)))
    // Create HUD panels within this layer.

    ui.panel_begin(
        c,
        ui.layout_auto(
            .Row,
            .Center,
            .Center,
            padding = ui.Inset{top = th.spacing.sm, right = th.spacing.lg, bottom = th.spacing.sm, left = th.spacing.lg},
            gap = th.spacing.lg,
        ),
        ui.Container_Options{positioning = .Anchored, anchor = .Top_Center, offset = {0, 12}},
    )
    // Create resource widgets within the top panel.
    ui.label(c, "Wood 128", role = .Body)
    ui.label(c, "Stone 72", role = .Body)
    ui.label(c, "Gold 38", role = .Body)
    ui.panel_end(c)

    ui.panel_begin(
        c,
        ui.layout_auto(
            .Row,
            .Center,
            .Center,
            padding = ui.Inset{top = th.spacing.md, right = th.spacing.lg, bottom = th.spacing.md, left = th.spacing.lg},
            gap = th.spacing.sm,
        ),
        ui.Container_Options{positioning = .Anchored, anchor = .Bottom_Center, offset = {0, -18}},
    )
    // Create hotbar slot widgets within the bottom panel.
    for slot in 0 ..< 8 {
        _ = ui.button(c, ui.layout_fixed(52, 52), "", sub_id = slot)
    }
    ui.panel_end(c)

    ui.layer_end(c)
}
```

To reserve a large bottom area *inside* a bottom-anchored HUD panel, place
`ui.spacer(c, 0, bottom_space)` after its visible column children instead.

### Dropdown Menu

Anchors are relative to the immediate parent. Put a button and its dropdown in
a fixed-size holder, then anchor the dropdown's top-left to the holder's
bottom-left.

```odin
ui.container_begin(
    &ctx,
    ui.layout_fixed(160, 40),
    ui.Container_Options{positioning = .Anchored, anchor = .Top_Left, offset = {16, 16}},
)
// Create the button and optional dropdown within this holder.

if ui.button(&ctx, ui.layout_fixed(160, 40), "Actions").released {
    menu_open = !menu_open // Persistent application state.
}
if menu_open {
    ui.panel_begin(
        &ctx,
        ui.layout_auto(
            .Column,
            .Start,
            .Start,
            padding = ui.Inset{top = 8, right = 8, bottom = 8, left = 8},
            gap = 4,
        ),
        ui.Container_Options{
            positioning = .Anchored,
            anchor = .Bottom_Left,
            pivot = .Top_Left,
            offset = {0, 6},
        },
    )
    // Create menu item widgets within the dropdown.
    _ = ui.button(&ctx, ui.layout_fixed(160, 32), "Rename", sub_id = 1)
    _ = ui.button(&ctx, ui.layout_fixed(160, 32), "Duplicate", sub_id = 2)
    _ = ui.button(&ctx, ui.layout_fixed(160, 32), "Delete", sub_id = 3)
    ui.panel_end(&ctx)
}

ui.container_end(&ctx)
```

`menu_open` is persistent application state. The example's container establishes
the local coordinate system that relates the button and dropdown rectangles.

### Centered Overlay Window

Place a fixed-size panel on its own layer. Do not set `capture_pointer_empty`
when gameplay should remain clickable outside the window.

```odin
ui.layer_begin(&ctx, ui.layout_fixed(f32(width), f32(height)))
// Create the floating window within this layer.

ui.panel_begin(
    &ctx,
    ui.layout_fixed(
        460,
        360,
        .Column,
        .Start,
        .Start,
        padding = ui.Inset{top = 20, right = 20, bottom = 20, left = 20},
        gap = 12,
    ),
    ui.Container_Options{positioning = .Anchored, anchor = .Center},
)
// Create window child widgets here.
ui.label(&ctx, "Character", role = .Title)
ui.label(&ctx, "Level 12 Ranger", role = .Section)
ui.label(&ctx, "Talent points available: 3", role = .Body)
_ = ui.button(&ctx, ui.layout_fixed(180, 40), "Spend talent")
ui.panel_end(&ctx)
ui.layer_end(&ctx)
```

For a modal character screen, use the same panel in a layer with
`capture_pointer_empty = true` and `capture_keyboard = true`; add a translucent
`background` to that layer before declaring the panel.

### Tooltip Above a Hover Target

A holder gives both the target and its tooltip a shared local coordinate system.
The tooltip uses a bottom-center pivot so it appears above the target.

```odin
ui.container_begin(
    &ctx,
    ui.layout_fixed(44, 44),
    ui.Container_Options{positioning = .Anchored, anchor = .Bottom_Right, offset = {-16, -16}},
)
// Create the hover target and optional tooltip within this holder.

hovered := ui.button(&ctx, ui.layout_fixed(44, 44), "?").hovered
if hovered {
    ui.panel_begin(
        &ctx,
        ui.layout_auto(
            .Column,
            padding = ui.Inset{top = 6, right = 8, bottom = 6, left = 8},
        ),
        ui.Container_Options{
            positioning = .Anchored,
            anchor = .Top_Center,
            pivot = .Bottom_Center,
            offset = {0, -8},
        },
    )
    // Create tooltip child widgets here.
    ui.label(&ctx, "Open the codex", role = .Caption)
    ui.panel_end(&ctx)
}

ui.container_end(&ctx)
```

Place a general overlay tooltip on a later layer with the default
`capture_pointer_empty = false` so its empty screen area passes input through.
The tooltip panel captures pointer input within its bounds, so place it away
from its trigger.

### Modal Confirmation Overlay

A modal layer captures empty space and keyboard input. Draw its dimming
background on the layer root, then anchor the dialog panel in the center.

```odin
ui.layer_begin(
    &ctx,
    ui.layout_fixed(f32(width), f32(height)),
    ui.Layer_Options{capture_pointer_empty = true, capture_keyboard = true},
)
// Draw the overlay and create the modal dialog within this layer.

ui.background(&ctx, ui.rgba(0x00000088))

ui.panel_begin(
    &ctx,
    ui.layout_auto(
        .Column,
        .Start,
        .Center,
        padding = ui.Inset{top = 20, right = 20, bottom = 20, left = 20},
        gap = 12,
    ),
    ui.Container_Options{positioning = .Anchored, anchor = .Center},
)
// Create dialog child widgets here.
ui.label(&ctx, "Delete this save?", role = .Title)
ui.label(&ctx, "This action cannot be undone.", role = .Muted)

ui.container_begin(&ctx, ui.layout_auto(.Row, .Center, .Center, gap = 8))
// Create dialog action widgets within this container.
_ = ui.button(&ctx, ui.layout_fixed(100, 36), "Cancel")
_ = ui.button(&ctx, ui.layout_fixed(100, 36), "Delete", bg_color = ctx.theme.color.danger)
ui.container_end(&ctx)
ui.panel_end(&ctx)
ui.layer_end(&ctx)
```

## Custom Renderer Integration

Use one of the renderer adapters for Raylib or Karl2D in most applications. To
write a custom renderer, call `cmd_iterator_create` after `end` and read each
item with `cmd_iterator_next`. Handle the rectangle, text, sprite, and clipping
command types that your renderer supports.
