# exigent - Odin Immediate Mode UI (WIP/Experimental)

This is a simple immediate mode UI written in Odin as an exploratory exercise in recreational programming. 

For layout this package uses a small Clay-inspired tree layout. Widgets are
declared as a tree, fixed-size leaves and intrinsic-size labels are measured,
parents compute their size from their children, and then children are positioned
with a parent `direction`, `main_align`, `cross_align`, `padding`, and `gap`.
Layout reserves space for widget borders so they are not clipped by parents.
Rendering commands are emitted after layout has resolved widget rectangles.

```odin
ui.begin(ctx, width, height, ui.layout_fixed(width, height, .Column, .Center, .Center))
defer ui.end(ctx)

ui.panel_begin(
	ctx,
	ui.layout_auto(
		.Column,
		.Start,
		.Center,
		padding = ui.Inset{top = 22, right = 28, bottom = 22, left = 28},
		gap = 22,
	),
)
defer ui.panel_end(ctx)

ui.label(ctx, "Layout showcase")
ui.button(ctx, ui.layout_fixed(170, 42), "Click me!")
```

Rendering uses a Command queue design where widgets are iterated starting from the root following a Breadth-First Search (BFS) pattern. For each widget, one or more Commands to draw are pushed into the queue. The queue can then be iterated and drawn by any graphical engine. Currently the `demo` uses Raylib. 

The name `exigent` means "requiring immediate action".

## Sample

![UI Sample](docs/ui-sample_2026-01-15_2238.png)

This sample contains all the available widgets so far.
