
function test_macro_throws(error_type, macroexpr)
  expansion = macroexpand(macroexpr)
  if expansion.head != :error
    warn("Expansion did not throw error")
    println(expansion)
    @test false
  end
  if !isa(expansion.args[1], error_type)
    warn("Expansion threw wrong error")
    warn("Expected: $error_type")
    warn("Got: $(expansion.args[1])")
    dump(expansion)
    @test false
  end
end

test_macro_throws(TypeError, quote 
@GtkBuilderAid helloSymbol
end)

test_macro_throws(ArgumentError, quote
@GtkBuilderAid helloExpr()
end)

test_macro_throws(ArgumentError, quote 
@GtkBuilderAid 
end)

test_macro_throws(ErrorException, quote
@GtkBuilderAid symbolDirective begin
end
end)

test_macro_throws(ErrorException, quote
@GtkBuilderAid badexpr::Directive begin
end
end)

test_app = @GtkApplication("com.github.test_gtkbuilderaid", 0)

# Check that an empty builder doesn't crash
@GtkBuilderAid function_name(empty_builder) begin

end
empty_builder("resources/nothing.ui", test_app)

# Check that a poorly made builder doesn't crash
@GtkBuilderAid function_name(poor_builder) begin

function click_ok()
end

function quit_app()
end

function close_window()
end

end
poor_builder("resources/nothing.ui", test_app)

# Try out known userdata with 
@GtkBuilderAid function_name(long_builder) begin

function click_ok(
    widget, 
    user_info)
  println("OK clicked!")
  return nothing
end

function quit_app(
    widget, 
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info)
  return nothing
end

function close_window(
    widget, 
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing
end

end

@test_throws MethodError long_builder()
long_builder("resources/nothing.ui", test_app)

# Show the expanded macro
# Mostly check that this succeeds
@GtkBuilderAid function_name(builder) userdata(test_app) "resources/nothing.ui" begin

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

function quit_app(
    widget,
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info)
  return nothing
end

function close_window(
    widget,
    window)
  destroy(window)
  return nothing
end

end

builder()
# Also check that the unbound form works
builder("$(Pkg.dir("GtkBuilderAid"))/test/resources/nothing.ui")

@GtkBuilderAid function_name(tuple_builder) userdata_tuple(test_app::GtkApplication) "resources/nothing.ui" begin

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

function quit_app(
    widget, 
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  return nothing
end

function close_window(
    widget,
    window)
  destroy(window)
  return nothing
end

end

# check again but with an explicit name for the builder function
@GtkBuilderAid function_name(build_nothing) userdata(test_app::GtkApplication) "resources/nothing.ui" begin

function close_window(
    widget,
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing
end

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

end
build_nothing()

# Test non-string file arguments
@GtkBuilderAid function_name(base_method_builder) begin

function close_window(
    widget,
    window)
  window = Gtk.GLib.GObject(window)
  destroy(window)
  return nothing
end

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

end

@test_throws MethodError base_method_builder()
# Should succeed
base_method_builder("resources/nothing.ui")

# Test non-existent files
test_macro_throws(ErrorException, quote
@GtkBuilderAid "resources/nonexistentfile.ui" begin
function close_window(
    widget,
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing
end

end
end)

expanding_builder = @GtkBuilderAid begin

@guarded function close_window(
    widget,
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing::Void
end

@guarded function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing::Void
end

end
expanding_builder("resources/nothing.ui")

# Test using canvas features of DrawingArea
type CanvasData
  surface::CairoSurface
end

# Based off of GTK's Custom Drawing source code
@GtkBuilderAid function_name(canvas_builder) begin

# Clear the surface to white
function clear_surface(cd::CanvasData)
  ctx = CairoContext(cd.surface)
  set_source_rgb(ctx, 1, 1, 1)
  paint(ctx)
  destroy(ctx)
end

@guarded Cint(0) function configure_event_cb(
    canvas,
    configure_event,
    userdata)
  destroy(userdata.surface)
  w = width(canvas)
  h = height(canvas)
  userdata.surface = CairoSurface(
    ccall((:gdk_window_create_similar_surface, Gtk.libgtk),
      Ptr{Void},
      (Ptr{Gtk.GdkWindow}, Gtk.GLib.GEnum, Cint, Cint),
      gdk_window(canvas),
      Cairo.CONTENT_COLOR_ALPHA,
      w,
      h))
  clear_surface(userdata)
  return 1
end

@guarded Cint(1) function draw_cb(
    canvas,
    ctx_ptr,
    userdata)
  ctx = CairoContext(ctx_ptr)
  set_source_surface(ctx, userdata.surface, 0, 0)
  paint(ctx)
  return Cint(0)
end

function draw_brush(
    canvas,
    x,
    y,
    userdata)
  ctx = CairoContext(userdata.surface)
  rectangle(ctx, x - 3, y - 3, 6, 6)
  fill(ctx)
  destroy(ctx)

  # Force the widget to update that part of the drawing
  ccall(
      (:gtk_widget_queue_draw_area, Gtk.libgtk),
      Void,
      (Ptr{Gtk.GObject}, Cint, Cint, Cint, Cint),
      canvas,
      x - 3,
      y - 3,
      6,
      6)
end

@guarded Cint(0) function button_press_event_cb(
    canvas,
    event,
    userdata) 

  # Make sure the surface is valid
  if userdata.surface.ptr == C_NULL
    return Cint(0)
  end

  if event.button == Gtk.GdkCursorType.LEFTBUTTON
    draw_brush(canvas, event.x, event.y, userdata)
  elseif event.button == Gtk.GdkCursorType.RIGHTBUTTON
    clear_surface(userdata)
    # Force a complete widget redraw after clearing the surface
    ccall(
        (:gtk_widget_queue_draw, Gtk.libgtk),
        Void,
        (Ptr{GObject}, ), 
        canvas)
  end

  return Cint(1)
end

@guarded Cint(0) function motion_notify_event_cb(
    canvas,
    event,
    userdata)

  # Make sure the surface is valid
  if userdata.surface.ptr == C_NULL
    return Cint(0)
  end

  if (event.state & Gtk.GdkModifierType.BUTTON1) != 0
    draw_brush(canvas, event.x, event.y, userdata)
  end

  return Cint(1)

end

# Destroy the cairo surface when the window closes
@guarded function close_window(
    window,
    userdata)
  destroy(userdata.surface)
  return nothing
end

end

canvas_builder("resources/draw.ui")

@test_throws ErrorException builder("resources/nonexistant.ui")

# run(test_app)

