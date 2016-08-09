#!/usr/bin/env julia

# An example for using Gadfly within GTK

using Gtk
using Cairo
using Compose
using Gadfly
using GtkBuilderAid

type PlotData
  surface::CairoSurface
  plot
end

function draw_backbuffer(area, udata)
  udata.surface = create_similar_surface(area, Gtk.GEnum(Cairo.CONTENT_COLOR_ALPHA))
  Gadfly.draw(
    Compose.CAIROSURFACE(udata.surface, CairoContext(udata.surface)),
    udata.plot)
end

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

app = @GtkApplication("io.github.matt5sean3.GtkBuilderAid.fourth", 0)
signal_connect(activate_cb, app, :activate, Void, (), false, ())

println("Starting Application")
run(app)

