

module GtkBuilderAid

using Gtk

export @GtkBuilderAid

include("function_inference.jl")
include("aidbuild.jl")

end # module
