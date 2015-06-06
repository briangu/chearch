module Operands {

  use DocumentId;

  /**
    Operand value is the value that represents the run-time, internal search results.
    After the query processing is complete, it is converted to a QueryResult which has 
    the resolved external document id instead of the internal document index.

    An operand value is a partitioned uint(64) value that contains the following fields:

    | term id (32-bit) | DocId (32-bit) |

    which expands to 

    | term id (32-bit) | text location (8-bit) | document index (24-bit) |

    Note that we keep the document index on the LSB side so that we can mask it out 
    and use it for document equivalent comparision between Operand values.

  */
  type OperandValue = uint;

  // Operand base class.  Also serves as Null / empty Operand
  // TODO: convert Operands to be proper Chapel iterators so we can iterate through the AST in parallel
  class Operand {
    inline proc hasValue(): bool {
      return false;
    }

    inline proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("iterated too far");
      }
      return 0;
    }

    inline proc advance() {
      if (!hasValue()) {
        halt("iterated too far");
      }
    }

    iter evaluate() {
      while (hasValue()) {
        yield getValue();
        advance();
      }
    }
  }

  class UnionOperand : Operand {
    var opA: Operand;
    var opB: Operand;
    var curOp: Operand = nextOperand();

    proc nextOperand(): Operand {
      var op: Operand = nil;

      if (opA.hasValue() && opB.hasValue()) {
        var docIndexA = (opA.getValue(): uint(32)) & DocumentIndexDocIdMask;
        var docIndexB = (opB.getValue(): uint(32)) & DocumentIndexDocIdMask;

        if (docIndexA > docIndexB) {
          op = opA;
        } else if (docIndexA == docIndexB) {
          op = opA;
        } else {
          op = opB;
        }
      } else if (opA.hasValue()) {
        op = opA;
      } else if (opB.hasValue()) {
        op = opB;
      }

      return op;
    }

    inline proc hasValue(): bool {
      return curOp != nil;
    }

    inline proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("union iterated past end of operands ", opA, opB);
      }

      return curOp.getValue();
    }

    proc advance() {
      if (!hasValue()) {
        halt("union iterated past end of operands ", opA, opB);
      }

      curOp.advance();
      curOp = nextOperand();
    }
  }

  class IntersectionOperand : Operand {
    var opA: Operand;
    var opB: Operand;
    var curOp: Operand = nextOperand();

    inline proc documentIndexFromOperand(op: Operand): uint(32) {
      return (op.getValue(): uint(32)) & DocumentIndexDocIdMask;
    }

    proc nextOperand(): Operand {
      var op: Operand = nil;

      while(opA.hasValue() && opB.hasValue()) {
        var docIndexA = documentIndexFromOperand(opA);
        var docIndexB = documentIndexFromOperand(opB);;

        if (docIndexA > docIndexB) {
          opA.advance();
        } else if (docIndexA == docIndexB) {
          if ((curOp != nil) && (documentIndexFromOperand(curOp) == docIndexA)) {
            if (curOp == opA) {
              opA.advance(); 
              op = opB;
            } else {
              opB.advance(); 
              op = opA;
            }
          } else {
            op = opA;
          }
          break;
        } else { // A < B
          opB.advance();
        }
      }

      return op;
    }

    inline proc hasValue(): bool {
      return curOp != nil;
    }

    inline proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("intersection iterated past end of operands ", opA, opB);
      }

      return curOp.getValue();
    }

    inline proc advance() {
      if (!hasValue()) {
        halt("intersection iterated past end of operands ", opA, opB);
      }

      curOp = nextOperand();
    }
  }
}
