// http://codefundas.blogspot.com/2010/09/create-tcp-echo-server-using-libev.html
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <unistd.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <netinet/in.h>
#include <ev.h>
#include <fcntl.h>
#include <errno.h>

#include "tcp_server.h"

extern void handle_received_data(int fd, char *buffer, size_t read, size_t buffer_size);

#define PORT_NO 3033
#define LISTEN_QUEUE_LENGTH 16*1024
#define MIN_CHILD_PROCESS_COUNT 4 // ideally one per processor

#define MAX(a,b) \
   ({ __typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })

typedef struct ev_fork_child {
  ev_child child;
  int sd;
  int process_slot;
} ev_fork_child;

int g_num_procs = MIN_CHILD_PROCESS_COUNT;

// pid of the master process
pid_t g_master_pid = 0;

// Total number of connected clients
int g_total_clients = 0;

ev_fork_child ** g_child_processes = NULL;

pid_t create_child_process(EV_P_ int sd, int process_slot);

void plog(const char *format, ...) {
  printf("%d: ", getpid());

  va_list argptr;
  va_start(argptr, format);
  vfprintf(stdout, format, argptr);
  va_end(argptr);
}

int make_socket_nonblocking(int fd) {
  // TODO: fix for windows
  // non blocking
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags == -1) {
      plog("make_socket_nonblocking: fcntl(F_GETFL) failed, errno: %s\n", strerror(errno));
      return -1;
  }
  if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) == -1) {
      plog("make_socket_nonblocking: fcntl(F_SETFL) failed, errno: %s\n", strerror(errno));
      return -1;
  }
  return 1;
}

/* Read client message */
void read_cb(EV_P_ struct ev_io *watcher, int revents) {
  struct ev_io_child *child = (ev_io_child *)watcher;
  int buffer_size = child->buffer_size;
  char *buffer = child->buffer;
  ssize_t read;

  if(EV_ERROR & revents) {
    plog("got invalid event\n");
    return;
  }

  // Receive message from client socket
  read = recv(watcher->fd, buffer, buffer_size, 0);
  if (read > 0) {
    handle_received_data(watcher->fd, buffer, read, buffer_size);
    // ev_io_stop(EV_A_ watcher);
    // free(watcher);
    // g_total_clients --; // Decrement g_total_clients count
  } else if(read < 0) {
    plog("read error");
    return;
  } else if(read == 0) {
    // Stop and free watcher if client socket is closing
    ev_io_stop(EV_A_ watcher);
    free(watcher);
    plog("peer might closing\n");
    g_total_clients --; // Decrement g_total_clients count
    plog("%d client(s) connected.\n", g_total_clients);
    return;
  }
}

/* Accept client requests */
void accept_cb(EV_P_ struct ev_io *watcher, int revents) {
  struct sockaddr_in client_addr;
  socklen_t client_len = sizeof(client_addr);
  int client_sd;

  if(EV_ERROR & revents) {
    plog("got invalid event");
    return;
  }

  // Accept client request
  client_sd = accept(watcher->fd, (struct sockaddr *)&client_addr, &client_len);
  if (client_sd < 0) {
    if (errno != EAGAIN) {
      plog("accept error %d\n", errno);
    }
    return;
  }

  if (make_socket_nonblocking(client_sd) == -1) { 
    plog("failed to set accepted socket to nonblocking mode");
    return;
  }

  g_total_clients ++; // Increment g_total_clients count
  plog("Successfully connected with client.\n");
  plog("%d client(s) connected.\n", g_total_clients);

  // Initialize and start watcher to read client requests
  struct ev_io *w_client = malloc(sizeof(ev_io_child) + 1024);
  ((ev_io_child *)w_client)->buffer_size = 1024;
  ((ev_io_child *)w_client)->buffer = ((char *)w_client) + sizeof(ev_io_child);
  ev_io_init(w_client, read_cb, client_sd, EV_READ);
  ev_io_start(EV_A_ w_client);
}

