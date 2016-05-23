using GtkAppAid
using Gtk
using Base.Test

include("function_inference.jl")

# Create an empty application
example_app = @GtkApplication("com.github.example", 0)

# Test out GtkHelperBuild macro
# Should encapsulate everything into a function

# TODO add an application_window(window, application) directive
built = @GtkAidBuild verbose userdata(example_app::GtkApplication) "resources/nothing.ui" begin

function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::UserInfo)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  # "nothing" is just a symbol when used in a macro
  return nothing::Void
end

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    window::Ptr{Gtk.GLib.GObject})
  destroy(window)
  return nothing::Void
end

end

push!(example_app, Gtk.GAccessor.object(built, "main_window"))

