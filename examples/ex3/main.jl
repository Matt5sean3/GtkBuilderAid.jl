#!/usr/bin/env julia

# An example for using Gadfly within GTK

using Gtk
using Cairo
using Compose
using Gadfly
using GtkBuilderAid

mutable struct PlotData
  surface::CairoSurface
  plot
end

function draw_backbuffer(area, udata)
  udata.surface = create_similar_surface(area, Gtk.GEnum(Cairo.CONTENT_COLOR_ALPHA))
  Gadfly.draw(
    Compose.CAIROSURFACE(udata.surface, CairoContext(udata.surface)),
    udata.plot)
end

ft = @GtkFunctionTable begin

  @guarded Cint(1) function plot_area_draw_cb(area, ctx_ptr, qsdata)
    udata = qsdata.userdata
    ctx = CairoContext(ctx_ptr)
    set_source_surface(ctx, udata.surface)
    paint(ctx)
    Cint(0)
  end

  @guarded Cint(0) function plot_area_configure_event_cb(
      area,
      configure_event,
      qsdata)
    # redraw the plot
    draw_backbuffer(area, qsdata.userdata)
    Cint(1)
  end

  @guarded function plot_area_realize_cb(
      area,
      qsdata)
    draw_backbuffer(area, qsdata.userdata)
    nothing
  end

end

start_application(
    ft,
    "io.github.matt5sean3.GtkBuilderAid.third",
    "main_window",
    "resources/main.ui",
    PlotData(
        CairoSurface(C_NULL, -1, -1),
        plot(x=collect(1:10), y=rand(10), Geom.LineGeometry)))

