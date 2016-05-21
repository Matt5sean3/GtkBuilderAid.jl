using GtkAppAid
using Gtk
using Base.Test

include("function_inference.jl")

# Create an empty application
example_app = @GtkApplication("com.github.example", 0)

# Test out GtkHelperBuild macro
# Should encapsulate everything into a function
built = @GtkAidBuild userdata(example_app) "resources/nothing.ui" begin

function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::UserInfo)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
end

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    window::Ptr{Gtk.GLib.GObject})
  destroy(window)
end

push!(example_app)

