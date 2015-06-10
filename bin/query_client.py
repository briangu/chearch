import binascii
import socket
import struct
import sys

sock = socket.create_connection(('localhost', 3033))

try:
    
    # Send data
    data = bytearray([5, 1, 0, 0, 0, 2])
    sock.send(data)

    record_size = 4 + 1 + 8;
    record_count = 8;

    amount_received = 0
    amount_expected = record_size * record_count

    responseData = bytearray([])

    while amount_received < amount_expected:
        data = sock.recv(amount_expected)
        print(len(data))
        responseData = [item for sublist in [responseData, bytearray(data)] for item in sublist]
        amount_received += len(data)

    print(len(responseData))


    x = responseData
    for j in range(0, record_count):
        o = j * record_size;
        termId = (x[o + 0] << 24 | x[o + 1] << 16 | x[o + 2] << 8 | x[o + 3])
        o += 4

        text_position = x[o]
        o += 1

        docId = (x[o + 0] << 24 | x[o + 1] << 16 | x[o + 2] << 8 | x[o + 3])
        o += 4
        docId = docId << 32 | (x[o + 0] << 24 | x[o + 1] << 16 | x[o + 2] << 8 | x[o + 3])

        print >>sys.stderr, 'received "%s %s %s"' % (termId, text_position, docId)

finally:
    print >>sys.stderr, 'closing socket'
    sock.close()
