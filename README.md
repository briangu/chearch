# chearch

Chearch is a simple search engine written in Cray's Chapel language.

Primary website: http://chearch.pw (church pew)

This application demonstrates how to use various important features of Chapel,
such as locales, and how to minimize RPC traffic through features such as local.

Features of the search engine
=============================

* lock-free, using atomic operations for all appropriate operations
* string-free, the entire engine is integer-based.  This minimizes memory footprint while improves processing speed
* boolean queries (in progress) using a FORTH-like integer-based (no strings, remember?) query language
* document-based hash partitioning
* distributed loads of indexes from storage (in-progress)
** async queue indexer
** batch load indexer
* online query and indexing support via libev-backed TCP connection (in-progress)
* support for in-memory and on-disk (future) index segments

Sample Query
============

    writeln("querying for 3 AND 2");
    var buffer = new InstructionBuffer(1024);
    writer.write_push();
    writer.write_term(3);
    writer.write_push();
    writer.write_term(2);
    writer.write_and();

    for result in query(new Query(buffer)) {
      writeln(result);
    }

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

TEST

    make chearch_test
    ./bin/chearch_test
