
@test_throws MethodError GtkBuilderAid.arguments(5)
@test_throws ErrorException GtkBuilderAid.arguments(:(hello::There))

nullio = IOBuffer(0)


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

test_app = GtkApplication("com.github.test_gtkbuilderaid", 0)

# Check that an empty builder doesn't crash
@GtkBuilderAid function_name(empty_builder) begin

end
empty_builder("resources/nothing.ui", test_app; wpipe=nullio)

# Check that a poorly made builder doesn't crash
@GtkBuilderAid function_name(poor_builder) begin

function click_ok()
end

function close_window()
end

end
poor_builder("resources/nothing.ui", test_app; wpipe=nullio)

type InternalData
  counter::Int
end

@GtkBuilderAid function_name(long_builder) begin

@guarded function click_ok(
    widget, 
    data)
  data.counter += 1
  return nothing
end

@guarded function close_window(
    widget, 
    window)
  destroy(window)
  return nothing
end

end

@test_throws MethodError long_builder()

type ActivateData
  app
  data
end

@guarded function activate_long_builder_app(app, data)
  app = GObject(app)
  built = long_builder("resources/nothing.ui", data)

  w = Gtk.GAccessor.object(built, "main_window")
  push!(app, w)
  showall(w)

  # Try triggering the clicked signal
  ccall(
    (:g_signal_emit_by_name, Gtk.libgtk), 
    Void,
    (Ptr{GObject}, Ptr{Int8}),
    Gtk.GAccessor.object(built, "ok_button"), "clicked")

  ccall(
    (:g_signal_emit_by_name, Gtk.libgtk), 
    Void,
    (Ptr{GObject}, Ptr{Int8}),
    Gtk.GAccessor.object(built, "cancel_button"), "clicked")

  quit(app)
  return nothing
end

data = InternalData(0)
@test data.counter == 0
signal_connect(activate_long_builder_app, test_app, "activate", Void, (), false, data)
run(test_app)
@test data.counter == 1

# Show the expanded macro
# Mostly check that this succeeds
@GtkBuilderAid function_name(builder) userdata(test_app) "resources/nothing.ui" begin

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
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
    window)
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
  window = GObject(window)
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
    window)
  destroy(window)
  return nothing
end

end
end)

expanding_builder = @GtkBuilderAid begin

@guarded function close_window(
    widget,
    window)
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

shorthand_builder = @GtkBuilderAid begin

close_window(
    widget,
    window) = begin
  destroy(window)
  return nothing::Void
end

click_ok(
    widget,
    user_info) = begin
  println("OK clicked!")
  return nothing::Void
end

end
shorthand_builder("resources/nothing.ui")

# Test using an external builder
external_builder = @GtkBuilderAid begin

close_window(
    widget,
    window) = begin
  destroy(window)
  return nothing::Void
end

click_ok(
    widget,
    user_info) = begin
  println("OK clicked!")
  return nothing::Void
end

end
builder_obj = GtkBuilder(filename = "resources/nothing.ui")
external_builder(builder_obj)

# create a drag-drop interface
# TODO complete this and use it as ex3
immutable GtkTargetEntry
  target::Ptr{UInt8}
  flags::Cuint
  info::Cuint
end

@GtkBuilderAid function_name(drag_drop_builder) begin

@guarded function close_window(widget, window)
  destroy(window)
  nothing
end

@guarded function text_view_realize_cb(
    widget,
    userinfo)
  # enable drag-drop stuff
  targets = GtkTargetEntry[]
  ccall(
      (:gtk_drag_dest_set, Gtk.libgtk), 
      Void,
      (Ptr{GObject}, Cint, Ptr{GtkTargetEntry}, Cint, Cint),
      widget,
      Gtk.GConstants.GtkDestDefaults.DROP,
      targets,
      length(targets),
      Gtk.GConstants.GdkDragAction.COPY)
  nothing
end

@guarded function text_view_drag_data_received_cb(
    widget, 
    context,
    x,
    y,
    data,
    info,
    time,
    userinfo)
  println("Drag Received")
  nothing
end

@guarded Cint(0) function text_view_drag_drop_cb(
    widget, 
    context,
    x,
    y,
    time,
    userinfo)
  # drag-drop check area
  println("Drag Drop")
  Cint(1)
end

end

built = drag_drop_builder("resources/multiparameter.ui")

# Based off of GTK's Custom Drawing source code

# Test using canvas features of DrawingArea
type CanvasData
  surface::CairoSurface
end

# Clear the surface to white
function clear_surface(surf::CairoSurface)
  ctx = CairoContext(surf)
  set_source_rgb(ctx, 1, 1, 1)
  paint(ctx)
  destroy(ctx)
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
  destroy(ctx)

  # Force the widget to update that part of the drawing
  ccall(
      (:gtk_widget_queue_draw_area, Gtk.libgtk),
      Void,
      (Ptr{GObject}, Cint, Cint, Cint, Cint),
      canvas,
      px,
      py,
      6,
      6)
end

@GtkBuilderAid function_name(canvas_builder) begin

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
      (Ptr{Void}, Gtk.GEnum, Cint, Cint),
      Gtk.gdk_window(canvas),
      Cairo.CONTENT_COLOR_ALPHA,
      w,
      h),
    w,
    h)
  clear_surface(userdata.surface)
  return Cint(1)
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

@guarded Cint(0) function button_press_event_cb(
    canvas,
    event_ptr,
    userdata) 

  event = Gtk.GdkEvent(event_ptr)

  # Make sure the surface is valid
  if userdata.surface.ptr == C_NULL
    return Cint(0)
  end

  if event.button == 1
    draw_brush(canvas, event.x, event.y, userdata.surface)
  elseif event.button == 3
    clear_surface(userdata.surface)
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
    event_ptr,
    userdata)

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

# Destroy the cairo surface when the window closes
@guarded function close_window(
    window,
    userdata)
  destroy(userdata.surface)
  return nothing
end

end

# Start with an under-defined cairo surface
canvas_builder("resources/draw.ui", CanvasData(CairoSurface(C_NULL, -1, -1)))

@test_throws ErrorException builder("resources/nonexistant.ui")

# run(test_app)

