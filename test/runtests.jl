using GtkBuilderAid
using Gtk
using Base.Test

include("function_inference.jl")

test_app = @GtkApplication("com.github.test_gtkbuilderaid", 0)

builder = @GtkBuilderAid userdata(test_app::GtkApplication) "resources/nothing.ui" begin

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

