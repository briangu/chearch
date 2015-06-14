type Term = uint(32);
type ChasmOp = uint(8); // CHASM opcode type

const CHASM_HALT: ChasmOp = 0: ChasmOp; // HALT (0) is the default value in the instructions array
const CHASM_PUSH: ChasmOp = 1: ChasmOp;
const CHASM_AND:  ChasmOp = 2: ChasmOp;
const CHASM_OR:   ChasmOp = 3: ChasmOp;

class InstructionBuffer {
  var count: uint;
  var buffer: [0..count-1] ChasmOp;
  var offset = 0: uint;

  proc atEnd(): bool {
    return (offset >= count);
  }

  proc rewind() {
    offset = 0;
  }

  proc clear() {
    buffer = 0;
    offset = 0;
  }

  proc advance() {
    offset += 1;
  }

  proc canAdvance(increment: uint): bool {
    return (offset + increment) <= count;
  }

  proc read(): ChasmOp {
    if (atEnd()) {
      writeln("extended past instructions array end.");
      return 0;
    }
    var op = buffer[offset];
    advance();
    return op;
  }

  proc write(op: ChasmOp): bool {
    if (atEnd()) {
      writeln("write is out of instruction space at offset ", offset, " for op code ", op);
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

  proc atEnd(): bool {
    return instructions.atEnd();
  }

  proc read(): ChasmOp {
    writeln("reading");
    return instructions.read();
  }

  // read the next 4 bytes from high to low order and create a Term
  // if something goes wrong while readNext we just use 0s in those slots and fail later.
  proc readTerm(): Term {
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
      writeln("write_push is out of instruction space for term: ", term, " at offset ", instructions.offset);
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
      writeln("write_and is out of instruction space for CHASM_PUSH at offset ", instructions.offset);
      return false;
    }

    return instructions.write(CHASM_PUSH);
  }

  proc write_push_term(term: Term): bool {
    if (!instructions.canAdvance(2)) {
      writeln("write_and is out of instruction space for CHASM_PUSH at offset ", instructions.offset);
      return false;
    }

    write_push();
    write_term(term);
    return true;
  }

  proc write_and(): bool {
    if (!instructions.canAdvance(1)) {
      writeln("write_and is out of instruction space for CHASM_AND at offset ", instructions.offset);
      return false;
    }

    return instructions.write(CHASM_AND);
  }

  proc write_or(): bool {
    if (!instructions.canAdvance(1)) {
      writeln("write_or is out of instruction space for CHASM_OR at offset ", instructions.offset);
      return false;
    }

    return instructions.write(CHASM_OR);
  }
}

proc main() {
  var buffer = new InstructionBuffer(1);
  var writer = new InstructionWriter(buffer);
  writer.write_push();
  buffer.rewind();
  var reader = new InstructionReader(buffer);

  while (!reader.atEnd()) {
// FAILS to increment offset inside reader?
    // select reader.read() {
    //   when 0 do writeln("zero");
    //   when 1 do writeln("one");
    // }

    // works if you breakout the read and assign it to op
    var op: uint(8) = reader.read();
    select op {
      when 0 do writeln("zero");
      when 1 do writeln("one");
    }
  }

  /*
    while (tmp_chpl8) {
    _ref_tmp__chpl3 = &reader_chpl3;
    chpl_check_nil(_ref_tmp__chpl3, INT64(151), "select_read.chpl");
    call_tmp_chpl9 = read_chpl2(_ref_tmp__chpl3);
    call_tmp_chpl10 = ((uint8_t)(INT64(0)));
    call_tmp_chpl11 = (call_tmp_chpl9 == call_tmp_chpl10);
    if (call_tmp_chpl11) {
      wide_string_from_c_string(&call_tmp_chpl12, "zero", INT64(0), INT64(0), INT64(152), "select_read.chpl");
      writeln_chpl6(call_tmp_chpl12, INT64(152), "select_read.chpl");
    } else {
      _ref_tmp__chpl4 = &reader_chpl3;
      chpl_check_nil(_ref_tmp__chpl4, INT64(151), "select_read.chpl");
      call_tmp_chpl13 = read_chpl2(_ref_tmp__chpl4);
      call_tmp_chpl14 = ((uint8_t)(INT64(1)));
      call_tmp_chpl15 = (call_tmp_chpl13 == call_tmp_chpl14);
      if (call_tmp_chpl15) {
        wide_string_from_c_string(&call_tmp_chpl16, "one", INT64(0), INT64(0), INT64(153), "select_read.chpl");
        writeln_chpl6(call_tmp_chpl16, INT64(153), "select_read.chpl");
      }
    }
    _ref_tmp__chpl5 = &reader_chpl3;
    chpl_check_nil(_ref_tmp__chpl5, INT64(149), "select_read.chpl");
    call_tmp_chpl17 = atEnd_chpl2(_ref_tmp__chpl5);
    call_tmp_chpl18 = (! call_tmp_chpl17);
    tmp_chpl8 = call_tmp_chpl18;
  }
*/
}
