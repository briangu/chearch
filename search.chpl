module Search {

  use Chasm, DocumentId, Operands;

  // reference in a string table
  type Term = uint(32);

  type ExternalDocId = uint;

  class Query {
    var instructionBuffer: InstructionBuffer;

    proc Query(query: Query) {
      instructionBuffer = new InstructionBuffer(query.instructionBuffer.count);
      for i in 0..instructionBuffer.count-1 {
        instructionBuffer.buffer[i] = query.instructionBuffer.buffer[i];
      }
    }
  }

  record QueryResult {
    var term: Term;
    var textLocation: TextLocation;
    var externalDocId: ExternalDocId;
  }

  record IndexTerm {
    var term: Term;
    var textLocation: TextLocation;
  }

  // A segment is a set of documents that can be searched over.
  // TODO: document deletes are not supported
  // TODO: document updates are not supported
  class Segment {
    inline proc isSegmentFull(): bool {
      halt("not implemented");
      return true;
    }

    proc addDocument(terms: [?D] IndexTerm, externalDocId: ExternalDocId): bool {
      halt("not implemented");
      return false;
    }

    iter query(query: Query): QueryResult {
      halt("not implemented");
      yield new QueryResult();
    }

    proc operandForTerm(term: Term): Operand {
      halt("not implemented");
      return new Operand();
    }
  }
}