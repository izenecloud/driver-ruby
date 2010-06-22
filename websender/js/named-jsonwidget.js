jsonwidget.named_editor = function (name) {
  this.editor = new jsonwidget.editor();
  this.editor.htmlids = {
    "warningdiv": name + "_warningdiv",
    "formdiv": name + "_formdiv",
    "schemaformdiv": name + "_schemaformdiv",
    "sourcetextarea": name + "_sourcetextarea",
    "schematextarea": name + "_schematextarea",
    "schemaschematextarea": name + "_schemaschematextarea",
    "byexamplebutton": name + "_byexamplebutton",
    "sourcetextform": name + "_sourcetextform"
  };
  this.editor.htmlbuttons = {
    form: name + "_formbutton",
    source: name + "_sourcebutton",
    schemasource: name + "_schemasourcebutton",
    schemaform: name + "_schemaformbutton"
  };

  this.editor.formdiv = document.getElementById(
    this.editor.htmlids.formdiv
  );

  this.editor.setView('form');
};

function load_editors() {
  var args = arguments;
  for (var i = 0; i < args.length; ++i) {
    var editor = new jsonwidget.named_editor(arguments[i]);
  }
}
