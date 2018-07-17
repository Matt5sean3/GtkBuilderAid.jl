Pkg.clone(pwd())
Pkg.add("BinDeps")
using BinDeps
println(BinDeps.debug("Gtk"))
Pkg.build("GtkBuilderAid")
Pkg.test("GtkBuilderAid"; coverage = true)
