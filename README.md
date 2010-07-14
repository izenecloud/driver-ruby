# SF1 Driver Ruby #

## Installation ##

sf1-driver can be install as a gem. The gem can be generated using `rake gem` in
the code base:

    rake gem
    gem install pkg/sf1-driver-${VERSION}.gem

(Replace ${VERSION} to the latest version. You many need root privileges to
install the gem in system path)

All your installed versions can be listed by:

    gem list sf1-driver

## Usage ##

[RDoc](https://git.izenesoft.cn/sf1-revolution/driver-docs/blobs/raw/master/html/ruby-client/index.html)

[Driver Specification](https://git.izenesoft.cn/sf1-revolution/driver-docs/blobs/raw/master/html/index.html)

If you cannot access these sites, ask for a package of
`sf1-revolution/driver-docs`.

### Create Driver Client ###

    require 'sf1-driver'
    sf1 = Sf1Driver.new(ba_ip, ba_port)

### Send Requests ###

Send one request message:

    response_message = sf1.call(uri, request_message)

Send request messages in batch. The messages will not block each other.

    response_messages = sf1.batch do
      sf1.call(uri1, request_message1)
      sf1.call(uri2, request_message2)
      sf1.call(uri3, request_message3)
    end

The returned result is an array of all response messages. The response sequence
is the same of the occurrence sequence of their corresponding requests. If some
responses are nil, please check `connection.server_error`.

Some examples:

    # index ChnWiki
    sf1.call "commands/index", :collection => "ChnWiki"

    # search in ChnWiki and SohuNews in batch
    responses = sf1.batch do
      sf1.call "documents/search",
        :collection => "ChnWiki",
        :search => {
          :keywords => "America"
        }
      sf1.call "documents/search",
        :collection => "ShohuNews",
        :search => {
          :keywords => "America"
        }
    end

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
