
function test_macro_throws(error_type, macroexpr)
  expansion = macroexpand(macroexpr)
  if expansion.head != :error
    warn("Expansion did not throw error")
    println(expansion)
    @test false
  end
  if !isa(expansion.args[1], error_type)
    warn("Expansion threw wrong error")
    warn("Expected: $error_type")
    warn("Got: $(expansion.args[1])")
    dump(expansion)
    @test false
  end
end

test_macro_throws(TypeError, quote 
@GtkBuilderAid helloSymbol
end)

test_macro_throws(ArgumentError, quote
@GtkBuilderAid helloExpr()
end)

test_macro_throws(ArgumentError, quote 
@GtkBuilderAid 
end)

test_macro_throws(ErrorException, quote
@GtkBuilderAid symbolDirective begin
end
end)

test_macro_throws(ErrorException, quote
@GtkBuilderAid badexpr::Directive begin
end
end)

test_app = @GtkApplication("com.github.test_gtkbuilderaid", 0)

# Try out known userdata with 
long_builder = @GtkBuilderAid begin

function click_ok(
    widget, 
    user_info)
  println("OK clicked!")
  return nothing
end

function quit_app(
    widget, 
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info)
  return nothing
end

function close_window(
    widget, 
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing
end

end

@test_throws MethodError long_builder()
long_builder("resources/nothing.ui", test_app)

# Show the expanded macro
# Mostly check that this succeeds
builder = @GtkBuilderAid userdata(test_app) "resources/nothing.ui" begin

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

function quit_app(
    widget,
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info)
  return nothing
end

function close_window(
    widget,
    window)
  destroy(window)
  return nothing
end

end

builder()
# Also check that the unbound form works
builder("$(Pkg.dir("GtkBuilderAid"))/test/resources/nothing.ui")

tuple_builder = @GtkBuilderAid userdata_tuple(test_app::GtkApplication) "resources/nothing.ui" begin

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

function quit_app(
    widget, 
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  return nothing
end

function close_window(
    widget,
    window)
  destroy(window)
  return nothing
end

end

# check again but with an explicit name for the builder function
@GtkBuilderAid function_name(build_nothing) userdata(test_app::GtkApplication) "resources/nothing.ui" begin

function close_window(
    widget,
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing
end

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

end
build_nothing()

# Test non-string file arguments
base_method_builder = @GtkBuilderAid begin

function close_window(
    widget,
    window)
  window = Gtk.GLib.GObject(window)
  destroy(window)
  return nothing
end

function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing
end

end

@test_throws MethodError base_method_builder()
# Should succeed
base_method_builder("resources/nothing.ui")

# Test non-existent files
test_macro_throws(ErrorException, quote
@GtkBuilderAid "resources/nonexistentfile.ui" begin

function close_window(
    widget,
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing
end

end
end)

expanding_builder = @GtkBuilderAid begin

@guarded function close_window(
    widget,
    window_ptr)
  window = Gtk.GLib.GObject(window_ptr)
  destroy(window)
  return nothing::Void
end

@guarded function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing::Void
end

end
expanding_builder("resources/nothing.ui")

@test_throws ErrorException builder("resources/nonexistant.ui")

# Test that issues can arise with expansion

# run(test_app)

