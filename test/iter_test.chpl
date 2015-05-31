var arr1 = [1,3,5,7,9,11,13];
var arr2 = [3,7,11,15];
var arr3 = [4,6,8,12];

class Operand {
  proc hasValue(): bool {
    return false;
  }

  proc getValue(): int {
    if (!hasValue()) {
      halt("iterated too far");
    }
    return -1;
  }

  proc advance() {
    if (!hasValue()) {
      halt("iterated too far");
    }
  }
}

class ArrOperand : Operand {
  var arr;
  var idx = arr.domain.low;

  proc hasValue(): bool {
    return idx <= arr.domain.high;
  }

  proc getValue(): int {
    if (!hasValue()) {
      halt("iterated past end of arr ", arr);
    }

    return arr[idx];
  }

  proc advance() {
    if (!hasValue()) {
      halt("iterated past end of arr ", arr);
    }

    idx += 1;
  }
}

class UnionOperand : Operand {
  var opA: Operand;
  var opB: Operand;
  var curOp: Operand = nextOperand();

  proc nextOperand(): Operand {
    var op: Operand = nil;

    if (opA.hasValue() && opB.hasValue()) {
      if (opA.getValue() < opB.getValue()) {
        op = opA;
      } else if (opA.getValue() == opB.getValue()) {
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

  proc getValue(): int {
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
      if (opA.getValue() < opB.getValue()) {
        opA.advance();
      } else if (opA.getValue() == opB.getValue()) {
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

  proc getValue(): int {
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

proc buildAST(): Operand {
  var arr1Op = new ArrOperand(arr1);
  var arr2Op = new ArrOperand(arr2);
  var iOp = new IntersectionOperand(arr1Op, arr2Op);
  var arr3Op = new ArrOperand(arr3);
  var uOp = new UnionOperand(iOp, arr3Op);
  return uOp;
}

iter evaluate(op: Operand) {
  while (op.hasValue()) {
    yield op.getValue();
    op.advance();
  }
}

for i in evaluate(buildAST()) {
  writeln(i);
}
