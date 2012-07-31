node-url-shortener
==================

Simple and really fast URL shortener

<del>Perl, Twiggy and Redis used.</del>

CoffeeScript, Node and Redis used (and kick ass, yap!)

To install:

	git clone git://github.com/Meettya/node-url-shortener.git
	cd node-url-shortener
	npm install .


To start:

1. one instance - `./node_server.coffee`
2. cluster - `/node_server_cluster.coffee`

**! UWAGA !**

cluster script use naive CPU number detection, if you PC use HT it will be better to manually reduce workers by 2

For benchmarking: `ab -n 10000 -c 500 -k http://localhost:3000/?url=$RANDOM`

PS.
> For my old machine -c must be lover, or ab aborted with message
>
> `apr_socket_recv: Connection reset by peer (54)`

