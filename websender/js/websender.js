var Websender = function () {
  var parameters = jQuery.grep(window.location.hash.substring(1).split('/'), function(arg) {
    return arg != null && arg != '';
  });

  this.controller = parameters[0] || 'hello';
  this.action = parameters[1] || 'index';
  this.template = parameters[2] || 'default';

  this.request_editor = new jsonwidget.editor('request');
  this.request_editor.setView('form');
  this.response_editor = new jsonwidget.editor('response');
  this.response_editor.setView('form');

  this.selector = {
    controller: $('#controller'),
    action: $('#action'),
    template: $('#template')
  };

  this.bindChangeHandler();

  this.overlay = $('#page-overlay');
  this.overlay.dialog({
    autoOpen: false,
    modal: true,
    resizable: false,
    draggable: false,
    open: function(event, ui) { $('.ui-dialog-titlebar-close', $(this).parent()).hide(); },
    closeOnEscape: false
  });

  this.request_schema ='{"title":"Freeform JSON","type": "any"}';
  this.response_schema = '{"title":"Freeform JSON","type": "any"}';
  this.controllers = ['hello'];
  this.actions = ['index'];
  this.templates = {
    default: '{}'
  };
  this.request_description = '';

  this.loadSchema();
};

Websender.prototype.bindChangeHandler = function() {
  var sender = this;
  this.selector.controller.change(function() {
    sender.controller = $(this).val();
    sender.loadSchema();
  });
  this.selector.action.change(function() {
    sender.action = $(this).val();
    sender.loadSchema();
  });
  this.selector.template.change(function() {
    sender.template = $(this).val();
    sender.renderTemplate();
  });
};

Websender.prototype.loadSchema = function() {
  $('#page-overlay-message').text('Loading ...');
  this.overlay.dialog('option', 'title', 'Loading Schema ...');
  this.overlay.dialog('open');
  var sender = this;
  $.getJSON('schema/' + this.controller + '/' + this.action, null, function(resp) {
    $.each(resp, function(key, val) {
        sender[key] = val;
    });

    sender.renderSchema();
    sender.overlay.dialog('close');
  });
};

Websender.prototype.renderSchema = function () {
  var selector = this.selector;
  var controller = this.controller;
  var action = this.action;
  var template = this.template;

  selector.controller.html('');
  $.each(this.controllers, function(i, val) {
    var option = $('<option></option>').val(val).html(val);
    if (val == controller) {
      option.attr('selected', 'selected');
    }
    selector.controller.append(option);
  });

  selector.action.html('');
  $.each(this.actions, function(i, val) {
    var option = $('<option></option>').val(val).html(val);
    if (val == action) {
      option.attr('selected', 'selected');
    }
    selector.action.append(option);
  });

  selector.template.html('');
  $.each(this.templates, function(key, val) {
    var option = $('<option></option>').val(key).html(key);
    if (key == template) {
      option.attr('selected', 'selected');
    }
    selector.template.append(option);
  });

  $('#' + this.request_editor.htmlids.schematextarea).val(this.request_schema);
  $('#' + this.response_editor.htmlids.schematextarea).val(this.response_schema);

  this.request_description = '';
  try {
    this.request_description = JSON.parse(this.request_schema)['desc'];
    if (this.request_description == null) {
      this.request_description = '';
    }
  } catch (x) {
    // ignore
  }

  $('#request-description').text(this.request_description);

  this.renderTemplate();
};

Websender.prototype.renderTemplate = function () {
  window.location.hash = this.controller + '/' + this.action + '/' + this.template;

  this.selector.template.val(this.template);

  var template_content = this.templates[this.template] || '{}';
  $('#' + this.request_editor.htmlids.sourcetextarea).val(template_content);
  this.request_editor.toggleToFormActual();

  $('#' + this.response_editor.htmlids.sourcetextarea).val('{}');
  this.response_editor.toggleToFormActual();
};

