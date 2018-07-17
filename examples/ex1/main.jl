#!/usr/bin/env julia

using Gtk
using GtkBuilderAid

example_app = GtkApplication("io.github.matt5sean3.GtkBuilderAid.first", 0)

builder = @GtkBuilderAid userdata(example_app) begin

@guarded function click_ok(
    widget, 
    app)
  println("OK clicked!")
  return nothing
end

@guarded function close_window(
    widget, 
    window)
  destroy(window)
  return nothing
end

end

@guarded function activateApp(widget, userdata)
  app, builder = userdata
  built = builder("resources/main.ui")
  win = Gtk.GAccessor.object(built, "main_window")
  push!(app, win)
  showall(win)
  return nothing
end

signal_connect(activateApp, example_app, :activate, Void, (), false, (example_app, builder))

println("Starting App")
run(example_app)

