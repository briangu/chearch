# chearch

Chearch is a simple search engine written in Cray's Chapel language.

This application demonstrates how to use various important features of Chapel,
such as locales, and how to minimize RPC traffic through features such as local. 
It also shows how to build a simple, efficient, inverted index using only integer represesentions.

Project link to this page: http://chearch.pw (church pew)

Features of the search engine
=============================

* lock-free, using atomic operations for all appropriate operations
* string-free, the entire engine is integer-based.  This minimizes memory footprint while improves processing speed
* boolean queries, using an integer-based (no strings, remember?) query language called CHASM (Chearch Assembly)
* document-based hash partitioning
* distributed loads of indexes from storage (in-progress)
	* async queue indexer
	* batch load indexer
* online query and indexing support via libev-backed TCP connection (in-progress)
* support for in-memory and on-disk (future) index segments

Sample Query
============

    writeln("querying for term IDs 3 AND 2");
    
    // allocate the instruction buffer
    var buffer = new InstructionBuffer(1024);

    // write the CHASM code to implement the query    
    var writer = new InstructionWriter(buffer);
    writer.write_push();
    writer.write_term(3);
    writer.write_push();
    writer.write_term(2);
    writer.write_and();

    for result in query(new Query(buffer)) {
      writeln(result);
    }

    delete buffer;

SETUP
=====

General setup is expecting an OSX brew installation:

    brew install libev
    
Chapel (http://chapel.cray.com/download.html)

	brea install chapel

COMPILING

    make

RUN

    ./bin/chearch

TEST

    make chearch_test
    ./bin/chearch_test
