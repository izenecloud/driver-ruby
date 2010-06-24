jQuery(document).ready(function() {
  var request_editor = new jsonwidget.editor('request');
  request_editor.setView('form');
  var response_editor = new jsonwidget.editor('response');
  response_editor.setView('form');

  var tabs = $('#tabs').tabs();
  $('#tabs').bind('tabsselect', function(event, ui) {
    switch(ui.panel.id) {
    case "request":
      request_editor.setView('form');
      break;
    case "request-source":
      request_editor.setView('source');
      break;
    case "response":
      response_editor.setView('form');
      break;
    case "response-source":
      response_editor.setView('source');
      break;
    }
  });

  $('#request-send-button').button();

  $('#request-send-button').click(function() {
    $('#request-send-button').button("option", "disabled", true);
    $('.request-indicator').html('<img src="images/ajax-loader.gif" alt="sending ..." />');
    $('#error-container').hide();

    var jsondata = "{}";
    var jsonarea = $("#" + request_editor.htmlids.sourcetextarea);
    if (jsonarea.css("display") != "none") {
      jsondata = jsonarea.val();
      request_editor.setView("form");
    } else {
      jsondata = JSON.stringify(request_editor.jsondata);
    }

    $.ajax({
      url: 'sender',
      contentType: 'application/json',
      dataType: 'json',
      data: jsondata,
      type: 'POST',
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
    var request = $('#save-template-form [name=request]');
    request.val(JSON.stringify(request_editor.jsondata));

    return true;
  });

  $('#save-template-dialog').dialog({
    autoOpen: false,
	width: 600,
    modal: true,
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
    $('#save-template-dialog').dialog('open');
    return false;
  });
  $('#save-template-dialog-link').hover(
    function() { $(this).addClass('ui-state-hover'); },
    function() { $(this).removeClass('ui-state-hover'); }
  );

});
