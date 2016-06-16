
using GtkBuilderAid
import GtkBuilderAid: FunctionDeclaration
# Function inference from code analysis is somewhat difficult
# The system here aims at determining the type as it would be in C
# Hopefully typealiases don't give terrible issues
test_buffer = IOBuffer()
test_str = bytestring("test error")
Base.showerror(test_buffer, InferenceException(test_str))
bytestring(test_buffer.data) == test_str

macro test_macro(args...)
  # mostly, test that the return and argument types are correctly inferred
  function_expr = args[end]
  if args[1] == :throws
    @test_throws InferenceException declaration = FunctionDeclaration(function_expr)
  else
    function_name = args[1]
    return_type = args[2]
    declaration = FunctionDeclaration(function_expr)
    @test declaration.function_name == args[1]
    @test declaration.return_type == args[2]
    @test declaration.argument_types == [arg::Union{Symbol, Expr} for arg in args[3:end - 1]]
  end
  return esc(function_expr)
end

@test_throws InferenceException GtkBuilderAid.functionName(:(tups{hello}))
@test_throws InferenceException GtkBuilderAid.functionName(:(hello, 5, 6))
@test_throws InferenceException GtkBuilderAid.arguments(:(tupe{hello}))
@test_throws InferenceException GtkBuilderAid.blockReturnType(quote 
  return 0
  return 0.0
end)

@test GtkBuilderAid.explicitBlockReturnType(quote 
  return 0
  return 0.0
end) == Set([symbol(Int), :Float64])
@test GtkBuilderAid.explicitBlockReturnType(quote 
  if a > 1
    return 0
  end
  return 0.0
end) == Set([symbol(Int), :Float64])
@test GtkBuilderAid.explicitBlockReturnType(quote 
  if a > 1
    return 0
  else
    return 0.0
  end
end) == Set([symbol(Int), :Float64])
@test GtkBuilderAid.explicitBlockReturnType(quote 
  while a > 1
    return 0
  end
  return 0.0
end) == Set([symbol(Int), :Float64])

@test GtkBuilderAid.explicitBlockReturnType(quote 
  try
    return 0
  catch
    return 0.0
  end
end) == Set([symbol(Int), :Float64])
@test_throws InferenceException GtkBuilderAid.exprResultType(Expr(:brokenexpr))

# Only infers about functions
@test_throws InferenceException FunctionDeclaration(:(tupe{hello}))
@test_macro throws begin
  # NOP
end

@test_macro noBody Void function noBody()
end
noBody()

@test_macro tryNoCatch Void function tryNoCatch()
  try
    Void()::Void
  end
end
tryNoCatch()

# @test_macro tryWithCatch Int function tryWithCatch()
#   try
#     0
#   catch e
#     1
#   end
# end
# 
@test_macro throws function tryNoCatchMismatch()
  try
    0
  end
end

@test_macro throws function tryCatchMismatch()
  try
    0
  catch
    0.0
  end
end

# Constant explicit return
@test_macro directReturn1 Bool function directReturn1()
  return true
end
@test directReturn1()

# Annotated explicit return
@test_macro directReturn2 Bool function directReturn2()
  return true::Bool
end
@test directReturn2()

# Annotated implicit return
@test_macro directReturn3 Bool function directReturn3()
  true::Bool
end
@test directReturn3()

# Constant implicit return
@test_macro directReturn4 Bool function directReturn4()
  true
end
@test directReturn4()

# # Explicit return in an if block
@test_macro positiveNegative1 Bool Int function positiveNegative1(value::Int)
  if value >= 0
    return true
  else
    return false
  end
end
@test positiveNegative1(5)
@test !positiveNegative1(-5)

# Implicit return in an if block
@test_macro positiveNegative2 Bool Int function positiveNegative2(value::Int)
  if value > 0
    true
  else
    false
  end
end
@test positiveNegative2(5)
@test !positiveNegative2(-5)

# If block void return type
@test_macro positiveNegative2 Void Int function positiveNegative2(value::Int)
  if value > 0
    nothing::Void
  end
end

# Multiple explicit return type issues
@test_macro throws function positiveNegative3(value::Int)
  if value > 0
    return 0
  else
    return false
  end
end

# Differing return type if block
@test_macro throws function positiveNegative4(value::Int)
  if value > 0
    true
  else
    0
  end
end

@test_macro throws function positiveNegative5(value::Int)
  if value > 0
    true
  end
end

# Can't directly infer, needs annotation
@test_macro positiveNegative3 Bool Int function positiveNegative3(value::Int)
  return (value > 0)::Bool
end
@test positiveNegative3(5)
@test !positiveNegative3(-5)

# Explicit return value with annotation
@test_macro factorial1 Int Int function factorial1(value::Int)
  ret = 1
  for i in 2:value
    ret *= i
  end
  return ret::Int
end
@test factorial1(5) == 2 * 3 * 4 * 5

# Implicit return value with annotation
@test_macro factorial2 Int Int function factorial2(value::Int)
  ret = 1
  for i in 2:value
    ret *= i
  end
  ret::Int
end
@test factorial2(5) == 2 * 3 * 4 * 5

@test_macro lastFor Void Int function lastFor(cycles::Int)
  j = 0
  for i in 1:cycles
    j = i + 1
  end
end

@test_macro lastWhile Void Int function lastWhile(cycles::Int)
  j = 0
  while j < cycles
    j = j + 1
  end
end

# Test decoding the functions we actually use
@test_macro close_window Void Ptr{Gtk.GLib.GObject} Ptr{Gtk.GLib.GObject} function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    window::Ptr{Gtk.GLib.GObject})
  destroy(window)
  nothing::Void
end

@test_macro quit_app Void Ptr{Gtk.GLib.GObject} Ptr{Tuple{Gtk.GtkApplication}} function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::Ptr{Tuple{Gtk.GtkApplication}})
  ccall((:g_application_quit, Gtk.libgtk), Void, (Ptr{Gtk.GLib.GObject}, ), user_info[1])
  return nothing::Void
end

# Test that just returning a symbol isn't working
@test_macro throws function bad_quit_app(
    widget::Ptr{Gtk.GLib.GObject},
    user_info::Ptr{Tuple{Gtk.GtkApplication}})
  ccall((:g_application_quit, Gtk.libgtk), Void, (Ptr{Gtk.GLib.GObject}, ), user_info[1])
  return nothing
end

# Returning directly from calls without annotation is also an issue
@test_macro throws function bad_quit_app2(
    widget::Ptr{Gtk.GLib.GObject},
    user_info::Ptr{Tuple{Gtk.GtkApplication}})
  ccall((:g_application_quit, Gtk.libgtk), Void, (Ptr{Gtk.GLib.GObject}, ), user_info[1])
  return Void()
end

