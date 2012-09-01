task("default", ["lint"]);


desc("Lint");
task("lint", [], function() {
  var lint = require();

  var files = new jake.FileList();
  files.include('**/*.js');
  lint.validateFileList(files.toArray)
});
