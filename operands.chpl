module Operands {

  use DocumentId;

  /**
  */
  type OperandValue = uint;

  // Operand base class.  Also serves as Null / empty Operand
  class Operand {
    proc hasValue(): bool {
      return false;
    }

    proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("iterated too far");
      }
      return 0;
    }

    proc advance() {
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
          opB.advance(); // skip over duplicate value
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

    proc hasValue(): bool {
      return curOp != nil;
    }

    proc getValue(): OperandValue {
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

    proc nextOperand(): Operand {
      var op: Operand = nil;

      while(opA.hasValue() && opB.hasValue()) {
        var docIndexA = (opA.getValue(): uint(32)) & DocumentIndexDocIdMask;
        var docIndexB = (opB.getValue(): uint(32)) & DocumentIndexDocIdMask;

        if (docIndexA > docIndexB) {
          opA.advance();
        } else if (docIndexA == docIndexB) {
          opB.advance(); // skip over duplicate value
          op = opA;
          break;
        } else { // A > B
          opB.advance();
        }
      }

      return op;
    }

    proc hasValue(): bool {
      return curOp != nil;
    }

    proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("intersection iterated past end of operands ", opA, opB);
      }

      return curOp.getValue();
    }

    proc advance() {
      if (!hasValue()) {
        halt("intersection iterated past end of operands ", opA, opB);
      }

      curOp = nextOperand();
    }
  }
}