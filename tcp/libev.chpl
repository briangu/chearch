module LibEv {

  extern const EVFLAG_AUTO: c_int;
  extern const EVFLAG_NO_ENV: c_int;
  extern const EVFLAG_FORKCHECK: c_int;
  extern const EVFLAG_NOINOTIFY: c_int;
  extern const EVFLAG_SIGNALFD: c_int;
  extern const EVFLAG_NOSIGMASK: c_int;

  extern const EVBACKEND_SELECT: c_int;
  extern const EVBACKEND_POLL: c_int;
  extern const EVBACKEND_EPOLL: c_int;
  extern const EVBACKEND_KQUEUE: c_int;
  extern const EVBACKEND_DEVPOLL: c_int;
  extern const EVBACKEND_PORT: c_int;
  extern const EVBACKEND_ALL: c_int;
  extern const EVBACKEND_MASK: c_int;

  extern const EVBREAK_CANCEL: c_int;
  extern const EVBREAK_ONE: c_int;
  extern const EVBREAK_ALL: c_int;

  extern type ev_fd = c_int;
  extern const STDIN_FILENO: ev_fd;
  extern const STDOUT_FILENO: ev_fd;

  extern type ev_events = c_int;
  extern const EV_READ: ev_events;
  extern const EV_WRITE: ev_events;
  extern const EV_ERROR: ev_events;

  extern type ev_tstamp = c_double;

// FEATURE: extern <extern type opt> record <internal type>
  extern record ev_loop {};

  extern record ev_io {
    var fd: c_int;
    var events: c_int;
  }
  extern type ev_timer;

  extern proc ev_version_major(): c_int;
  extern proc ev_version_minor(): c_int;
  extern proc ev_supported_backends: c_uint;
  extern proc ev_recommended_backends: c_uint;
  extern proc ev_embeddable_backends: c_uint;
  extern proc ev_time(): ev_tstamp;
  extern proc ev_sleep(ts: ev_tstamp);
  extern proc ev_feed_signal(x: c_int);
  extern proc ev_default_loop(x: c_uint): opaque;
  extern proc ev_loop_new(x: c_uint): opaque;
  extern proc ev_loop_destroy(loop: opaque);
  extern proc ev_loop_fork(loop: opaque);
  extern proc ev_is_default_loop(loop: opaque);
  extern proc ev_iteration(loop: opaque);
  extern proc ev_depth(loop: opaque): c_uint;
  extern proc ev_backend(loop: opaque): c_uint;
  extern proc ev_now(loop: opaque): ev_tstamp;
  extern proc ev_now_update(loop: opaque);
  extern proc ev_suspend(loop: opaque);
  extern proc ev_resume(loop: opaque);
  extern proc ev_run(loop: opaque, x: c_int);
  extern proc ev_break(loop: opaque, x: c_int);
  extern proc ev_ref(loop: opaque);
  extern proc ev_unref(loop: opaque);
// FEATURE: differentiate between type of ev_loop and function type of ev_loop so we don't need to use _fn
  extern ev_loop proc ev_loop_fn(loop: opaque, x: c_int);
  extern proc ev_unloop(loop: opaque, x: c_int);

  extern proc ev_timer_init_fn(ref loop: opaque, ref timer: ev_timer, x: c_int);
  extern proc ev_timer_init(ref timer: ev_timer, ref fn: c_void_ptr, start: ev_tstamp, stop: ev_tstamp);

  extern proc ev_timer_start(ref loop: opaque, ref timer: ev_timer);
  extern proc ev_timer_stop(ref loop: opaque, ref timer: ev_timer);

  extern proc ev_io_init(ref io: ev_io, fn, fd: ev_fd, events: ev_events);
  extern proc ev_io_start(loop: opaque, ref io: ev_io);

// FEATURE: this returns a c_ptr(ev_loop) but can't be used as input to a (ref: loop ev_loop) arg list
  extern var EV_DEFAULT: opaque;
}