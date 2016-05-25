

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
  userdata_tuple = arguments(userdata_call)
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

  # Emulate a typealias
  replaceSymbol!(block, :UserData, userdata_tuple_type)

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
        callback_declarations[fdecl.function_name] = fdecl
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
  append!(block.args, (quote
    built = @GtkBuilder(filename=$filename)
  end).args)

  # Build cfunction and argument tuple
  add_callback_symbols_arguments = :()
  add_callback_symbols_argument_types = :(Ptr{Gtk.GLib.GObject}, )
  for fdecl in values(callback_declarations)

    # Add the function pointer symbol
    funcptr_symbol = Symbol(string(fdecl.function_name, "_ptr"))
    fname = fdecl.function_name
    frettype = fdecl.return_type
    fargtypes = Expr(:tuple, fdecl.argument_types...)
    fname_str = string(fname)
    append!(block.args, (quote 
      # The code sort of expands with this unfortunately
      $funcptr_symbol = cfunction($fname, $frettype, $fargtypes)
      ccall(
          (:gtk_builder_add_callback_symbol, Gtk.libgtk),
          Void,
          (Ptr{Gtk.GLib.GObject}, Ptr{UInt8}, Ptr{Void}),
          built,
          $fname_str,
          $funcptr_symbol)
    end).args)
  end

  append!(block.args, (quote
    # connect the signals and the userdata tuple
    # TODO ensure the userdata_tuple doesn't get garbage collected
    userdata = $userdata_tuple
    ccall(
        (:gtk_builder_connect_signals, Gtk.libgtk), 
        Void, 
        (Ptr{Gtk.GLib.GObject}, Ptr{Void}),
        built,
        pointer_from_objref(userdata))
    return built
  end).args)

  # Needs to do much of this in the parent scope
  funcdef = if :function_name in directives
    esc(Expr(:function, :($function_name()), block))
  else
    Expr(:function, :($function_name()), esc(block))
  end

  return quote
    $funcdef
    $function_name
  end
end

end # module
