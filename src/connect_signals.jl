
export connect_signals

"""
```julia
GSignalQuery(
  signal_id::Cuint,
  signal_name::Ptr{Int8},
  itype::Gtk.GType,
  signal_flags::Gtk.GEnum,
  return_type::Gtk.GType,
  n_params::Cuint,
  param_types::Ptr{Gtk.GType})
```
For internal use.

A structure holding information for a specific signal. It is filled in by the
`g_signal_query` C function.

See `struct GSignalQuery` in the GObject reference manual for more information
* `signal_id` - The signal id of the signal being queried, or 0 if the signal 
to be queried was unknown.
* `signal_name` - The signal name.
* `itype` - The interface/instance type that this signal can be emitted for.
* `signal_flags` - The signal flags as passed in to the `g_signal_new` C
function
* `return_type` - The return type for user callbacks.
* `n_params` - The number of parameters that user callbacks take.
* `param_types` - The individual parameter types for user callbacks, note that
the effective callback signature is:
```julia
callback(
    data1::Ptr{GObject},
    [param_name_1::ParamType1 ... param_name_n::ParamTypeN], 
    data2::Ptr{GObject})::return_type
```
see also: SignalInfo, query_signal
"""
immutable GSignalQuery
  signal_id::Cuint
  signal_name::Ptr{Int8}
  itype::Gtk.GType
  signal_flags::Gtk.GEnum
  return_type::Gtk.GType
  n_params::Cuint
  param_types::Ptr{Gtk.GType}
end

"""
```julia
SignalInfo(
    itype::Type, 
    return_type::Type, 
    parameter_types::Array{Type, 1})
```
For internal use.

A data type with information about a particular signal.
* `itype` - The interface type that the signal is emitted for.
* `return_type` - The return type for the user callbacks.
* `parameter_types` - The parameter types for the user callbacks.
see also: GSignalQuery, query_signal
"""
immutable SignalInfo
  itype::Type
  return_type::Type
  parameter_types::Array{Type, 1}
end

# Not all types were already covered so add in an auxiliary case
const more_types = Dict{Symbol, Type}(
  :GdkEvent => Ptr{Gtk.GdkEvent},
  :GdkEventButton => Ptr{Gtk.GdkEventButton});

"""
```julia
gtype_to_jtype(t::Gtk.GType)::Type
```
For internal use.

Maps from a `GType` object to the corresponding Julia object type.
* `t` - The type to convert.
"""
function gtype_to_jtype(t::Gtk.GType)
  for (i, id) in enumerate(Gtk.GLib.fundamental_ids)
    if id == t
      return Gtk.GLib.fundamental_types[i][2]
    end
  end
  typename = Gtk.GLib.g_type_name(t)
  if typename in keys(Gtk.GLib.gtype_wrappers)
    return Ptr{Gtk.GLib.gtype_abstracts[typename]}
  end
  if typename in keys(more_types)
    return more_types[typename]
  end
  return Ptr{Void}
end

"""
```julia
query_signal(obj::GObject, signal_name::String)::SignalInfo
```
For internal use.

Looks up details about a particular signal on an object and provides it as 
`SignalInfo`.
* `obj` - The GObject to get the details of the signal for.
* `signal_name` - The name of the signal to get details for
"""
function query_signal(obj::GObject, signal_name::String)
  obj_class = Gtk.GLib.G_OBJECT_CLASS_TYPE(obj)
  signal_id = ccall(
    (:g_signal_lookup, Gtk.GLib.libgobject),
    Cuint,
    (Ptr{Int8}, Gtk.GType),
    signal_name,
    obj_class)
  result = Ref{GSignalQuery}()
  ccall(
    (:g_signal_query, Gtk.GLib.libgobject), 
    Void, 
    (Cuint, Ptr{GSignalQuery}), 
    signal_id, 
    result)
  SignalInfo(
    gtype_to_jtype(result[].itype),
    gtype_to_jtype(result[].return_type),
    [gtype_to_jtype(gtype) for gtype in unsafe_wrap(Array,
      result[].param_types, 
      result[].n_params)])
