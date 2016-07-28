import Base: quit
export reveal_area, create_similar_surface

# Some convenience functionalities

const suffix = "Leaf"

# Quit the Gtk application
function quit(app::Gtk.GApplication)
  ccall((:g_application_quit, Gtk.libgio), Void, (Ptr{GObject}, ), app)
end

"""
```julia
reveal_area(
    canvas::Gtk.GtkWidget,
    x::Integer,
    y::Integer,
    width::Integer,
    height::Integer)
```
Selectively update portions of a widget.

This is a wrapper around the C function `gtk_widget_queue_draw_area`.
"""
reveal_area(
    canvas::Gtk.GtkWidget, 
    x::Integer, 
    y::Integer, 
    width::Integer, 
    height::Integer) =
  ccall(
    (:gtk_widget_queue_draw_area, Gtk.libgtk), 
    Void, 
    (Ptr{GObject}, Cint, Cint, Cint, Cint), 
    canvas, x, y, width, height)

"""
```julia
window(widget::Gtk.GtkWidget)::GObject
```
Get the GdkWindow as a GObject.

This is a wrapper for the `gtk_widget_get_window` C function.
"""
window(widget::Gtk.GtkWidget) = 
    GObject(ccall(
        (:gtk_widget_get_window, Gtk.libgtk), 
        Ptr{GObject}, 
        (Ptr{GObject}, ), 
        widget))

"""
```julia
create_similar_surface(
    w::GObject,
    content::Gtk.GEnum,
    width::Cint,
    height::Cint)
create_similar_surface(
    w::Gtk.GtkWidget,
    content::Gtk.GEnum = Gtk.GEnum(Cairo.CONTENT_COLOR_ALPHA))
```
This is a wrapper for the `gdk_window_create_similar_surface` C function.

The second form calls the first with width and height information taken from
the widget.
"""
function create_similar_surface(
    w::GObject,
    content::Gtk.GEnum,
    width::Cint,
    height::Cint)
  CairoSurface(
    ccall(
      (:gdk_window_create_similar_surface, Gtk.libgdk), 
      Ptr{Void}, 
      (Ptr{GObject}, Gtk.GEnum, Cint, Cint),
      w, content, width, height), 
    width, height)
end
create_similar_surface(w::Gtk.GtkWidget, content::Gtk.GEnum=Gtk.GEnum(Cairo.CONTENT_COLOR_ALPHA)) =
  create_similar_surface(window(w), content, width(w), height(w))

