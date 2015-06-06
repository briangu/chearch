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
