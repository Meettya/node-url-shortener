#!/usr/bin/env coffee

###
This is simple test server, was build to compare Node with Twiggy
Just for fun, don't use it in production!

###

express   = require 'express'
{ hash }  = require 'mhash'
b62       = require 'base62-c'
redis     = require 'redis'
cluster   = require 'cluster'

CPUs      = require('os').cpus()

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

if cluster.isMaster
  
  # Fork workers.
  for cpu in CPUs
    cluster.fork()

  cluster.on 'exit', (worker, code, signal) ->
    console.log "worker #{worker.process.pid} died"

else

  app = express.createServer()
  app.use express.bodyParser()

  # build Redis client with error handling
  redis_client = redis.createClient()
  redis_client.on "error", (err) -> console.log "Error #{err}"

  # index page generator
  app.get '/', (req, res) ->
    long_url = req.param 'url'

    # nothing to do, send index and brake
    unless long_url
      res.send index, {'Content-Type':'text/html; charset=utf-8'}, 200
      return

    # hm, we are have some work today
    url_hash = hash "tiger192", long_url

    redis_client.get url_hash, (err, short_url) ->

      if short_url

        res_string = "Get: Short for #{long_url} is #{node_server}#{short_url}"
        res.send res_string, {'Content-Type':'text/html; charset=utf-8'}, 200

      else 

        redis_client.incr counter_key, (err, url_number) ->
          short_url = b62.encode url_number
          redis_client.mset [ url_hash, short_url, short_url, long_url ], (err, result) ->
            
            res_string = "Build: Short for #{long_url} is #{node_server}#{short_url}"
            res.send res_string, {'Content-Type':'text/html; charset=utf-8'}, 200


  # URL redirector
  app.get '/:short_url', (req, res) ->
    short_url = req.params.short_url
    # reject f*cking favicon.ico
    return if short_url is 'favicon.ico'

    redis_client.get short_url, (err, long_url) ->
      # should be 
      #   res.redirect long_url, 301
      # but crashes and I dont know why :(
      res.redirect long_url


  # 404 for others
  app.get '*', (req, res) ->
    res.send 'Not found', {'Content-Type' : 'text/plain'}, 404


  console.log "-> Start server on #{node_server}"
  app.listen node_port