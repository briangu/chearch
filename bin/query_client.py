import binascii
import socket
import struct
import sys

sock = socket.create_connection(('localhost', 3033))

try:
    
    # Send data
    data = bytearray([5, 1, 0, 0, 0, 2])
    sock.send(data)

    amount_received = 0
    amount_expected = 4
    
    while amount_received < amount_expected:
        data = sock.recv(4)
        x = bytearray(data)
        amount_received += len(data)
        termId = (x[0] << 24 | x[1] << 16 | x[2] << 8 | x[3])
        print >>sys.stderr, 'received "%s"' % termId

finally:
    print >>sys.stderr, 'closing socket'
    sock.close()
