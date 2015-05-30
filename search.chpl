module Search {

  use DocumentId;

  // reference in a string table
  type Term = uint(32);

  type ExternalDocId = uint;

  class Query {
    var term: Term;
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
  }
}