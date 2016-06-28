
# quit needs to work or early tests will hang

# Try out queue_draw_area
da = Gtk.@GtkDrawingArea(ccall((:gtk_drawing_area_new, Gtk.libgtk), Ptr{GObject}, ()))
w = @GtkWindow(da, "Test Window")
@test isa(GtkBuilderAid.window(da), GtkBuilderAid.GdkWindowLeaf)

@test isa(create_similar_surface(da), CairoSurface)

# Can't do much beyond check that it doesn't error out
reveal_area(da, 5, 5, 5, 5)

destroy(w)

