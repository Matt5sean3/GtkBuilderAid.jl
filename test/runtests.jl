using GtkAppAid
using Gtk
using Base.Test

include("function_inference.jl")

# Create an empty application
example_app = @GtkApplication("com.github.example", 0)

# TODO add an application_window(window, application) directive
builder = @GtkAidBuild userdata(example_app::GtkApplication) "resources/nothing.ui" begin

function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::UserData)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  return nothing::Void
end

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    window::Ptr{Gtk.GLib.GObject})
  destroy(window)
  return nothing::Void
end

end

function activateApp(widget, userdata)
  app, = userdata
  built = builder()
  # built = @GtkBuilder(filename="resources/nothing.ui")
  win = Gtk.GAccessor.object(built, "main_window")
  push!(app, win)
  showall(win)
  return nothing
end

signal_connect(activateApp, example_app, :activate, Void, (), false, (example_app, ))

run(example_app)

