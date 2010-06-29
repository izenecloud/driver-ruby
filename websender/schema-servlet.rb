require "rubygems"
require "webrick"
include WEBrick

class SchemaServlet < HTTPServlet::AbstractServlet
  DEFAULT_SCHEMA = {
    :request_schema => '{"title":"Freeform JASON","type": "any"}',
    :response_schema => '{"title":"Freeform JSON","type": "any"}'
  }

  def do_GET(req, resp)
    controller, action, template = req.path_info.split("/").reject {|s| s.nil?||s.empty?}

    resp['content-type'] = 'application/json'
    resp_object = {}

    resp_object[:controllers] = controllers
    controller = resp_object[:controllers].first if controller.nil?

    resp_object[:actions] = actions(controller)
    if action.nil? or !resp_object[:actions].include?(action)
      if resp_object[:actions].include? "index"
        action = "index"
      else
        action = resp_object[:actions].first
      end
    end

    resp_object.merge! schema(controller, action)
    resp_object[:templates] = templates(controller, action);
    if template.nil? or !resp_object[:templates].key? template
      template = "default"
    end

    resp_object.merge!({
      :controller => controller,
      :action => action,
      :template => template
    })

    resp.body = resp_object.to_json

    raise HTTPStatus::OK
  end

  def do_POST(req, resp)
    resp['content-type'] = 'application/json'

    controller, action, template = req.path_info.split("/").reject {|s| s.nil?||s.empty?}
    template_file = File.join(SCHEMA_DIR, controller, action, "template.#{template}.json")

    begin
      File.open(template_file, 'w') do |f|
        f.flock File::LOCK_EX
        f.write req.body
      end
    rescue => e
      resp.body = {:message => e.to_s}.to_json
      raise HTTPStatus::Forbidden
    end

    resp.body = {:message => "Success"}.to_json
    raise HTTPStatus::OK
  end

  def controllers
    dirs = Dir[File.join(SCHEMA_DIR, "*")].select do |dir|
      File.directory? dir and File.basename(dir) != "ref"
    end
    if dirs.empty?
      ["freeform"]
    else
      dirs.map {|dir| File.basename(dir)}
    end
  end

  def actions(controller)
    dirs = Dir[File.join(SCHEMA_DIR, controller, "*")].select do |dir|
      File.directory? dir
    end
    if dirs.empty?
      ["index"]
    else
      dirs.map {|dir| File.basename(dir)}
    end
  end

  def templates(controller, action)
    found_templates = {"default" => "{}"}
    Dir[File.join(SCHEMA_DIR, controller, action, "template.*.json")].map do |f|
      template_content = "{}"
      template_content = File.read(f) rescue nil
      template_name = File.basename(f).sub(/^template\./, "").sub(/\.json$/, "")
      found_templates[template_name] = template_content
    end

    return found_templates
  end

  def schema(controller, action)
    loaded_schema = DEFAULT_SCHEMA
    selected_schema_dir = File.join(SCHEMA_DIR, controller, action)

    request_schema_file = File.join(selected_schema_dir, "request.json")
    if File.exist? request_schema_file
      loaded_schema[:request_schema] = File.read(request_schema_file) rescue nil
    end
    loaded_schema[:request_schema] = replace_ref loaded_schema[:request_schema]
    
    response_schema_file = File.join(selected_schema_dir, "response.json")
    if File.exist? response_schema_file
      loaded_schema[:response_schema] = File.read(response_schema_file) rescue nil
    end
    loaded_schema[:response_schema] = replace_ref loaded_schema[:response_schema]

    return loaded_schema
  end

  def replace_ref(schema)
    schema.sub /#\{([^}]+)\}/ do |match|
      begin
        file = File.join(SCHEMA_DIR, 'ref', "#{$1}.json")
        File.read(file)
      rescue
        match
      end
    end
  end
end
