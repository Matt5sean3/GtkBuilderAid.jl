
import GtkAppAid: FunctionDeclaration
# Function inference from code analysis is somewhat difficult
# The system here aims at determining the type as it would be in C
# Hopefully typealiases don't give terrible issues

macro test_macro(args...)
  # mostly, test that the return and argument types are correctly inferred
  function_name = args[1]
  return_type = args[2]
  argument_types = [arg::Union{Symbol, Expr} for arg in args[3:end - 1]]
  function_expr = args[end]
  declaration = FunctionDeclaration(function_expr)
  @test declaration.function_name == function_name
  @test declaration.return_type == return_type
  @test declaration.argument_types == argument_types
  return esc(function_expr)
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

# Test decoding the functions we actually use
@test_macro close_window Void Ptr{Gtk.GLib.GObject} Ptr{Gtk.GLib.GObject} function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    window::Ptr{Gtk.GLib.GObject})
  destroy(window)
  nothing::Void
end

# Inference on this is much harder
# The *= method could be overriden
# @test_macro factorial3 Int Int function factorial3(value::Int)
#   ret = 1
#   for i in 2:value
#     ret *= i
#   end
#   return ret
# end

