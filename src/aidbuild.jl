
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
      if entry.head == :function
        fcall = entry.args[1]
        fname = fcall.args[1]
        body = entry.args[2]
        if length(fcall.args) >= 3 && isa(fcall.args[end], Symbol)
          # Convert the last argument to a GObject if it's a gpointer
          last_arg = fcall.args[end]
          new_last_arg = symbol(last_arg, "_ptr")
          fcall.args[end] = new_last_arg
          prepend!(body.args, (quote 
            $last_arg = if isa($new_last_arg, Ptr{GObject})
              GObject($new_last_arg)
            else
              $new_last_arg
            end
          end).args)
        end
        if length(fcall.args) >= 2 && isa(fcall.args[2], Symbol)
          # Convert the first argument to a GObject if it's a gpointer
          first_arg = fcall.args[2]
          new_first_arg = symbol(first_arg, "_ptr")
          fcall.args[2] = new_first_arg
          prepend!(body.args, (quote 
            $first_arg = GObject($new_first_arg)
          end).args)
        end
        # Can support multiple function methods now
        push!(callbacks, fname)
      end

      if entry.head == :(=)
        left = entry.args[1]
        if isa(left, Expr) && left.head == :call
          fname = left.args[1]
          push!(callbacks, fname)
        end
      end
    end
  end

  funcdata = Expr(:vect)
  for fname in callbacks
    push!(funcdata.args, Expr(:tuple, 
        fname,
        string(fname)))
  end

  # Escape the modified user block
  block = quote
    $(esc(user_block))

    if !isfile(filename)
      throw(ErrorException("Provided UI file, $filename, does not exist"))
    end
    built = @GtkBuilder(filename=filename)
    
    handlers = Dict{Compat.String, Function}()
    for func in $(esc(funcdata))
      handlers[string(func[2])] = func[1]
    end

    connectSignals(built, handlers, userdata; wpipe=wpipe)

    return built
  end

  if :function_name in directives
    final_function_name = esc(generated_function_name)
  else
    final_function_name = generated_function_name
  end

  filename_arg = :filename
  userdata_arg = Expr(:kw, :userdata, esc(userdata))

  if :filename in directives
    filename_arg = Expr(:kw, filename_arg, filename)
  end

  funcdef = Expr(:function, :($final_function_name($filename_arg, $userdata_arg; wpipe=Base.STDERR)), block)

  # For some reason scope seems to be killing me now
  if :function_name in directives
    return funcdef
  else
    return quote
      $funcdef
      $final_function_name
    end
  end

end
