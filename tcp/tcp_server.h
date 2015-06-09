#include <ev.h>

void plog(const char *format, ...);

// start the tcp server
int start_server();

int initialize_socket(int port);
void accept_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
void read_cb(EV_P_ struct ev_io *watcher, int revents);;

#define BUFFER_SIZE 1024

typedef struct ev_io_child {
  ev_io child;
  int buffer_size;
  char *buffer;
} ev_io_child;
