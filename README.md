# GtkBuilderAid.jl
This package's functionality is very narrowly to enable creating Gtk GUIs using [Glade](https://glade.gnome.org/) and [Julia](http://julialang.org/) more simply than can be accomplished using only the [Julia interface to Gtk](https://github.com/JuliaLang/Gtk.jl). The main concept is to use the signal connection features of the GtkBuilder object as simply in Julia as they can be from C.

## Example

A simple example that matches up with the screenshotted GUI is displayed below.

### Julia Code

```julia
example_app = @GtkApplication("com.github.example", 0)

builder = @GtkBuilderAid userdata(example_app::GtkApplication) "resources/main.ui" begin

function click_ok(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    user_info::Ptr{UserData})
  println("OK clicked!")
  return 0
end

function quit_app(
    widget::Ptr{Gtk.GLib.GObject}, 
    user_info::Ptr{UserData})
  ccall((:g_application_quit, Gtk.libgtk), Void, (Gtk.GLib.GObject, ), user_info[1])
  return nothing::Void
end

function close_window(
    widget::Ptr{Gtk.GLib.GObject}, 
    evt::Ptr{Gtk.GdkEventButton}, 
    window_ptr::Ptr{Gtk.GLib.GObject})
  window = convert(Gtk.GObject, window_ptr)
  destroy(window)
  return 0
end

end

@guarded function activateApp(widget, userdata)
  app, builder = userdata
  built = builder()
  win = Gtk.GAccessor.object(built, "main_window")
  push!(app, win)
  showall(win)
  return nothing
end

signal_connect(activateApp, example_app, :activate, Void, (), false, (example_app, builder))

run(example_app)
```

All of the functions defined in the block starting with `builder = @GtkAidBuild` will be accessable as handlers from within Glade.

### Glade Design

Note how the handler for `click_ok` is filled out directly as `click_ok` to match the code above.

![Glade screenshot showing the application window](doc/resources/glade_example.png)

## Type Annotation
In order for this macro to work correctly, types must be fully annotated and there cannot be any ambiguity in the return type. A certain degree of type inference is built into this package, but is limited overall. In this way, all return expressions in a function that cannot be directly inferred need to be made explicit.

### Explicit Type Annotation

An example of an explicitly typed function is shown below. Most of the time the types annotated will be similar to those used in the [wrapper library's](https://github.com/JuliaLang/Gtk.jl), `signal_connect` function.

```julia
function click_ok(
    widget::Ptr{Gtk.GLib.GObject},
    evt::Ptr{Gtk.GdkEventButton},
    user_info::Ptr{UserData})
  println("OK Clicked")
  return 0::Int
end
```

Note especially, that Int, not Int64 or Int32, is used in this case because that type needs to vary depending on CPU architecture.


### Type Inference

Examining the code allows certain guesses to be performed. Basic types, such as integers and strings that can be identified as such with minimal work from within a macro are automatically determined. Ideally, with changes to the code, Julia's internal, far more advanced, type inference system could be used to determine the resulting return types. This allows the same function from above to be written a little more simply as shown.

```julia
function click_ok(
    widget::Ptr{Gtk.GLib.GObject},
    evt::Ptr{Gtk.GdkEventButton},
    user_info::Ptr{UserData})
  println("OK Clicked")
  return 0
end
```

There is currently no inference for argument types.

## Additional Considerations

### If Blocks
When an `if` statement is the final statement of a function block or an `if` statement is returned using the `return` keyword the resulting type can be ambiguous. When this situation arises either ensure that the `if` statement is not the returning expression or ensure that there is an `else` block that can be inferred to return the same type as the `if` block. This principle also extends through to `elseif` cases which will still need a concluding `else` block for inference purposes.

### Loop Blocks
Whenever a loop block such as `for` or `while` is used they will always return `Void()` which can be accurately inferred by this package.

### Void() != nothing
The `nothing` keyword can be overwritten to a different value than `Void()`. This means that even though `nothing` is generally considered to be the `Void` singleton that's not necessarily an accurate assumption. This means that even when `nothing` is returned directly annotation is still necessary.

### `@guarded` macro

The `@guarded` macro is not currently supported within this wrapper, which is a major drawback. Work will be done to rectify this problem sooner rather than later.

### Nested Blocks

Only functions defined at the level of the block within the macro will be converted to cfunctions and be enabled as signals. This is partly to give a means to define functions

### Functions Defined Using Shorthand

Functions defined using the equals operator will not be converted to cfunctions or be accessible as signal handlers. This will probably change in future versions so don't depend upon this behaviour.

### Multiple Function Methods

Functions defined with multiple methods are allowable within Julia but introduce ambiguity when interacting with C. For this reason, defining multiple methods for the same function is disallowed within the macro.

### Argument Type Assumptions

The first and final argument types of a callback can usually be guessed without a problem, which is what the Gtk wrapper does internally for `signal_connect`. Similarly, adding this assumption would make this package more user friendly and better in-line with the Gtk wrapper library.

