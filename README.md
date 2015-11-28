Fastest Servers
===============
[![Build Status](https://img.shields.io/travis/trinitronx/fastest-servers.svg)](https://travis-ci.org/trinitronx/fastest-servers)
[![Docker Pulls](https://img.shields.io/docker/pulls/trinitronx/fastest-servers.svg)](https://hub.docker.com/r/trinitronx/fastest-servers)
[![Docker Stars](https://img.shields.io/docker/stars/trinitronx/fastest-servers.svg)](https://hub.docker.com/r/trinitronx/fastest-servers)
[![Gittip](http://img.shields.io/gittip/trinitronx.svg)](https://www.gittip.com/trinitronx)

A Ruby Script to narrow down a list of mirrors to the fastest servers.

By default, use Ubuntu mirror list hosted at: http://mirrors.ubuntu.com/mirrors.txt

Outputs a `mirrors.txt` file to `/tmp/` in the container.  To capture this file for later use, pass through `/tmp` as a volume mount to Docker Container.

Configuration / Environment Variables
-------------------------------------

Variable Name                    | Description                                                                                                                                             | Default
-------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------
`FASTEST_SERVER_LIST_TYPE`       | Tells script what port to ping servers on. `HTTP` or `NTP` (Experimental)                                                                               | `HTTP`
`FASTEST_SERVER_INITIAL_TIMEOUT` | Initial timeout in seconds used as limit for server ping timeout. If < 5 servers satisfy timeout, add `0.001` to this & retry until >= 5 servers found. | `0.050` (seconds)
`MIRRORLIST_LOCAL_FILE`          | If specified, use this local file as mirror list input to find fastest servers in list                                                                  | `nil`
`MIRRORLIST_HOST`                | Get `MIRRORLIST_URL` from this host and use as mirror list input for finding fastest servers                                                            | `mirrors.ubuntu.com`
`MIRRORLIST_URL`                 | Get this URL from `MIRRORLIST_HOST` & use as mirror list input                                                                                          | `/mirrors.txt`
`MIRRORLIST_PORT`                | Port to contact `MIRRORLIST_HOST` on for getting `MIRRORLIST_URL` via HTTP                                                                              | `80`
`FASTEST_SERVER_LIST_OUTPUT`     | Local file to output final filtered mirror list to.  If using docker, ensure you volume mount enclosing directory from host                             | `/tmp/mirrors.txt`
`FASTEST_SERVER_DEBUG`           | Puts script in `DEBUG` mode, which prints extra information to `STDOUT`                                                                                 | `nil`

Example Usage
-------------

To output a list of fastest Ubuntu mirrors to `/tmp/mirrors.txt`:

    sudo docker run -ti -v /tmp/:/tmp/ trinitronx/fastest-servers:latest

To run script in `DEBUG` mode, pass in environment variable `-e FASTEST_SERVER_DEBUG=true`:

    sudo docker run -ti -e FASTEST_SERVER_DEBUG=true -v /tmp/:/tmp/ trinitronx/fastest-servers:latest

