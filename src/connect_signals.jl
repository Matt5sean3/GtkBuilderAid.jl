
immutable GSignalQuery
  signal_id::Cuint
  signal_name::Ptr{Int8}
  itype::Gtk.GLib.GType
  signal_flags::Gtk.GLib.GEnum
  return_type::Gtk.GLib.GType
  n_params::Cuint
  param_types::Ptr{Gtk.GLib.GType}
end

immutable SignalInfo
  itype::Type
  return_type::Type
  parameter_types::Array{Type}
end

function gtype_to_jtype(t::Gtk.GLib.GType)
  for (i, id) in enumerate(Gtk.GLib.fundamental_ids)
    if id == t
      return Gtk.GLib.fundamental_types[i][2]
    end
  end
  typename = Gtk.GLib.g_type_name(t)
  if typename in keys(Gtk.GLib.gtype_wrappers)
    return Ptr{Gtk.GLib.gtype_abstracts[typename]}
  end
  return Ptr{Void}
end

function query_signal(obj::GObject, signal_name::ByteString)
  obj_class = Gtk.GLib.G_OBJECT_CLASS_TYPE(obj)
  signal_id = ccall(
    (:g_signal_lookup, Gtk.GLib.libgobject),
    Cuint,
    (Ptr{Int8}, Gtk.GLib.GType),
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
    [gtype_to_jtype(gtype) for gtype in pointer_to_array(
      result[].param_types, 
      result[].n_params)])
end

type SignalConnectionData
  handlers::Dict{AbstractString, Function}
  data
end

# A cfunction to configure connections
@guarded function connectSignalsCFunction(
    builder, 
    object_ptr, 
    signal_name_ptr, 
    handler_name_ptr, 
    connect_object_ptr, 
    flags, 
    userdata_ptr)
  userdata = unsafe_pointer_to_objref(userdata_ptr)

  handler_name = bytestring(handler_name_ptr)
  handler = userdata.handlers[handler_name]
  
  object = Gtk.GLib.GObject(object_ptr)
  signal_name = bytestring(signal_name_ptr)
  signal_info = query_signal(object, signal_name)
  if connect_object_ptr == C_NULL
    # Use the provided 

    signal_connect(
        handler, 
        object, 
        signal_name, 
        signal_info.return_type, 
        (signal_info.parameter_types...), 
        false, 
        userdata.data)
  else
    # Connect the objects directly
    argument_array = copy(signal_info.parameter_types)
    unshift!(argument_array, Ptr{Gtk.GObject})
    push!(argument_array, Ptr{Gtk.GObject})
    argument_types = tuple(argument_array...)
    ccall(
        (:g_signal_connect_object, Gtk.libgtk),
        Culong,
        (
          Ptr{Gtk.GLib.GObject}, 
          Ptr{UInt8}, 
          Ptr{Void}, 
          Ptr{Gtk.GLib.GObject}, 
          Gtk.GEnum),
        object_ptr,
        signal_name_ptr,
        cfunction(handler, signal_info.return_type, argument_types),
        connect_object_ptr,
        flags)
  end

  return nothing
end

function connectSignals(
    built::GtkBuilderLeaf, 
    handlers::Dict{ByteString, Function}, 
    userdata)
  connector = cfunction(
      connectSignalsCFunction, 
      Void, 
      (
          Ptr{Gtk.GLib.GObject}, 
          Ptr{Gtk.GLib.GObject},
          Ptr{UInt8},
          Ptr{UInt8},
          Ptr{Gtk.GLib.GObject},
          Int,
          Ptr{Void}))
  ccall(
      (:gtk_builder_connect_signals_full, Gtk.libgtk),
      Void,
      (Ptr{Gtk.GLib.GObject}, Ptr{Void}, Ptr{Void}), 
      built, 
      connector,
      pointer_from_objref(SignalConnectionData(handlers, userdata)))
end
