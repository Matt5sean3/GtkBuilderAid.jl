#!/usr/bin/env julia

using Gtk
using GtkBuilderAid

example_app = @GtkApplication("com.github.example", 0)

builder = @GtkBuilderAid userdata(example_app::GtkApplication) begin

@guarded function click_ok(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    user_info::UserData)
  println("OK clicked!")
  return nothing::Void
end

@guarded function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::UserData)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  return nothing::Void
end

@guarded function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing::Void
end

end

@guarded function activateApp(widget, userdata)
  app, builder = userdata
  built = builder("resources/first.ui")
  win = Gtk.GAccessor.object(built, "main_window")
  push!(app, win)
  showall(win)
  return nothing
end

signal_connect(activateApp, example_app, :activate, Void, (), false, (example_app, builder))

run(example_app)
