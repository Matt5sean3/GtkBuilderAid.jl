# Simple Example

This is a very basic example that demonstrates use of the `@GtkBuilderAid` macro.

## UI File

### `GtkApplicationWindow` widget

This widget is the top-level window for all the widgets in this example. It's an application window for improved compatibility with the `GtkApplication` object.

### `GtkBox` widget

This widget lays out the label and the set of buttons.

### `GtkLabel` widget

This widget shows "Hello World!" at the top of the widget box.

### `GtkButtonBox` widget

This widget lays out the buttons one next to the other.

### `GtkButton` - `ok_button` widget

When clicked, this button will print "OK clicked!" in the console. Connecting the `click_ok` handler to the widget's `clicked` signal achieves.

### `GtkButton` - `cancel_button` widget

When clicked, this button will close the window. Connecting the `close_window` handler to the widget's `clicked` signal achieves this.

## Julia File

### `click_ok` handler

This handler causes "OK clicked!" to be printed in the console.

```julia
@guarded function click_ok(
    widget, 
    app)
  println("OK clicked!")
  return nothing
end
```

### `close_window` handler

This handler causes the window to close.

```julia
@guarded function close_window(
    widget, 
    window)
  destroy(window)
  return nothing
end
```

### `activateApp` handler

This handler is used to perform start-up actions for the application such as constructing the `GtkBuilder` and showing the window. This handler is connected in the code, not the UI file.

```julia
@guarded function activateApp(widget, userdata)
  app, builder = userdata
  built = builder("resources/main.ui")
  win = Gtk.GAccessor.object(built, "main_window")
  push!(app, win)
  showall(win)
  return nothing
end
```

### Start-Up

During start-up the app is constructed with the identifier "io.github.matt5sean3.first", the activate handler is connected to the activate signal, and the app is started.

```julia
example_app = GtkApplication("io.github.matt5sean3.GtkBuilderAid.first", 0)
signal_connect(activateApp, example_app, :activate, Void, (), false, (example_app, builder))

println("Starting App")
run(example_app)
```