end

"""
```julia
SignalConnectionData
```
For internal use.

"""
type SignalConnectionData
  handlers::Dict{String, Function}
  data
  warn_pipe::IO
  passthrough::Function
end

"""
```julia
PassthroughData{T, O, P}(
  ret_type::Type{T},
  object_type::Type{O},
  func::Ptr{Void},
  data::P)
```
For internal use.
"""
type PassthroughData{T, O, P}
  ret_type::Type{T}
  object_type::Type{O}
  func::Ptr{Void}
  data::P
end

"""
```
connect_signals_c_function(
    builder,
    object_ptr,
    signal_name_ptr,
    handler_name_ptr,
    connect_object_ptr,
    flags,
    userdata_ptr)
```
For internal use.

A compilable function for configuring signal connections. Passed in its 
compiled form to the `gtk_builder_connect_signals_full` C function.
The cfunction version runs but the julia version doesn't
"""
function connect_signals_c_function(
    builder, 
    object_ptr, 
    signal_name_ptr, 
    handler_name_ptr, 
    connect_object_ptr, 
    flags, 
    userdata_ptr)
  userdata = unsafe_pointer_to_objref(userdata_ptr)
  wpipe = userdata.warn_pipe

  handler_name = unsafe_string(handler_name_ptr)
  if !(handler_name in keys(userdata.handlers))
    warn(wpipe, "Signal handler, $handler_name, could not be found")
    return nothing
  end
  handler = userdata.handlers[handler_name]
  passthrough = userdata.passthrough

  object = GObject(object_ptr)
  signal_name = unsafe_string(signal_name_ptr)
  signal_info = query_signal(object, signal_name)

  passed_data = (connect_object_ptr == C_NULL)? userdata.data : GObject(connect_object_ptr)
  ptypes = tuple(Ref{typeof(object)}, signal_info.parameter_types..., Ref{typeof(passed_data)})
  cptr = cfunction(
      handler,
      signal_info.return_type,
      ptypes)
  data = PassthroughData(signal_info.return_type, typeof(object), cptr, passed_data)
  try
    cptr = cfunction(
        handler,
        signal_info.return_type,
        ptypes)
    signal_connect(
        passthrough, 
        object, 
        signal_name, 
        signal_info.return_type, 
        (signal_info.parameter_types...), 
        false, 
        data)
  catch err
    warn(wpipe, "Signal connection failed; signal, $signal_name; handler, $handler_name")
    warn(wpipe, err)
  end

  nothing
end

"""
```julia
connect_signals(
    built::GtkBuilderLeaf,
    handlers::Dict{String, Function}, 
    userdata,
    passthrough::Function;
    wpipe=Base.STDERR)
```
Connects signals specified within a `GtkBuilder`. Internally calls
C function `gtk_builder_connect_signals_full`. Contains lots of
magic for connecting to functions.
* `built` - A `GtkBuilder` that the signals are connected for.
* `handlers` - A mapping between signal names and callbacks.
* `userdata` - The user provided data to be passed to the callbacks.
* `passthrough` - A generic function that covers requirements for passthrough
functionality.
"""
function connect_signals(
    built::GtkBuilderLeaf, 
    handlers::Dict{String, Function}, 
    userdata,
    passthrough::Function;
    wpipe=Base.STDERR)
  connector = cfunction(
      connect_signals_c_function, 
      Void, 
      (
          Ptr{GObject}, 
          Ptr{GObject},
          Ptr{UInt8},
          Ptr{UInt8},
          Ptr{GObject},
          Int,
          Ptr{Void}))
  ccall(
      (:gtk_builder_connect_signals_full, Gtk.libgtk),
      Void,
      (Ptr{GObject}, Ptr{Void}, Ptr{Void}), 
      built, 
      connector,
      pointer_from_objref(SignalConnectionData(handlers, userdata, wpipe, passthrough)))
end
