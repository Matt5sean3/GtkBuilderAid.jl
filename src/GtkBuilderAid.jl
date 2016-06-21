

module GtkBuilderAid

using Gtk

export @GtkBuilderAid

include("connect_signals.jl")
include("aidbuild.jl")

end # module
