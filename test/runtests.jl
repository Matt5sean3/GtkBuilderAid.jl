using GtkBuilderAid
using Gtk
using Cairo
using Base.Test

# Force loading a few things into memory
# Need to do this to make the builder work in early versions
dummy = @GtkWindow("DUMMY")
dummy_box = @GtkBox(:v)
push!(dummy_box, @GtkLabel("dummy"))
dummy_button_box = @GtkButtonBox(:h)
push!(dummy_box, dummy_button_box)
push!(dummy_button_box, @GtkButton("dummy"))
destroy(dummy)

include("aidbuild.jl")
include("misc.jl")

