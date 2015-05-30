module Common {
  
  // TODO: should be using a doc index that maps to a doc id?
  type DocId = uint(64);

  class IndexRequest {
    var word: string;
    var docId: DocId;
  }
}