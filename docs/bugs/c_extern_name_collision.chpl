/*

Collision between ev_loop struct and function name:


In file included from /tmp/chpl-bguarraci-91221.deleteme/_main.c:1:
/tmp/chpl-bguarraci-91221.deleteme/chpl__header.h:237:9: error: must use 'struct' tag to refer to type 'ev_loop'
typedef ev_loop *c_ptr_ev_loop;
        ^
        struct
/opt/local/Cellar/libev/4.15/include/ev.h:826:20: note: struct 'ev_loop' is hidden by a non-type declaration of 'ev_loop' here
    EV_INLINE void ev_loop   (EV_P_ int flags) { ev_run   (EV_A_ flags); }
                   ^
In file included from /tmp/chpl-bguarraci-91221.deleteme/_main.c:1:
/tmp/chpl-bguarraci-91221.deleteme/chpl__header.h:269:9: error: must use 'struct' tag to refer to type 'ev_loop'
typedef ev_loop *_ref_ev_loop;
        ^
        struct
/opt/local/Cellar/libev/4.15/include/ev.h:826:20: note: struct 'ev_loop' is hidden by a non-type declaration of 'ev_loop' here
    EV_INLINE void ev_loop   (EV_P_ int flags) { ev_run   (EV_A_ flags); }
                   ^
2 errors generated.
make[1]: *** [/tmp/chpl-bguarraci-91221.deleteme/chpl_tcp_server.tmp] Error 1
error: compiling generated source [mysystem.cpp:43]
make: *** [chpl_tcp_server] Error 1

*/