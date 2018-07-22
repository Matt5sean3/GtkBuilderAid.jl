#!/usr/bin/env julia

using Gtk
using GtkBuilderAid

example_app = GtkApplication("io.github.matt5sean3.GtkBuilderAid.first", 0)

ft = @GtkFunctionTable begin

@guarded function click_ok(
    widget, 
    qsdata)
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

start_application(ft, "io.github.matt5sean3.GtkBuilderAid.first", "main_window", "resources/main.ui", nothing)

