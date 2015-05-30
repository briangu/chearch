module DocumentId {
  /**
    A document id is the connection between a term and the external document it belongs to,
    providing both a reference to the external document as well as the term's text position within that document.

    Document Index = internal reference to externalDocumentId table.
    Text Position = position of the term in this document

    Since have a fixed upper-bound of documents, we therefore balance segment size with text position constraints.
    A document id can fit both the docuent index and the text position as bit field partitions.  
    For different mixes of document count and text positions, the ratio of bit fields can be adjusted.

    There's nothing implementation dependent here about the bit partitions except that the 
    document index should always be on the lower-order side for optimizing the operand document comparision.

    The 32-bit unsigned integer is partitioned as follows:
      high-order 8-bits: text position in external document (e.g. a Tweet)
      low-order 24-bits: index into segment's documents array
  */
  type DocId = uint(32);
  type DocumentIndex = uint(32);
  type TextLocation = uint(8);

  const MaxDocumentIndexCount = 2 ** 24;

  const DocumentIndexDocIdMask = 0x00FFFFFF: DocId;

  inline proc documentIndexFromDocId(docId: DocId): DocumentIndex {
    return (docId & DocumentIndexDocIdMask): DocumentIndex;
  }

  inline proc textLocationFromDocId(docId: DocId): TextLocation {
    return ((docId & ~DocumentIndexDocIdMask) >> 24): TextLocation;
  }

  inline proc splitDocId(docId: DocId): (DocumentIndex, TextLocation) {
    return (documentIndexFromDocId(docId), textLocationFromDocId(docId));
  }

  inline proc assembleDocId(documentIndex: DocumentIndex, textLocation: TextLocation): DocId {
    return ((textLocation: DocId) << 24) | (documentIndex: DocId);
  }
}
