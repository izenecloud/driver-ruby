Ruby Client Tool for SF1R
=======================================


### Install
To use ruby driver, you should have ruby 1.9.3 installed:
```bash
$ cd driver-ruby
$ rake install
```

### Usage
To start the web API sender:
```bash
$ cd driver-ruby/websender
$ ruby server.rb
```
However, you should specify the configuration of web API sender beforehand:
```bash
:Port: 18188
:MimeTypes:
  html: text/html
  js: application/x-javascript
  css: text/css
:BA:
  :IP: 127.0.0.1
  :Port: 18181
```
`18181` is the default port SF1R is listening at. If you want to send the API to the nginx reverse proxy, you should use a different configuration:

```bash
:Port: 18188
:MimeTypes:
  html: text/html
  js: application/x-javascript
  css: text/css
:NGINX_POSTFIX: sf1r
:BA:
  :IP: 127.0.0.1
  :Port: 8888
```
Here `8888` is the default port nginx is listening on.



### License
The SF1R project is published under the Apache License, Version 2.0:
http://www.apache.org/licenses/LICENSE-2.0
