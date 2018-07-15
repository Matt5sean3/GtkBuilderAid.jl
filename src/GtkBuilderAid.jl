__precompile__()

module GtkBuilderAid
using Gtk
using Cairo

export @GtkBuilderAid, @GtkFunctionTable, quickstart

include("connect_signals.jl")
include("aidbuild.jl")
include("misc.jl")

end # module
