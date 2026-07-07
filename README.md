# exigent - Odin Immediate Mode UI (WIP/Experimental)

This is a simple immediate mode UI written in Odin as an exploratory exercise in recreational programming. 

For layout this package uses a small Clay-inspired tree layout. Widgets are
declared as a tree, fixed-size leaves and intrinsic-size labels are measured,
parents compute their size from their children, and then children are positioned
with a parent `direction`, `main_align`, `cross_align`, `padding`, and `gap`.
Layout reserves space for widget borders so they are not clipped by parents.
Rendering commands are emitted after layout has resolved widget rectangles.

```odin
theme := ui.theme_light(font)
ui.init(ctx, theme = theme)
ui.text_measure_init(ctx, nil, measure_width)

ui.begin(ctx, width, height, ui.layout_fixed(width, height, .Column, .Center, .Center))
defer ui.end(ctx)

th := ctx.theme
ui.panel_begin(
	ctx,
	ui.layout_auto(
		.Column,
		.Start,
		.Center,
		padding = ui.Inset{top = th.spacing.xl, right = th.spacing.xl, bottom = th.spacing.xl, left = th.spacing.xl},
		gap = th.spacing.xl,
	),
)
defer ui.panel_end(ctx)

ui.label(ctx, "Layout showcase", role = .Title)
ui.button(ctx, ui.layout_fixed(170, 42), "Click me!")
```

Rendering uses a Command queue design where widgets are iterated starting from the root following a Breadth-First Search (BFS) pattern. For each widget, one or more Commands to draw are pushed into the queue. The queue can then be iterated and drawn by any graphical engine. Currently the `demo` uses Raylib. 

The name `exigent` means "requiring immediate action".

## Sample

![UI Sample](docs/ui-sample_2026-01-15_2238.png)

This sample contains all the available widgets so far.

## Karl2D adapter

This repo includes an optional `karl2d_exigent` package that renders Exigent
commands through [Karl2D](https://github.com/karl-zylinski/karl2d). Core
Exigent does not import Karl2D; only the adapter and `demos/karl2d` do.

For local development, Karl2D is checked out as a git submodule under `lib/`:

```sh
git submodule update --init --recursive
```

The adapter uses collection imports so downstream projects can point `karl2d`
at their own submodule and avoid duplicate Karl2D package identities:

```odin
import ui "exigent:."
import k2 "karl2d:."
import kx "karl2d_exigent:."
```

Run the Karl2D demo from the repo root:

```sh
./demos/karl2d/run.sh
```

For a downstream project, use the same collection names but point them at that
project's checkouts:

```sh
odin run . \
	-collection:exigent=/path/to/exigent \
	-collection:karl2d=/path/to/project/lib/karl2d \
	-collection:karl2d_exigent=/path/to/exigent/karl2d_exigent
```

Karl2D currently exposes key and mouse events, but not dedicated text-input
character events. The adapter feeds key/mouse events directly and synthesizes
basic ASCII character events from key presses for Exigent text inputs.

## Raylib adapter

This repo also includes an optional `raylib_exigent` package that renders
Exigent commands through `vendor:raylib`, translates Raylib input into Exigent
events, measures text through Raylib fonts, and maps Raylib textures to Exigent
sprite handles.

Run the Raylib demo from the repo root:

```sh
./demos/raylib/run.sh
```

For a downstream Raylib project:

```sh
odin run . \
	-collection:exigent=/path/to/exigent \
	-collection:raylib_exigent=/path/to/exigent/raylib_exigent
```

The adapter owns textures loaded through its `load_sprite_*` helpers when
`destroy(renderer, true)` is used. Textures registered from a game-owned asset
cache can use `destroy(renderer, false)` so the game keeps lifetime ownership.
