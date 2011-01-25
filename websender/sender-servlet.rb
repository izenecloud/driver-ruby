require "rubygems"
require "sf1-driver"
require "json"
require "webrick"
include WEBrick

class SenderServlet < HTTPServlet::AbstractServlet

  def do_POST(req, resp)
    error_message = {
      "header" => {
        "success" => false
      },
      "errors" => []
    }
    response_message = nil

    begin
      request_message = JSON.load req.body

      if request_message.is_a? Hash

        uri = request_message["uri"]
        if request_message["uri"].nil?
          uri = req.path_info
        end
        uri = uri.strip

        if uri and !uri.empty?
          response_message = sf1.call uri, request_message, req["X_IZENESOFT_ACL_TOKENS"]
        else
          error_message["errors"] << "Require uri."
        end

      else
        error_message["errors"] << "Request must be an Object"
      end

    rescue => e
      error_message["errors"] << "Exception: #{e}"
    end

    if response_message.nil?
      response_message = error_message
    end

    resp['content-type'] = 'application/json'
    resp.body = response_message.to_json
    raise HTTPStatus::OK
  end

  def sf1
    @sf1 ||= Sf1Driver.new(CONFIG[:BA][:IP], CONFIG[:BA][:Port])
  end
  
end
