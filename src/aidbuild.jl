
"""
This macro is meant to make using glade with Julia as easy as working with 
Glade in C is. From a staticly compiled language the function names are just
pulled from a compiled file but that option isn't available in Julia, at least
not cleanly.

Type annotations are necessary for this case as the macro needs to compile the
functions to cfunctions with minimal information.
"""
macro GtkBuilderAid(args...)
  if length(args) < 1
    throw(ArgumentError("GtkBuilderAid macro requires at least one argument"))
  end

  user_block = args[end]::Expr
  if user_block.head != :block
    throw(ArgumentError("The last argument to this macro must be a block"))
  end

  directives = Set{Symbol}()

  if length(args) >= 2 && isa(args[end - 1], AbstractString)
    # Enables the pre-bound version
    filename = args[end - 1]
    if !isfile(filename)
      throw(ErrorException("Provided UI file, $filename, does not exist"))
    end
    push!(directives, :filename)
  end

  userdata_tuple = ()
  userdata_tuple_type = Expr(:curly, :Tuple)
  generated_function_name = :genned_function
  for directive in args[1:end - 1]
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
          userdata_tuple = arguments(directive)
          userdata_tuple_type = Expr(:curly, :Tuple, argumentTypes(directive)...)
          push!(directives, :userdata)
        end

        if directive.args[1] == :function
          generated_function_name = directive.args[2]
        end

        if directive.args[1] == :userdatatype
          userdata_tuple_type = Expr(:curly, :Tuple, directive.args[2:end]...)
        end

      end
    else
      # A different sort of directive
    end
  end

  # Analogous to function declarations of a C header file
  callback_declarations = Dict{Symbol, FunctionDeclaration}();

  # Emulate a typealias
  replaceSymbol!(user_block, :UserData, userdata_tuple_type)

  line = 0
  for entry in user_block.args

    if typeof(entry) <: Expr
      if entry.head == :line
        line = entry.args[1]
      end

      if entry.head == :function

        # A big spot where things can go wrong
        fdecl = FunctionDeclaration(entry)

        if fdecl.function_name in keys(callback_declarations)
          throw(DomainError("Function names must be unique, $line"))
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

  funcdata = Expr(:vect)
  for fdecl in values(callback_declarations)
    # [1] function symbol
    # [2] function string name
    # [3] function return type
    # [4] function argument types
    push!(funcdata.args, Expr(:tuple, 
        fdecl.function_name,
        string(fdecl.function_name),
        fdecl.return_type,
        Expr(:tuple, fdecl.argument_types...)))
  end

  # Escape the modified user block
  block = quote
    $(esc(user_block))

    if !isfile(filename)
      throw(ErrorException("Provided UI file, $filename, does not exist"))
    end
    built = @GtkBuilder(filename=filename)
    
    for func in $(esc(funcdata))
      funcptr = cfunction(func[1], func[3], func[4])
      ccall(
          (:gtk_builder_add_callback_symbol, Gtk.libgtk),
          Void,
          (Ptr{Gtk.GLib.GObject}, Ptr{UInt8}, Ptr{Void}),
          built,
          func[2],
          funcptr)
    end

    ccall(
        (:gtk_builder_connect_signals, Gtk.libgtk), 
        Void, 
        (Ptr{Gtk.GLib.GObject}, Ptr{Void}),
        built,
        pointer_from_objref(userdata))
    return built
  end

  if :function_name in directives
    final_function_name = :($(esc(generated_function_name)))
  else
    final_function_name = generated_function_name
  end

  filename_arg = Expr(:(::), :filename, :AbstractString)
  if :filename in directives
    filename_arg = Expr(:kw, filename_arg, filename)
  end

  userdata_arg = Expr(:(::), :userdata, userdata_tuple_type)
  if !(:userdatatype in directives)
    userdata_arg = Expr(:kw, userdata_arg, esc(userdata_tuple))
  end

  funcdef = Expr(:function, :($final_function_name($filename_arg, $userdata_arg)), block)

  ret = quote
    $funcdef
    $final_function_name
  end

  return ret
end
