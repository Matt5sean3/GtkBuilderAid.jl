
export InferenceException

type InferenceException <: Exception
  str
end

Base.showerror(io::IO, err::InferenceException) = print(io, err.str)

function replaceSymbol!(expr::Expr, symbol::Symbol, replacement)
  # recursive symbol replacement
  for (i, arg) in enumerate(expr.args)
    if typeof(arg) <: Expr
      # recurse
      replaceSymbol!(arg, symbol, replacement)
    elseif arg == symbol
      # replace
      expr.args[i] = replacement
    end
  end
end

function exprResultType(expr)
  # TODO Use the internal type inference features instead of rolling my own
  exprtype = typeof(expr)
  if exprtype <: Symbol
    throw(InferenceException("Cannot determine type of Symbols directly"))
  elseif exprtype <: Expr
    result = nothing
    if expr.head == :(::)
      # Directly annotated, makes life much easier
      result = expr.args[2]
    elseif expr.head == :call
      throw(InferenceException("Cannot determine return type of call directly"))
    elseif expr.head == :return
      result = exprResultType(expr.args[1])
    elseif expr.head == :if
      # Needs to get the result from the block
      true_block_type = exprResultType(expr.args[2])
      false_block_type = nothing
      if length(expr.args) < 3
        false_block_type = :Void
      else
        false_block_type = exprResultType(expr.args[3])
      end
      if true_block_type != false_block_type
        throw(InferenceException("The if blocks provide differing result types"))
      end
      result = true_block_type
    elseif expr.head == :while || expr.head == :for
      # while and for always return void
      result = :Void
    elseif expr.head == :try
      try_type = exprResultType(expr.args[1])
      catch_type = exprResultType(expr.args[3])
      if try_type != catch_type
        throw(InferenceException("The try-catch blocks provide differing result types"))
      end
      result = :Void
    elseif expr.head == :block
      # Filter out line expressions
      block_args = []
      for arg in expr.args
        if !isa(arg, Expr) || arg.head != :line
          push!(block_args, arg)
        end
      end
      if length(block_args) == 0
        # An empty block returns void
        result = :Void
      else
        # Blocks evaluate to their final argument
        result = exprResultType(block_args[end])
      end
    end
    # expr.typ = eval(result)
    if(result == nothing)
      throw(InferenceException("Did not retrieve a result type: $(expr)"))
    end
    return result
  else
    # constants aren't too hard
    return Symbol(string(exprtype))
  end
end

function explicitBlockReturnType(block::Expr, line = 0)
  # Finds all the return statements
  # Potentially multiple types in certain cases
  # Uses some nice recursion magic to descend into sub-blocks
  types = Set{Symbol}()
  for arg in block.args
    if typeof(arg) <: Expr
      if arg.head == :return
        push!(types, exprResultType(arg.args[1]))
      elseif arg.head == :block
        union!(types, explicitBlockReturnType(arg))
      elseif arg.head == :if
        union!(types, explicitBlockReturnType(arg.args[2]))
        if length(arg.args) > 2
          union!(types, explicitBlockReturnType(arg.args[3]))
        end
      elseif arg.head == :while || arg.head == :for
        union!(types, explicitBlockReturnType(arg.args[2]))
      elseif arg.head == :try
        # recurse in search of return type
        union!(types, explicitBlockReturnType(arg.args[1]))
        union!(types, explicitBlockReturnType(arg.args[3]))
      end
    end
  end
  return types
end

function blockReturnType(block)
  rts = explicitBlockReturnType(block)
  push!(rts, exprResultType(block))
  if length(rts) != 1
    throw(InferenceException("ERROR: Failed to determine return type"))
  else
    return collect(rts)[1]
  end
end

function functionName(call_expr::Expr)
  if call_expr.head != :call
    throw(InferenceException("Malformed function declaration"))
  end
  call_expr.args[1]::Symbol
end

function arguments(call_expr::Expr, line = 0)
  if call_expr.head != :call
    throw(InferenceException("Malformed function declaration, $line"))
  end
  call_expr = copy(call_expr)
  call_expr.head = :tuple
  shift!(call_expr.args)
  return call_expr
end

function argumentTypes(call_expr, line = 0)
  args = arguments(call_expr)
  fargtypes = Array{Union{Expr, Symbol}, 1}()
  for entry in call_expr.args[2:end]
    push!(fargtypes, exprResultType(entry))
  end
  return fargtypes
end

type FunctionDeclaration
  function_name::Symbol
  return_type::Union{Symbol, Expr}
  argument_types::Array{Union{Expr, Symbol}, 1}
  function FunctionDeclaration(function_expr::Expr)
    if function_expr.head != :function && function_expr.head != :(==)
      throw(InferenceException("ERROR: getting declaration of non-function expression"))
    end
    fcall = function_expr.args[1]::Expr
    fblock = function_expr.args[2]::Expr

    fname = functionName(fcall)
    fargtypes = argumentTypes(fcall)
    frtype = blockReturnType(fblock)

    return new(fname, frtype, fargtypes)
  end
end
