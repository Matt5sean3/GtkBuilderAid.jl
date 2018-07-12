
"""
```julia
arguments(call_expr::Expr)
```
For internal use.

Retrieves the argument expressions from a call expression.
"""
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
```julia
QuickstartUserdata(app::GtkApplication, builder::GtkBuilder, userdata)
```

This type is used to provide the Gtk application and builder to applications
created with the quickstart directive along with other user data.
"""
mutable struct QuickstartUserdata
  app::GtkApplication
  builder::GtkBuilder
  userdata
end

"""
```julia
GtkBuilderAidData(builder::GtkBuilder, handlers::Dict{String, Function})
```


"""
mutable struct GtkBuilderAidData
  builder::Union{GtkBuilder, Void}
  handlers::Dict{String, Function}
  userdata
  wpipe::IO
end

function (x::GtkBuilderAidData)(builder::Union{GtkBuilder, Void} = x.builder, userdata = x.userdata; wpipe::IO = x.wpipe)
  if isa(builder, Void)
    throw(MethodError("GtkBuilderAidData object must have builder to be callable without builder object"))
  else
    connect_signals(builder, x.handlers, userdata; wpipe = wpipe)
  end
  builder
end

function (x::GtkBuilderAidData)(builderFile::String, userdata = x.userdata; wpipe::IO = x.wpipe)
  builder = GtkBuilder(filename = builderFile)
  x(builder, userdata; wpipe = wpipe)
  builder
end

function quickstart(x::GtkBuilderAidData, appName::String, mainWindowId::String, builderFile::String, userdata = x.userdata)
  quickstart(GtkBuilder(builderFile), appName, mainWindowId, userdata = x.userdata)
end

function quickstart(x::GtkBuilderAidData, appName::String, mainWindowId::String, builder::Union{GtkBuilder, Void} = x.builder, userdata = x.userdata)
  # Create the app
  app = GtkApplication($app_name, 0)
  @guarded function activateApp(widget, app)
    x(builder, QuickstartUserdata(app, builder, appdata))

    # Quit the app when the window is destroyed
    win = Gtk.GAccessor.object(builder, mainWindowId)
    signal_connect(win, "destroy") do window
      ccall((:g_application_quit, Gtk.libgtk), Void, (Ptr{GObject}, ), app)
    end

    # Connect the app
    push!(app, win)
    showall(win)
    nothing
  end
  signal_connect(activateApp, app, :activate, Void, (), false, app)
  Gtk.register(app)
  # I forgot about this wonkiness, printing to stdout here is actually a necessary step
  println(join(("Starting Application:", $app_name), " "))
  run(app)
  println("Application Completed!")
end

"""
@GtkFunctionTable begin
  # ... callback functions ...
end

This macro allows using glade with Julia mostly as easy as working with Glade
in C is when coupled with `connect_signals` and the GtkBuilder object. The
macro creates a dictionary of all the callbacks that serves as a replacement
for the C function table that Gtk pulls callbacks from during usage with C.
"""
macro GtkFunctionTable(args...)
  length(args) < 1 && throw(ArgumentError("GtkBuilderAid macro requires at least one argument"))

  user_block = args[end]::Expr
  user_block.head != :block && throw(ArgumentError("The last argument to this macro must be a block"))

  # Analogous to function declarations of a C header file
  callbacks = Set{Symbol}();

  for entry in user_block.args

    if isa(entry, Expr)
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
      end

      if entry.head == :(=)
        left = entry.args[1]
        if isa(left, Expr) && left.head == :call && length(left.args) >= 3
          fname = left.args[1]
          push!(callbacks, fname)
        end
      end
    end
  end

  funcdata = Expr(:vect)
  for fname in callbacks
    push!(funcdata.args, Expr(:tuple, fname, string(fname)))
  end

  # Escape the modified user block
  quote
    $(esc(user_block))

    handlers = Dict{String, Function}()
    for func in $(esc(funcdata))
      handlers[string(func[2])] = func[1]
    end

    handlers
  end

end

"""
```julia
@GtkBuilderAid directives()... begin
  # ... implementation ...
end
```

This macro is meant to make using glade with Julia as easy as working with 
Glade in C is. From a staticly compiled language the function names are just
pulled from a compiled file but that option isn't available in Julia, at least
not cleanly.
"""
macro GtkBuilderAid(args...)
  length(args) < 1 && throw(ArgumentError("GtkBuilderAid macro requires at least one argument"))

  user_block = args[end]::Expr
  user_block.head != :block && throw(ArgumentError("The last argument to this macro must be a block"))

  # The whole directives thing was a mistake in retrospect
  lastDirective = length(args) - 1
  builder = nothing
  if length(args) >= 2 && isa(args[end - 1], AbstractString)
    lastDirective -= 1
    # Enables the pre-bound version
    filename = args[end - 1]
    if !isfile(filename)
      throw(ErrorException("Provided UI file, $filename, does not exist"))
    end
    builder = :(GtkBuilder(filename = $filename))
  end

  userdata = ()
  final_function_name = :genned_function
  for directive in args[1:lastDirective]
    # Only support expression-style directives
    if typeof(directive) <: Expr && directive.head == :call
      # A function call style directive
      if directive.args[1] == :function_name
        final_function_name = esc(directive.args[2])
      end

      if directive.args[1] == :userdata
        userdata = arguments(directive).args[1]
      end

      if directive.args[1] == :userdata_tuple
        # Creates a tuple from the arguments
        # and uses that as the userinfo argument
        userdata = arguments(directive)
      end

    else
      throw(ErrorException("Directives must be in the format of a function call"))
    end
  end

  block = quote
    handlers = @GtkFunctionTable $(esc(user_block))
    GtkBuilderAidData($builder, handlers, $(esc(userdata)), Base.STDERR)
  end

  quote
    $final_function_name = $block
  end
end

