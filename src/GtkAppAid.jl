

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


"""
This macro is meant to make using glade with Julia as easy as working with 
Glade in C is. From a staticly compiled language the function names are just
pulled from a compiled file but that option isn't available in Julia, at least
not cleanly.

Type annotations are necessary for this case as the macro needs to compile the
functions to cfunctions with minimal information.
"""
macro GtkAidBuild(args...)
  if length(args) < 2
    throw("ERROR: Requires at least two arguments")
  end

  userdata_call = :(userdata())
  directives = Set{Symbol}()
  function_name = :genned_function
  for directive in args[1:end - 2]
    if typeof(directive) <: Symbol
      # A symbol directive
      push!(directives, directive)
    elseif typeof(directive) <: Expr
      # An expression directive
      if directive.head == :call
        push!(directives, directive.args[1])
        if directive.args[1] == :userdata
          # Creates a tuple from the arguments
          # and uses that as the userinfo argument
          userdata_call = directive
        end

        if directive.args[1] == :application_window
          app_expr = directive.args[2] # The app object's symbol or expression
          window_id = directive.args[3] # id of the application window
        end

        if directive.args[1] == :function
          function_name = directive.args[2]
        end

      end
    else
      # A different sort of directive
    end
  end

  # Determine the tuple type
  userdata_tuple_type = Expr(:curly, :Tuple, argumentTypes(userdata_call)...)
  push!(directives, :userdata)

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

        # A big spot where things can go wrong
        fdecl = FunctionDeclaration(entry)

        if fdecl.function_name in keys(callback_declarations)
          throw("Function names must be unique, $line")
        end
        if :verbose in directives
          println("Adding function: $(fdecl.function_name)")
          println("Return Type: $(fdecl.return_type)")
          for fargtype in fdecl.argument_types
            println("Argument Type: $fargtype")
          end
        end
      end
    end
  end

  # Add commands 
  push!(block.args, quote
    built = @GtkBuilder(filename=$filename)
    # perform the symbol resolution actions
    return built
  end)

  # Emulate a typealias
  replaceSymbol!(block, :UserData, userdata_tuple_type)

  # Needs to do much of this in the parent scope
  return if :function_name in directives
    esc(quote
      function $function_name()
        $block
      end
      $function_name
    end)
  else
    quote 
      function $function_name()
        $(esc(block))
      end
      $function_name
    end
  end
end

end # module
