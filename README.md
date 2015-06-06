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
* parallel scatter-gather across partitions using native Chapel forall support

Sample
============

A simple example (from test/helloworld.chpl) which indexes a document (id 10) with two terms: 2 and 3

    use SearchIndex;

    proc main() {

        writeln("initialize search index");

        initPartitions();

        writeln("add document id 10 with terms 2 and 3");

        {
            var terms: [0..1] IndexTerm;
            terms[0].term = 2;
            terms[0].textLocation = 6;
            terms[1].term = 3;
            terms[1].textLocation = 15;
            addDocument(terms, 10);
        }

        {
            var terms: [0..1] IndexTerm;
            terms[0].term = 2;
            terms[0].textLocation = 6;
            addDocument(terms, 15);
        }

        // create CHASM instruction buffer
        var buffer = new InstructionBuffer(1024);
        var writer = new InstructionWriter(buffer);

        // write the CHASM code to implement the query
        writeln("querying for term IDs 2");
        writer.write_push_term(2);
        forall result in query(new Query(buffer)) {
            writeln(result);
        }

        writeln("querying for term IDs 3");
        buffer.clear();
        writer.write_push_term(3);
        forall result in query(new Query(buffer)) {
            writeln(result);
        }

        writeln("querying for term IDs 2 OR 3");
        buffer.clear();
        writer.write_push_term(2);
        writer.write_push_term(3);
        writer.write_or();
        forall result in query(new Query(buffer)) {
            writeln(result);
        }

        writeln("querying for term IDs 2 AND 3");
        buffer.clear();
        writer.write_push_term(2);
        writer.write_push_term(3);
        writer.write_and();
        forall result in query(new Query(buffer)) {
            writeln(result);
        }

        delete buffer;
    }


Output

    initialize search index
    add document id 10 with terms 2 and 3
    querying for term IDs 2
    (term = 2, textLocation = 6, externalDocId = 15)
    (term = 2, textLocation = 6, externalDocId = 10)
    querying for term IDs 3
    (term = 3, textLocation = 15, externalDocId = 10)
    querying for term IDs 2 OR 3
    (term = 2, textLocation = 6, externalDocId = 15)
    (term = 3, textLocation = 15, externalDocId = 10)
    (term = 2, textLocation = 6, externalDocId = 10)
    querying for term IDs 2 AND 3
    (term = 3, textLocation = 15, externalDocId = 10)
    (term = 2, textLocation = 6, externalDocId = 10)

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
