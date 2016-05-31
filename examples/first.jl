#!/usr/bin/env julia

using Gtk
using GtkBuilderAid

example_app = @GtkApplication("com.github.example", 0)

builder = @GtkBuilderAid userdata(example_app::GtkApplication) "resources/first.ui" begin

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

signal_connect(activateApp, example_app, :activate, Void, (), false, (example_app, builder))

run(example_app)
