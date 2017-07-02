# Gadfly Plotting Example

Given Julia is a technical computing language this wrapper wouldn't be complete without describing some means to visualize data.

## Dependencies

```julia
using Gtk
using Cairo
using Compose
using Gadfly
using GtkBuilderAid
```

The [Gadfly](https://github.com/dcjones/Gadfly.jl) package provides advanced plotting functionality and is a fantastic tool overall and, importantly, operates atop the [Compose](https://github.com/dcjones/Compose.jl) package which includes a backend for the [Cairo](https://github.com/JuliaGraphics/Cairo.jl) package which integrates well with the [Gtk wrapper](https://github.com/JuliaGraphics/Gtk.jl) package. In fact, this example could be modified to work with any package built atop `Compose` such as [GraphLayout](https://github.com/IainNZ/GraphLayout.jl), [Hinton](https://github.com/ninjin/Hinton.jl), and other visualizations created directly in `Compose`. Given sufficient knowledge of the `Cairo`, this should also be adaptable to libraries that utilize `Cairo` directly too.

## Plotting Data Structure

```julia
type PlotData
  surface::CairoSurface
  plot
end
```

This data structure holds the required data for the drawing area callbacks. `surface` contains a CairoSurface object that contains the completed form of the plot while `plot` contains the Gadfly representation of the plot.

## Drawing the Plot

```julia
function draw_backbuffer(area, udata)
  udata.surface = create_similar_surface(area, Gtk.GEnum(Cairo.CONTENT_COLOR_ALPHA))
  Gadfly.draw(
    Compose.CAIROSURFACE(udata.surface, CairoContext(udata.surface)),
    udata.plot)
end
```

This function generates a fresh surface and renders the plot to it with `Gadfly.draw` after the surface has been wrapped by the Compose Cairo backend.

## Open the GtkBuilderAid macro

```julia
@GtkBuilderAid function_name(canvas_builder) begin

  @guarded Cint(1) function plot_area_draw_cb(area, ctx_ptr, udata)
    ctx = CairoContext(ctx_ptr)
    set_source_surface(ctx, udata.surface)
    paint(ctx)
    Cint(0)
  end

  @guarded Cint(0) function plot_area_configure_event_cb(
      area,
      configure_event,
      udata)
    # redraw the plot
    draw_backbuffer(area, udata)
    Cint(1)
  end

  @guarded function plot_area_realize_cb(
      area,
      udata)
    draw_backbuffer(area, udata)
    nothing
  end

end
```

This is the core of the GtkBuilderAid package and contains the callbacks necessary to render the plot to a drawing area.

### `plot_area_draw_cb`

The draw callback executes every time the widget is somehow obscured and subsequently revealed. This happens quite often so this must be kept as lean as possible. In this case, the pre-rendered form of the plot is just painted onto the canvas using the Cairo context provided by the `draw` callback.

### `plot_area_configure_event_cb`

The configure event callback executes whenever the widget is changed such as by resizing. Whenever the widget resizes the surface and rendered form of the plot need to be regenerated as the old rendered form will not fit correctly in the resized widget.

### `plot_area_realize_cb`

The realize event callback executes when the widget is first displayed. This will usually be the first time the plot is rendered.

## Creating the Application

```julia
@guarded function activate_cb(
    app_ptr,
    userdata)
  app = GObject(app_ptr)
  built = canvas_builder(
    "resources/main.ui", 
    PlotData(
      CairoSurface(C_NULL, -1, -1),
      plot(x=collect(1:10), y=rand(10), Geom.LineGeometry)))
  win = GAccessor.object(built, "main_window")
  push!(app, win) 
  showall(win)
  nothing
end
```

Outside of the wrapper, the application activate callback is defined to set everything into motion. The `canvas_builder` function defined by the macro is used with a newly created `PlotData` object to pass as userdata to the callbacks. The Gadfly plot is defined in this line and will just be a plot with a random value of `y` for each integer value of `x` from one to ten for our example. The application window is next added to the application to ensure the application closes when the window closes. Finally, `showall` is called on the application window to display everything.

## Running the Application

```julia
app = GtkApplication("io.github.matt5sean3.GtkBuilderAid.fourth", 0)
signal_connect(activate_cb, app, :activate, Void, (), false, ())

println("Starting Application")
run(app)
```

The application is created and connected with its activate callback. `println` is called to stifle a Heisenbug in the Gtk wrapper. `run` is called on the application to set everything in motion and block execution until the user closes the application.

## The Glade File

The glade file in this case is very minimalist. A `GtkApplicationWindow` with a `GtkDrawingArea` as its child is all that is necessary. On the `GtkDrawingArea` the `configure-event`, `draw`,  and `realize` signals are handled by `plot_area_configure_event_cb`, `plot_area_draw_cb`, and `plot_area_realize_cb` respectively.

