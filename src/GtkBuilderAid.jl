

module GtkBuilderAid
using Gtk
using Compat

export @GtkBuilderAid

include("connect_signals.jl")
include("aidbuild.jl")

end # module
