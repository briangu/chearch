# chearch

Chearch is a simple search engine written in Cray's Chapel language.

Primary website: http://chearch.pw (church pew)

This application demonstrates how to use various important features of Chapel,
such as locales, and how to minimize RPC traffic through features such as local.

Features of the search engine
=============================

* document-based hash partitioning (in-progress)
* boolean queries (in progress)
* distributed loads of indexes from storage (in-progress)
* online query and indexing support via libev-backed TCP connection (in-progress)
* support for in-memory and on-disk index segments (future)

SETUP
=====

General setup is expecting an OSX brew installation:

    brew install libev
    
Chapel (http://chapel.cray.com/download.html)

	brea install chapel

COMPLING

    make

RUN

    ./bin/chearch

