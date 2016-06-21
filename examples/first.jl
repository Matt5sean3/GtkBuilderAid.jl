#!/usr/bin/env julia

using Gtk
using GtkBuilderAid

example_app = @GtkApplication("com.github.example", 0)

builder = @GtkBuilderAid userdata(example_app) begin

@guarded function click_ok(
    widget, 
    user_info)
  println("OK clicked!")
  return nothing
end

@guarded function quit_app(
    widget, 
    user_info)
  ccall(
      (:g_application_quit, Gtk.libgtk), 
      Void, 
      (Ptr{Gtk.GLib.GObject}, ), 
      user_info)
  return nothing
end

@guarded function close_window(
    widget, 
    window)
  destroy(Gtk.GObject(window))
  return nothing
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

