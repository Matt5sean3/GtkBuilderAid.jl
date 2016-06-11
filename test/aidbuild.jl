
function test_macro_throws(error_type, macroexpr)
  expansion = macroexpand(macroexpr)
  if expansion.head != :error
    warn("Expansion did not throw error")
    dump(expansion)
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
@GtkBuilderAid hello
end)

test_macro_throws(ArgumentError, quote 
@GtkBuilderAid 
end)

test_app = @GtkApplication("com.github.test_gtkbuilderaid", 0)

# Try out known userdata with 
long_builder = @GtkBuilderAid userdatatype(GtkApplication) begin

function click_ok(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    user_info::Ptr{UserData})
  println("OK clicked!")
  return 0
end

function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::Ptr{UserData})
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  return nothing::Void
end

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = convert(Gtk.GObject, window_ptr)
  destroy(window)
  return 0
end

end

@test_throws MethodError long_builder()
@test_throws MethodError long_builder("resources/nothing.ui")
long_builder("resources/nothing.ui", (test_app, ))

# Show the expanded macro
# Mostly check that this succeeds
builder = @GtkBuilderAid verbose userdata(test_app::GtkApplication) "resources/nothing.ui" begin

function click_ok(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    user_info::Ptr{UserData})
  println("OK clicked!")
  return 0
end

function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::Ptr{UserData})
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  return nothing::Void
end

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = convert(Gtk.GObject, window_ptr)
  destroy(window)
  return 0
end

end

builder()
# Also check that the unbound form works
builder("$(Pkg.dir("GtkBuilderAid"))/test/resources/nothing.ui")

# check again but with an explicit name for the builder function
@GtkBuilderAid function_name(build_nothing) userdata(test_app::GtkApplication) "resources/nothing.ui" begin

function click_ok(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    user_info::Ptr{UserData})
  println("OK clicked!")
  return 0
end

end

# Test non-string file arguments
base_method_builder = @GtkBuilderAid begin

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = convert(Gtk.GObject, window_ptr)
  destroy(window)
  return 0
end

function click_ok(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    user_info::Ptr{UserData})
  println("OK clicked!")
  return 0
end

end

@test_throws MethodError base_method_builder()
# Should succeed
base_method_builder("resources/nothing.ui")

# Test non-existent files
test_macro_throws(ErrorException, quote
@GtkBuilderAid "resources/nonexistentfile.ui" begin

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = convert(Gtk.GObject, window_ptr)
  destroy(window)
  return 0
end

end
end)

# @test_throws ErrorException broken_builder2()

# Test duplicate function names
test_macro_throws(MethodError, quote
@GtkBuilderAid "resources/nothing.ui" begin

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = convert(Gtk.GObject, window_ptr)
  destroy(window)
  return 0
end

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = convert(Gtk.GObject, window_ptr)
  destroy(window)
  return 0
end

end
end)

@guarded function activateApp(widget, userdata)
  app, builder = userdata
  built = builder()
  win = Gtk.GAccessor.object(built, "main_window")
  push!(app, win)
  showall(win)
  return nothing
end

signal_connect(activateApp, test_app, :activate, Void, (), false, (test_app, builder))

# run(test_app)

