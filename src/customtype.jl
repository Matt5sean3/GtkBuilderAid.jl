
# This tries to allow for registering custom types with the GTK type system

immutable GTypeValueTable
  value_init::Ptr{Void}
  value_free::Ptr{Void}
  value_copy::Ptr{Void}
  value_peek_pointer::Ptr{Void}
  collect_format::Ptr{UInt8}
  collect_value::Ptr{Void}
  lcopy_format::Ptr{UInt8}
  lcopy_value::Ptr{Void}
end

immutable GTypeInfo
  class_size::UInt16
  base_init::Ptr{Void}
  base_finalize::Ptr{Void}
  class_init::Ptr{Void}
  class_finalize::Ptr{Void}
  class_data::Ptr{Void}
  instance_size::UInt16
  n_preallocs::UInt16
  instance_init::Ptr{Void}
  value_table::Ptr{GTypeValueTable}
end

# Simple passthrough
g_type_register_static(
    parent_type::GType,
    type_name::AbstractString,
    info::GTypeInfo,
    flags::Cint) =
  ccall(
    (:g_type_register_static, Gtk.libgtk),
    GType,
    (GType, Ptr{UInt8}, Ref{GTypeInfo}, Cint),
    parent_type,
    type_name,
    info,
    flags)

immutable GParameter
  name::Ptr{UInt8}
  value::Gtk.GValue
end

abstract GTypePlugin

immutable GTypePluginClass
  use_plugin::Ptr{Void}
  unuse_plugin::Ptr{Void}
  complete_type_info::Ptr{Void}
  complete_interface_info::Ptr{Void}
end

immutable GTypeModule <: GTypePlugin
  # It's an opaque type
  # they keep the struct out of the documentation
end

g_object_new_by_name(name::Symbol, params...) =
  ccall(
    (:g_object_newv, Gtk.libgtk),
    Ptr{GObject},
    (GType, Cuint, Ptr{GParameter}),
    Gtk.g_type_from_name(name),
    length(params),
    GParameter[GParameter(param[1], param[2]) for param in params])

g_type_register_dynamic(
    parent_type::GType,
    type_name::AbstractString,
    plugin::GTypePlugin,
    flags::Cint) =
  ccall(
    (:g_type_register_dynamic, Gtk.libgtk),
    GType,
    (GType, Ptr{UInt8}, Ptr{Void}, Cint),
    parent_type,
    plugin,
    flags)