Websender.prototype.getRequestJSON = function () {
  var jsondata = "{}";
  var jsonarea = $("#" + this.request_editor.htmlids.sourcetextarea);
  if (jsonarea.css("display") != "none") {
    jsondata = jsonarea.val();
    this.request_editor.toggleToFormActual();
  } else {
    jsondata = JSON.stringify(this.request_editor.jsondata);
  }

  return jsondata;
};

jQuery(document).ready(function() {
  var websender = new Websender;
  var request_editor = websender.request_editor;
  var response_editor = websender.response_editor;

  var tabs = $('#tabs').tabs();
  $('#tabs').bind('tabsselect', function(event, ui) {
    switch(ui.panel.id) {
    case 'request':
      request_editor.setView('form');
      break;
    case 'request-source':
      request_editor.setView('source');
      break;
    case 'response':
      response_editor.setView('form');
      break;
    case 'response-source':
      response_editor.setView('source');
      break;
    }
  });

  $('#request-send-button').button();

  $('#request-send-button').click(function() {
    $('#request-send-button').button("option", "disabled", true);
    $('.request-indicator').html('<img src="images/ajax-loader.gif" alt="sending ..." />');
    $('#error-container').hide();

    $.ajax({
      url: 'sender/' + websender.controller + '/' + websender.action,
      contentType: 'application/json',
      dataType: 'json',
      data: websender.getRequestJSON(),
      type: 'POST',
      error: function() {
        $('#error-messages').html('<p>Failed to send the request</p>');
        $('#error-container').show();
      },
      success: function(json) {
        response_editor.jsondata = json;

        if (json && json.errors && json.errors.length > 0) {
          var error_messages = "";
          for (var i = 0; i < json.errors.length; ++i) {
            error_messages += '<p>' + $('<p/>').text(json.errors[i]).html() + '<p>';
          }
          $('#error-messages').html(error_messages);
          $('#error-container').show();
        }

        response_editor.updateJSON();
        $('#request-send-button').button("option", "disabled", false);
        $('.request-indicator').html('');
        $('#response-tab-header').effect('highlight', 1500);
        tabs.tabs('select', '#response');
        response_editor.setView('form');
        $('#response').effect('highlight', 1500);
      }
    });
  });

  $('#save-template-form').submit(function() {
    $('#page-overlay-message').text('Saving ...');
    websender.overlay.dialog('option', 'title', 'Saving Template ...');
    websender.overlay.dialog('open');
    $('#error-container').hide();

    var name = $('#save-as-template').val();
    var url = 'schema/' + websender.controller + '/' + websender.action + '/' + name;
    var data = websender.getRequestJSON();

    $.ajax({
      url: url,
      contentType: 'application/json',
      dataType: 'json',
      data: data,
      type: 'POST',
      error: function() {
        $('#error-messages').html('<p>Failed to save the template</p>');
        $('#error-container').show();
        websender.overlay.dialog('close');
        $('#save-template-dialog').dialog('close');
      },
      success: function() {
        websender.templates[name] = data;
        websender.template = name;
        websender.renderSchema();
        websender.overlay.dialog('close');
        $('#save-template-dialog').dialog('close');
      }
    });

    return false;
  });

  $('#save-template-dialog').dialog({
    autoOpen: false,
	width: 600,
    modal: true,
    closeOnEscape: false,
	buttons: {
	  "Save": function() {
        $('#save-template-form').trigger('submit');
	  },
	  "Cancel": function() { 
	    $(this).dialog("close"); 
	  } 
	}
  });

  $('#save-template-dialog-link').click(function(){
    $('#save-as-template').val(websender.template);
    $('#save-template-dialog').dialog('open');
    return false;
  });
  $('#save-template-dialog-link').hover(
    function() { $(this).addClass('ui-state-hover'); },
    function() { $(this).removeClass('ui-state-hover'); }
  );

});
