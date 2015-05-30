#include "callbacks.h"

void c_accept_cb(struct ev_loop *loop, struct ev_io *watcher, int revents) {
	accept_cb(loop, watcher, revents);
}

