import binascii
import socket
import struct
import sys

sock = socket.create_connection(('localhost', 3033))

try:
    
    # Send data
    data = bytearray([5, 1, 0, 0, 0, 2])
    sock.send(data)

    record_size = 5;
    record_count = 32;

    amount_received = 0
    amount_expected = record_size * record_count

    while amount_received < amount_expected:
        data = sock.recv(amount_expected)
        x = bytearray(data)
        amount_received += len(data)
        for j in range(0, record_count):
            o = j * record_size;
            termId = (x[o + 0] << 24 | x[o + 1] << 16 | x[o + 2] << 8 | x[o + 3])
            text_position = x[o+4]
            print >>sys.stderr, 'received "%s %s"' % (termId, text_position)

finally:
    print >>sys.stderr, 'closing socket'
    sock.close()
