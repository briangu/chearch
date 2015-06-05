/**
  Chasm is the Chearch query assembly language (that helps you cross the search query chasm.)
*/
module Chasm {
  
  use Logging, Search;

  type ChasmOp = uint(8); // CHASM opcode type

  const CHASM_HALT: ChasmOp = 0: ChasmOp; // HALT (0) is the default value in the instructions array
  const CHASM_PUSH: ChasmOp = 1: ChasmOp;
  const CHASM_AND:  ChasmOp = 2: ChasmOp;
  const CHASM_OR:   ChasmOp = 3: ChasmOp;

  class InstructionBuffer {
    var count: uint;
    var buffer: [0..count-1] ChasmOp;
    var offset: uint = 0: uint;

    inline proc atEnd(): bool {
      return (offset >= count);
    }

    inline proc rewind() {
      offset = 0;
    }

    inline proc clear() {
      buffer = 0;
      offset = 0;
    }

    inline proc advance() {
      offset += 1;
    }

    inline proc canAdvance(increment: uint): bool {
      return (offset + increment) <= count;
    }

    inline proc read(): ChasmOp {
      if (atEnd()) {
        error("extended past instructions array end.");
        return 0;
      }
      var op = buffer[offset];
      advance();
      return op;
    }

    inline proc write(op: ChasmOp): bool {
      if (atEnd()) {
        error("write is out of instruction space at offset ", offset, " for op code ", op);
        return false;
      }

      buffer[offset] = op;
      advance();

      return true;
    }
  }

  record InstructionReader {
    var instructions: InstructionBuffer;

    proc InstructionReader(instructions: InstructionBuffer) {
      this.instructions = instructions;
      this.instructions.rewind();
    }

    inline proc atEnd(): bool {
      return instructions.atEnd();
    }

    inline proc read(): ChasmOp {
      return instructions.read();
    }

    // read the next 4 bytes from high to low order and create a Term
    // if something goes wrong while readNext we just use 0s in those slots and fail later.
    inline proc readTerm(): Term {
      return 
        ((instructions.read(): Term) << 24) | 
        ((instructions.read(): Term) << 16) | 
        ((instructions.read(): Term) << 8) | 
        (instructions.read(): Term);
    }
  }

  record InstructionWriter {
    var instructions: InstructionBuffer;

    proc write_term(term: Term): bool {
      if (!instructions.canAdvance(4)) {
        error("write_push is out of instruction space for term: ", term, " at offset ", instructions.offset);
        return false;
      }

      instructions.write((term >> 24): ChasmOp);
      instructions.write(((term & 0x00FF0000) >> 16): ChasmOp);
      instructions.write(((term & 0x0000FF00) >> 8): ChasmOp);
      instructions.write(term: ChasmOp);

      return true;
    }

    proc write_push(): bool {
      if (!instructions.canAdvance(1)) {
        error("write_and is out of instruction space for CHASM_PUSH at offset ", instructions.offset);
        return false;
      }

      return instructions.write(CHASM_PUSH);
    }

    proc write_and(): bool {
      if (!instructions.canAdvance(1)) {
        error("write_and is out of instruction space for CHASM_AND at offset ", instructions.offset);
        return false;
      }

      return instructions.write(CHASM_AND);
    }

    proc write_or(): bool {
      if (!instructions.canAdvance(1)) {
        error("write_or is out of instruction space for CHASM_OR at offset ", instructions.offset);
        return false;
      }

      return instructions.write(CHASM_OR);
    }
  }

  /**
    Intepret a query instruction sequence into a query AST object tree.
  */
  proc chasm_interpret(segment: Segment, instructionBuffer: InstructionBuffer): Operand {

    var reader = new InstructionReader(instructionBuffer);
    var stack: [0..1023] Operand;
    var stackPtr = stack.domain.high + 1;

    inline proc push(op: Operand) {
      if (stackPtr <= 0) {
        error("pushing out of stack space @ ", reader, " for buffer ", instructionBuffer);
        return;
      }
      stackPtr -= 1;
      stack[stackPtr] = op;
    }

    inline proc pop(): Operand {
      if (stackPtr > stack.domain.high) {
        error("popping out of stack space @ ", reader, " for buffer ", instructionBuffer);
        return new Operand();
      }
      var op = stack[stackPtr];
      stackPtr += 1;
      return op;
    }

    while (!reader.atEnd()) {
      var op = reader.read();
      select op {
        when CHASM_HALT do break;
        when CHASM_PUSH do push(segment.operandForTerm(reader.readTerm()));
        when CHASM_AND  do push(new IntersectionOperand(pop(), pop()));
        when CHASM_OR   do push(new UnionOperand(pop(), pop()));
      }
    }

    return pop();
  }
}