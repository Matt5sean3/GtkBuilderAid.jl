
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

test_macro_throws(ArgumentError, quote 
@GtkBuilderAid hello
end)

test_app = @GtkApplication("com.github.test_gtkbuilderaid", 0)

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
test_macro_throws(MethodError, quote 
@GtkBuilderAid mistake begin

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

# Test having a non-block final argument
test_macro_throws(MethodError, quote
@GtkBuilderAid "resources/nothing.ui" mistake begin

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

