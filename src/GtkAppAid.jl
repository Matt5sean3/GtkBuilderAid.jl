

module GtkAppAid

using Gtk

export @GtkAidBuild

include("function_inference.jl")

# TODO add bindings for g_application_quit

function addCallbackSymbols(built, pairs)
  flat_pairs = Union{Symbol, Ptr{Void}}[]
  for pair in pairs
    push!(flat_pairs, pair[0])
    push!(flat_pairs, pair[1])
  end
  ccall(
      (:gtk_builder_add_callback_symbols, Gtk.libgtk),
      Void,
      (
          Ptr{Gtk.GLib.GObject}, 
          repeat([Ptr{UInt8}, ], outer = [length(pairs)])...),
      built,
      flat_pairs...)
end

include("aidbuild.jl")

end # module
