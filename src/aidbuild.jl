
function arguments(call_expr::Expr)
  if call_expr.head != :call
    throw(ErrorException("Malformed function declaration"))
  end
  call_expr = copy(call_expr)
  call_expr.head = :tuple
  shift!(call_expr.args)
  return call_expr
end

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

  lastDirective = length(args) - 1
  if length(args) >= 2 && isa(args[end - 1], AbstractString)
    lastDirective -= 1
    # Enables the pre-bound version
    filename = args[end - 1]
    if !isfile(filename)
      throw(ErrorException("Provided UI file, $filename, does not exist"))
    end
    push!(directives, :filename)
  end

  userdata = ()
  generated_function_name = :genned_function
  for directive in args[1:lastDirective]
    # Only support expression-style directives
    if typeof(directive) <: Expr && directive.head == :call
      # A function call style directive
      push!(directives, directive.args[1])
      if directive.args[1] == :function_name
        generated_function_name = directive.args[2]
      end

      if directive.args[1] == :userdata
        userdata = arguments(directive).args[1]
      end

      if directive.args[1] == :userdata_tuple
        # Creates a tuple from the arguments
        # and uses that as the userinfo argument
        push!(directives, :userdata)
        userdata = arguments(directive)
      end

    else
      throw(ErrorException("Directives must be in the format of a function call"))
    end
  end

  # Analogous to function declarations of a C header file
  callbacks = Set{Symbol}();
  # Necessary for pass-through
  passthroughs = Set{Int}()

  line = 0
  for entry in user_block.args

    if isa(entry, Expr)
      if entry.head == :line
        line = entry.args[1]
      end

      if entry.head == :macrocall
        # expand the macro
        expanded = macroexpand(entry)
        if expanded.head == :function
          entry.head = expanded.head
          entry.args = expanded.args
        end
      end
      if entry.head == :function && length(entry.args[1].args) >= 3
        fcall = entry.args[1]
        fname = fcall.args[1]
        push!(callbacks, fname)
        push!(passthroughs, length(fcall.args) - 1)
      end

      if entry.head == :(=)
        left = entry.args[1]
        if isa(left, Expr) && left.head == :call && length(left.args) >= 3
          fname = left.args[1]
          push!(callbacks, fname)
          push!(passthroughs, length(left.args) - 1)
        end
      end
    end
  end

  # Extend the curly to get things by argument type
  base_passthrough_decl = :(passthrough{T, O, P}(object, userdata::PassthroughData{T, O, P}))
  base_passthrough_expr = :(ccall(userdata.func, T, (Ref{O}, Ref{P}), GObject(object), userdata.data))
  passthrough_expr = quote
    passthrough() = nothing
  end
  for passthrough in passthroughs 
    new_passthrough_decl = deepcopy(base_passthrough_decl)
    new_passthrough_expr = deepcopy(base_passthrough_expr)
    
    # passthrough{T, O, P, X1 ... XN}(object, x_1::X1 ... x_n::XN, userdata::PassthroughData{T, O, P}) = 
    #   ccall(userdata.func, T, (O, X1 ... XN, P), GObject(object), x_1 ... x_n, GObject(userdata.data))
    # Inserts additional arguments
    for i in 1:passthrough - 2
      var = symbol("x_", i)
      typ = symbol("X", i)
      insert!(new_passthrough_decl.args, 3, :($var::$typ))
      insert!(new_passthrough_expr.args, 5, var)
      push!(new_passthrough_decl.args[1].args, typ)
      insert!(new_passthrough_expr.args[3].args, 2, typ)
    end
    # Provides types for the arguments

    append!(passthrough_expr.args, (quote
      $new_passthrough_decl = begin
        $new_passthrough_expr
      end
    end).args)
  end

  funcdata = Expr(:vect)
  for fname in callbacks
    push!(funcdata.args, Expr(:tuple, fname, string(fname)))
  end

  # Escape the modified user block
  block = quote
    $(esc(user_block))
    $passthrough_expr
    handlers

    handlers = Dict{Compat.String, Function}()
    for func in $(esc(funcdata))
      handlers[string(func[2])] = func[1]
    end

    connectSignals(built, handlers, userdata, passthrough; wpipe=wpipe)

    return built
  end

  if :function_name in directives
    final_function_name = esc(generated_function_name)
  else
    final_function_name = generated_function_name
  end

  filename_arg = :(filename::AbstractString)
  userdata_arg = Expr(:kw, :userdata, esc(userdata))

  if :filename in directives
    filename_arg = Expr(:kw, filename_arg, filename)
  end

  funcdef = Expr(:function, :($final_function_name(built::GtkBuilderLeaf, $userdata_arg; wpipe=Base.STDERR)), block)

  quote
    $funcdef
    $final_function_name($filename_arg, $userdata_arg; wpipe=Base.STDERR) = 
      $final_function_name(@GtkBuilder(filename=filename), userdata; wpipe=wpipe)
    $final_function_name
  end
end
