//#include <ev.h>

struct ev_loop;
struct ev_io;

// implemented in Chapel
void accept_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);

// trampoline for libev to call accept_cb
void c_accept_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