int initialize_socket(int port) {
  int sd;

  // Create server socket
  if((sd = socket(PF_INET, SOCK_STREAM, 0)) < 0) {
    plog("socket error");
    return -1;
  }

  int option_value = 0;
  setsockopt(sd, SOL_SOCKET, SO_REUSEADDR, (char*) &option_value, sizeof(option_value));

  if (make_socket_nonblocking(sd) == -1) {
    plog("failed to set socket to nonblocking mode");
    return -1;
  }

  struct sockaddr_in addr;
  bzero(&addr, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = INADDR_ANY;

  // Bind socket to address
  if (bind(sd, (struct sockaddr*) &addr, sizeof(addr)) != 0) {
    plog("bind error");
  }

  // Start listing on the socket
  if (listen(sd, LISTEN_QUEUE_LENGTH) < 0) {
    plog("listen error");
    return -1;
  }

  return sd;
}

void child_cb(EV_P_ ev_child *ec, int revents) {
  // don't respawn processes unless master
  if (getpid() != g_master_pid) {
    return;
  }

  ev_fork_child *fork_child = (ev_fork_child *)ec;
  ev_child *w = &fork_child->child;

  plog("child process %d exited with status %x. respawning.\n", w->rpid, w->rstatus);

  // stop monitoring the, now dead, child process
  ev_child_stop(EV_A_ w);

  int sd = fork_child->sd;
  free(fork_child);

  pid_t pid = create_child_process(EV_A_ sd, fork_child->process_slot);
  if (pid > 0) {
    plog("respawed new child process %d\n", pid);
  } else {
    plog("failed to respawn child process: %d\n", pid);
  }
}

void watch_child(EV_P_ int sd, pid_t pid, int process_slot) {
  plog("watching child %d\n", pid);
  ev_fork_child *cw = malloc(sizeof(ev_fork_child));
  cw->sd = sd;
  cw->process_slot = process_slot;
  ev_child_init (&cw->child, child_cb, pid, 0);
  ev_child_start (EV_DEFAULT_ (ev_child *)cw);
  g_child_processes[process_slot] = cw;
}

void unwatch_child(EV_P_ int process_slot) {
  plog("unwatching child process %d\n", process_slot);
  ev_fork_child *cw = g_child_processes[process_slot];
  ev_child_stop(EV_A_ (ev_child *)cw);
}

pid_t create_child_process(EV_P_ int sd, int process_slot) {
  pid_t pid = fork();
  if (pid == 0) {
    // child process
    plog("new child process: %d\n", getpid());

    // Initialize and start a watcher to accepts client requests
    ev_loop_fork(loop);

    struct ev_loop *child_loop = EV_DEFAULT;

    // TODO: unwatch other children
    for (int i = 0; i < g_num_procs; i++) {
      if (i != process_slot && g_child_processes[i]) {
        unwatch_child(child_loop, i);
      }
    }

    struct ev_io *w_accept = malloc(sizeof(ev_io));
    ev_io_init(w_accept, accept_cb, sd, EV_READ);
    ev_io_start(child_loop, w_accept);

    plog("starting event loop.\n");

    while (1) {
      ev_loop(child_loop, 0);
    }

    plog("exiting event loop.\n");

    free(w_accept);
  } else if (pid > 0) {
    plog("created child process for %d\n", process_slot);
    watch_child(loop, sd, pid, process_slot);
  } else {
    plog("failed to create child process for %d\n", process_slot);
  }

  return pid;
}

int get_processor_count() {
  long nprocs;

#ifdef _WIN32
#ifndef _SC_NPROCESSORS_ONLN
SYSTEM_INFO info;
GetSystemInfo(&info);
#define sysconf(a) info.dwNumberOfProcessors
#define _SC_NPROCESSORS_ONLN
#endif
#endif

#ifdef _SC_NPROCESSORS_ONLN
  nprocs = sysconf(_SC_NPROCESSORS_ONLN);
  if (nprocs < 1) {
    plog("Could not determine number of CPUs online:\n%s\n", strerror (errno));
  }
#else
  fprintf(stderr, "Could not determine number of CPUs");
#endif

  return MAX(nprocs, MIN_CHILD_PROCESS_COUNT);
}

int start_server() {
  plog("master starting\n");

  g_master_pid = getpid();
  g_num_procs = get_processor_count();

  int sd = initialize_socket(PORT_NO);
  if (sd == -1) {
    plog("failed to initialize socket");
    return -1;
  }

  // empty the child process slots so that child processes know which childs to unwatch
  plog("using %d child threads\n", g_num_procs);
  g_child_processes = malloc(g_num_procs * sizeof(ev_fork_child *));
  for (int i = 0; i < g_num_procs; i++) {
    g_child_processes[i] = NULL;
  }

  for (int i = 0; i < g_num_procs; i++) {
    pid_t pid = create_child_process(EV_DEFAULT_ sd, i);
    if (pid > 0) {
      // parent (this) process
      plog("Successfully created child process: %d\n", pid);
    } else {
      // failure to create child process
      plog("Failed to create child process: %d\n", pid);
    }
  }

  while (1) {
    ev_loop(EV_DEFAULT_ 0);
  }

  return 0;
}
