# SF1 Driver Ruby #

## Installation ##

Add `lib` directory to environment variable `RUBYLIB` or ruby global
environment `$LOAD_PATH`. Or, which is recommended, install the gem:

    rake gem
    gem install pkg/sf1-driver-${VERSION}.gem
    
(Replace ${VERSION} to the latest version. You many need root privileges to
install the gem in system path)

## Usage ##

[RDoc](https://git.izenesoft.cn/sf1-revolution/driver-docs/blobs/raw/master/html/ruby-client/index.html)

[Driver Specification](https://git.izenesoft.cn/sf1-revolution/driver-docs/blobs/raw/master/html/index.html)

### Create Driver Client ###

    require 'sf1-driver
    sf1 = Sf1Driver.new(ba_ip, ba_port)

### Send Requests ###

Send one request message:

    response_message = sf1.send(uri, request_message)

Send request messages in batch. The messages will not block each other.

    response_messages = sf1.batch
        connection.send(uri1, request_message1)
        connection.send(uri2, request_message2)
        connection.send(uri3, request_message3)
    end

The returned result is an array of all response messages. The response sequence
is the same of the occurrence sequence of their corresponding requests. If some
responses are nil, please check `connection.server_error`.


## Scripts ##

All scripts share the configuration file `bin/config.yml`. You can copy from
`bin/config.yml.default`.

### bin/cmd_sender.rb ###

Send index, mining and optimize_index command to BA. Example:

    ruby bin/cmd_sender.rb -n 1000 index ChnWiki


### bin/send.rb ###

Send the specified JSON files as request messages. The uri should be specified
as an field in the request message, e.g., file for sending index command to
ChnWiki:

    {
      "uri": "commands/index",
      "collection": "ChnWiki"
    }

The response message is saved in JSON file, which file name is adding "out.json"
suffix to the corresponding request JSON file name. If the request file has a
suffix "in.json", the suffix are removed first

   input        => output
   test.json    => test.out.json
   test.js      => test.out.json
   test.in.json => test.out.json
   test.in.js   => test.out.json
   test         => test.out.json

There are some samples in bin/json, you can send all requests using:

    ruby bin/send.rb bin/json/*.in.json

## WEB Sender ##

WEB sender uses the configuration file `websender/server.yml`. You can copy from
`websender/server.yml.default`.

Port is used to specify the port on which the WEB sender is listening to. It is
18188 be default. So the WEB Sender can be accessed through:

    http://localhost:18188


### Start WEB Sender ###

It is a WEB server implemented by WEBrick. Just start it in terminal:

    ruby websender/server.rb


### Add Schema & Template ###

The request form are generated from json schema file. All schema are in the
directory `websender/schema`. Every schema is a directory containing following
files:

  - request.json: schema for request.
  - response.json: schema for response.
  - template.*.json: named template.

Template are the default request messages that can be loaded in WEB
interface. The request also can be saved as template thought WEB
interface. You can add your frequently used templates in the directory, or
construct it through WEB interface and then save it. Remember to commit your
template if you think your template is valuable to be shared.

Schema file uses the syntax descried in
[here](http://robla.net/jsonwidget/jsonschema/).

### WEB Sender Agent ###

The WEB Sender can also be used as an agent. For example, you can use AJAX to
send request though WEB Sender.

You should post data in JSON format to URL `/sender`. For example, if your WEB
sender root URL is `http://localhost:18188`. Then you need to post data to
`http://localhost:18188/sender`.

The result are returned also in JSON format.

The path relative to `/sender` is used as URI sent to BA. Following is an
example to send request though WEB sender using ruby restclient.

    require 'restclient'
    require 'json'

    request = {
      "collection" => "ChnWiki",
      "search" => {
        "keywords" => "america",
        "in" => ["Title", "Content"]
      },
      "select" => ["Title", "Content"]
    }
    response = RestClient.post "http://localhost:18188/sender/documents",
        request.to_json, :content_type => :json, :accept => :json
    puts response
