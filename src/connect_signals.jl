
immutable GSignalQuery
  signal_id::Cuint
  signal_name::Ptr{Int8}
  itype::Gtk.GType
  signal_flags::Gtk.GEnum
  return_type::Gtk.GType
  n_params::Cuint
  param_types::Ptr{Gtk.GType}
end

immutable SignalInfo
  itype::Type
  return_type::Type
  parameter_types::Array{Type}
end

# Not all types were already covered so add in an auxiliary case
const more_types = Dict{Symbol, Type}(
  :GdkEvent => Ptr{Gtk.GdkEvent},
  :GdkEventButton => Ptr{Gtk.GdkEventButton});

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

function query_signal(obj::GObject, signal_name::Compat.String)
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
  return SignalInfo(
    gtype_to_jtype(result[].itype),
    gtype_to_jtype(result[].return_type),
    [gtype_to_jtype(gtype) for gtype in unsafe_wrap(Array,
      result[].param_types, 
      result[].n_params)])
end

type SignalConnectionData
  handlers::Dict{Compat.String, Function}
  data
  warn_pipe::IO
  passthrough::Function
end

type PassthroughData{T, O, P}
  ret_type::Type{T}
  object_type::Type{O}
  func::Ptr{Void}
  data::P
end

# A cfunction to configure connections
# The cfunction version runs but the julia version doesn't
function connectSignalsCFunction(
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

function connectSignals(
    built::GtkBuilderLeaf, 
    handlers::Dict{Compat.String, Function}, 
    userdata,
    passthrough::Function;
    wpipe=Base.STDERR)
  connector = cfunction(
      connectSignalsCFunction, 
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
