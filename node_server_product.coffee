#!/usr/bin/env coffee

###
This is advanced simple test server, was build to compare Node with Twiggy
May be used in real world, but not tested.
Use with care.
###

express   = require 'express'
{ hash }  = require 'mhash'
b62       = require 'base62-c'
redis     = require 'redis'


# settings
node_port   = 3000
node_server = "http://localhost:#{node_port}/"
counter_key = 'node_urls_counter'


index = '''
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
         <head>
          <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
          <title>URL shotener</title>
         </head>
         <body>
          <form action="/">
           <fieldset>
            <label for="url">Enter URL:</label>
            <input type="text" name="url" id="url" />
            <input type="submit" value="Get short link" />
           </fieldset>
          </form>
         </body>
        </html>
        '''

app = express.createServer()
app.use express.bodyParser()

# build Redis client with error handling
redis_client = redis.createClient()
redis_client.on "error", (err) -> console.log "Error #{err}"

# index page generator
app.get '/', (req, res) ->
  res.set 'Content-Type', 'text/html'
  long_url = req.param 'url'

  # nothing to do, send index and brake
  unless long_url
    res.send 200, index
    return

  # hm, we are have some work today
  url_hash = hash 'tiger192', long_url

  redis_client.get url_hash, (err, short_url) ->

    if short_url

      res.send 200, "Redis: Short for #{long_url} is #{node_server}#{short_url}"

    else 
      # in some rare cases we are MAY increment counter,
      # but dont use returned number. who care?
      redis_client.incr counter_key, (err, url_number) ->
        new_short_url = b62.encode url_number
        redis_client.msetnx [ url_hash, new_short_url, new_short_url, long_url ], (err, data_saved) ->
          
          if data_saved
            
            res_string = "Calculated: Short for #{long_url} is #{node_server}#{new_short_url}"
            res.send 200, res_string
          
          else
            # why it happened?
            # so, node is too match async, we may get |no key| 
            # but actually it exists - we are need double check
            redis_client.get url_hash, (err, short_url) ->
              if short_url
                res_string = "Redis: Short for #{long_url} is #{node_server}#{short_url}"
                res.send 200, res_string
              else 
                # TODO: add here node error logger
                res.set 'Content-Type', 'text/plain'
                res.send 500, 'Internal Server Error'

# URL redirector
app.get '/:short_url', (req, res, next) ->
  short_url = req.params.short_url
  # reject f*cking favicon.ico
  return next() if short_url is 'favicon.ico'

  redis_client.get short_url, (err, long_url) ->
    # if someone send unexistents key
    return next() unless long_url
    # should be 
    #   res.redirect long_url, 301
    # but crashes and I dont know why :(
    res.redirect 301, long_url



# 404 for others
app.get '*', (req, res) ->
  res.set 'Content-Type', 'text/plain'
  res.send 404, 'Not found'


console.log "-> Start server on #{node_server}"
app.listen node_port