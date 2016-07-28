__precompile__()

module GtkBuilderAid
using Gtk
using Cairo
using Compat

export @GtkBuilderAid

include("connect_signals.jl")
include("aidbuild.jl")
include("misc.jl")

end # module
