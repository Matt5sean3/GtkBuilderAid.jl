

module GtkAppAid

using Gtk

export GtkBuilderHelper

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

include("function_inference.jl")

"""
This macro is meant to make using glade with Julia as easy as working with 
Glade in C is. From a staticly compiled language the function names are just
pulled from a compiled file but that option isn't available in Julia, at least
not cleanly.

Type annotations are necessary for this case as the macro needs to compile the
functions to cfunctions with minimal information.
"""
macro GtkBuilderHelper(args...)
  if length(args) < 2
    throw("ERROR: Requires at least two arguments")
  end

  # Create a set of directives
  directives = Set([directive::Symbol for directive in args[1:end - 2]])

  # Analogous to function declarations of a C header file
  callback_declarations = Dict{Symbol, FunctionDeclaration}();

  filename = args[end - 1]
  if !isfile(filename)
    throw("ERROR: Provided UI file does not exist")
  end

  block = args[end]::Expr
  if block.head != :block
    throw("The last argument to this macro must be a block")
  end

  line = 0
  for entry in block.args
    if typeof(entry) <: Expr
      if entry.head == :line
        line = entry.args[1]
      end
      if entry.head == :function
        fdecl = FunctionDeclaration(entry)
        if fdecl.function_name in callback_declarations
          throw("Function names must be unique, $line")
        end
        if :verbose in directives
          println("Adding function: $(fdecl.function_name)")
          println("Return Type: $(fdecl.return_type)")
          for fargtype in fdecl.argument_types
            println("Argument Type: $fargtypes")
          end
        end
      end
    end
  end

  return quote
    built = @GtkBuilder(filename=$filename)
    
  end

end

end # module
