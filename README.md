Fastest Servers
===============
[![Build Status](https://img.shields.io/travis/trinitronx/fastest-servers.svg)](https://travis-ci.org/trinitronx/fastest-servers)
[![Docker Pulls](https://img.shields.io/docker/pulls/trinitronx/fastest-servers.svg)](https://hub.docker.com/r/trinitronx/fastest-servers)
[![Docker Stars](https://img.shields.io/docker/stars/trinitronx/fastest-servers.svg)](https://hub.docker.com/r/trinitronx/fastest-servers)
[![Gittip](http://img.shields.io/gittip/trinitronx.svg)](https://www.gittip.com/trinitronx)

A Ruby Script to narrow down a list of mirrors to the fastest servers.

By default, use Ubuntu mirror list hosted at: http://mirrors.ubuntu.com/mirrors.txt


Example Usage
-------------

To output a list of fastest Ubuntu mirrors to `/tmp/mirrors.txt`:

    sudo docker run -ti -v /tmp/:/tmp/ trinitronx/fastest-servers:latest


