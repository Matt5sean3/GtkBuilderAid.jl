# GtkBuilderAid.jl
[![Build Status](https://travis-ci.org/Matt5sean3/GtkBuilderAid.jl.svg?branch=master)](https://travis-ci.org/Matt5sean3/GtkBuilderAid.jl)
[![Coverage Status](https://coveralls.io/repos/github/Matt5sean3/GtkBuilderAid.jl/badge.svg?branch=master)](https://coveralls.io/github/Matt5sean3/GtkBuilderAid.jl?branch=master)

This package's functionality is very narrowly to enable creating Gtk GUIs using [Glade](https://glade.gnome.org/) and [Julia](http://julialang.org/) more simply than can be accomplished using only the [Julia interface to Gtk](https://github.com/JuliaLang/Gtk.jl). The main concept is to use the signal connection features of the GtkBuilder object as simply in Julia as they can be from C.

## Example

A simple example that matches up with the screenshotted GUI is displayed below.

### Julia Code

```julia
example_app = @GtkApplication("com.github.example", 0)

builder = @GtkBuilderAid userdata(example_app::GtkApplication) "resources/main.ui" begin

@guarded function click_ok(
    widget, 
    user_info)
  println("OK clicked!")
  return nothing
end

@guarded function quit_app(
    widget,
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Ptr{GObject}, ), user_info)
  return nothing
end

@guarded function close_window(
    widget,
    window)
  destroy(window)
  return nothing
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

## User Data Choices

The arguments to the macro preceding the filename and code block generally refine how the macro should behave. The most important of these directives are the user data directives of which there are four. However, user data may also be set within glade using the `User data` field in the `Signals` tab of the widget properties.

### `userdata`

The `userdata` directive takes the form shown in the earlier code block. The default user data is given as the first argument and is annotated with the type for user data.

### `userdata_tuple`

This is a shorthand for using a tuple as the user data type. This directive follows a form similar to the `userdata` directive except that all the arguments are bundled into a tuple with the type determined by the annotated types of the several arguments. As an example, `userdata_tuple(example_app, example_int)` would provide a tuple with `example_app` as the first element and `example_int` as the second element as the default user data.

### Glade User data

In cases where the user data is set in glade, the user data type will be a `GObject`. In the code block above this is demonstrated with the `close_window` function which will receive the window GObject as its user data argument.

## Runtime UI File Selection
The example above could be rewritten slightly to enable selecting the either or both of the filename or userdata at runtime instead of at compile time. Choosing the UI file will usually be preferable for the improved flexibility that it provides. Additionally, a name chosen at compile time cannot be computed, it can only be a string constant or the macro will ignore it. Even when the filename and userdata options are set for the macro the method allowing selection of the UI file and userdata will still be available. However, the types for the userdata must still be available at compile time.

```julia
example_app = @GtkApplication("com.github.example", 0)

builder = @GtkBuilderAid begin

@guarded function click_ok(
    widget,
    user_info)
  println("OK clicked!")
  return nothing::Void
end

@guarded function quit_app(
    widget,
    user_info)
  ccall((:g_application_quit, Gtk.libgtk), Void, (Ptr{GObject}, ), user_info)
  return nothing::Void
end

@guarded function close_window(
    widget,
    window)
  destroy(window)
  return nothing::Void
end

end

@guarded function activateApp(widget, userdata)
  app, builder = userdata
  built = builder("$(Pkg.dir("*your_package*"))/resources/main.ui", (app, ))
  win = Gtk.GAccessor.object(built, "main_window")
  push!(app, win)
  showall(win)
  return nothing
end

signal_connect(activateApp, example_app, :activate, Void, (), false, (example_app, builder))

run(example_app)
```

## Additional Considerations

### Macros

Some macros at the first layer of the block processed by the `@GtkBuilderAid` macro are manually expanded during analysis of that block. The expansion will be kept and added to the list of signals in the case that the expanded expression is a function definition. Macros that don't result in function definitions will be left to expand as they would have otherwise. This expansion works well enough for simple macros such as the Gtk wrapper library's `@guarded` macro but has the potential to cause complications in more complex macros.

### Nested Blocks

Only functions defined at the level of the block within the macro will be converted to cfunctions and be enabled as signals. This is partly to give a means to define functions that won't be used as functions.

### Multiple Dispatch

Multiple dispatch should work correctly if multiple methods with different arguments are defined.

