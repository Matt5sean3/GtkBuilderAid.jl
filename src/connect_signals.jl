
immutable FunctionInfo
  func::Function
  return_type::Type
  argument_types::Array{Type}
end

type SignalConnectionData
  handlers::Dict{AbstractString, FunctionInfo}
  data
end

# A cfunction to configure connections
function connectSignalsCFunction(
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
  
  if connect_object_ptr == C_NULL
    # Use the provided 
    object = Gtk.GLib.GObject(object_ptr)
    signal_name = bytestring(signal_name_ptr)

    signal_connect(
        handler.func, 
        object, 
        signal_name, 
        handler.return_type, 
        (handler.argument_types[2:end - 1]...), 
        false, 
        userdata.data)
  else
    # Connect the objects directly
    handler.argument_types[1] = Ptr{Gtk.GLib.GObject}
    handler.argument_types[end] = Ptr{Gtk.GLib.GObject}
    ccall(
        (:g_signal_connect_object, Gtk.libgtk),
        Culong,
        (Ptr{Gtk.GLib.GObject}, Ptr{UInt8}, Ptr{Void}, Ptr{Gtk.GLib.GObject}, Gtk.GEnum),
        object_ptr,
        signal_name_ptr,
        cfunction(handler.func, handler.return_type, (handler.argument_types...)),
        connect_object_ptr,
        flags)
  end

  return nothing
end

function connectSignals(
    built::GtkBuilderLeaf, 
    handlers::Dict{ByteString, FunctionInfo}, 
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
