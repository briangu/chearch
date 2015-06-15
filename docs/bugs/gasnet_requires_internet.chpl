/*

running locally with one host requires inernet


time ./bin/chearch -nl 1

[tw-mbp-bguarraci chearch (_bg_numeric)]$ time ./bin/chearch -nl 1
AMUDP sendPacket returning an error code: AM_ERR_RESOURCE (Problem with requested resource)
  from function sendPacket
  at /Users/bguarraci/src/chapel-1.11.0/third-party/gasnet/GASNet-1.24.0/other/amudp/amudp_reqrep.cpp:97
  reason: No route to host
initializing index
AMUDP AMUDP_RequestGeneric returning an error code: AM_ERR_RESOURCE (Problem with requested resource)
  at /Users/bguarraci/src/chapel-1.11.0/third-party/gasnet/GASNet-1.24.0/other/amudp/amudp_reqrep.cpp:1214

GASNet gasnetc_AMRequestMediumM encountered an AM Error: AM_ERR_RESOURCE(3)
  at /Users/bguarraci/src/chapel-1.11.0/third-party/gasnet/GASNet-1.24.0/udp-conduit/gasnet_core.c:690
GASNet gasnetc_AMRequestMediumM returning an error code: GASNET_ERR_RESOURCE (Problem with requested resource)
  at /Users/bguarraci/src/chapel-1.11.0/third-party/gasnet/GASNet-1.24.0/udp-conduit/gasnet_core.c:694
ERROR calling: gasnet_AMRequestMedium0(node, FORK, info, info_size)
 at: comm-gasnet.c:989
 error: GASNET_ERR_RESOURCE (Problem with requested resource)

*/