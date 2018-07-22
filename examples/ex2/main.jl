#!/usr/bin/env julia

using Gtk
using Cairo
using GtkBuilderAid

# Test using canvas features of DrawingArea
mutable struct CanvasData
  surface::CairoSurface
end

# Clear the surface to white
function clear_surface(surf::CairoSurface)
  ctx = CairoContext(surf)
  set_source_rgb(ctx, 1, 1, 1)
  paint(ctx)
end

function draw_brush(
    canvas,
    x,
    y,
    surf)
  px = Int(round(x - 3))
  py = Int(round(y - 3))
  ctx = CairoContext(surf)
  rectangle(ctx, px, py, 6, 6)
  fill(ctx)
  reveal_area(canvas, px, py, 6, 6)
end

ft = @GtkFunctionTable begin

@guarded Cint(0) function configure_event_cb(
    canvas,
    configure_event,
    qsdata)
  userdata = qsdata.userdata
  userdata.surface = create_similar_surface(canvas, Gtk.GEnum(Cairo.CONTENT_COLOR_ALPHA))
  clear_surface(userdata.surface)
  return Cint(1)
end

@guarded Cint(1) function draw_cb(
    canvas,
    ctx_ptr,
    qsdata)
  userdata = qsdata.userdata

  ctx = CairoContext(ctx_ptr)

  set_source_surface(ctx, userdata.surface, 0, 0)
  paint(ctx)
  return Cint(0)
end

@guarded Cint(0) function button_press_event_cb(
    canvas,
    event_ptr,
    qsdata) 
  userdata = qsdata.userdata

  event = Gtk.GdkEvent(event_ptr)

  # Make sure the surface is valid
  if userdata.surface.ptr == C_NULL
    return Cint(0)
  end

  if event.button == 1
    draw_brush(canvas, event.x, event.y, userdata.surface)
  elseif event.button == 3
    clear_surface(userdata.surface)
    reveal(GObject(canvas)::Gtk.GtkWidget, false)
  end

  return Cint(1)
end

@guarded Cint(0) function motion_notify_event_cb(
    canvas,
    event_ptr,
    qsdata)
  userdata = qsdata.userdata

  event = Gtk.GdkEvent(event_ptr)

  # Make sure the surface is valid
  if userdata.surface.ptr == C_NULL
    return Cint(0)
  end

  if (event.state & Gtk.GdkModifierType.BUTTON1) != 0
    draw_brush(canvas, event.x, event.y, userdata.surface)
  end

  return Cint(1)

end

end

start_application(ft, "io.github.matt5sean3.GtkBuilderAid.second", "drawing_window", "resources/main.ui", CanvasData(CairoSurface(C_NULL, -1, -1)))

