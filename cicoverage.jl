cd(Pkg.dir("GtkBuilderAid"))
Pkg.add("Coverage")
using Coverage
# Push results to coveralls
Coveralls.submit(Coveralls.process_folder())
