#include "timers.h"
#include <QTimer>

int timer_create(lua_State *L) {
  QTimer **p = static_cast<QTimer**>(lua_newuserdata(L, sizeof(QTimer*)));
  *p = new QTimer();
  (*p)->setTimerType(Qt::PreciseTimer);
  luaL_getmetatable(L, "timers.Timer");
  lua_setmetatable(L, -2);
  return 1;
}

int timer_start(lua_State *L) {
  QTimer *timer =
    *static_cast<QTimer**>(luaL_checkudata(L, 1, "timers.Timer"));
  if (lua_isnumber(L, 2)) {
    int msec = lua_tonumberx(L, 2, NULL);
    timer->start(msec);
  } else {
    timer->start();
  }
  return 0;
}

int timer_stop(lua_State *L) {
  QTimer *timer =
    *static_cast<QTimer**>(luaL_checkudata(L, 1, "timers.Timer"));
  timer->stop();
  return 0;
}

int timer_reset(lua_State *L) {
  QTimer *timer =
	*static_cast<QTimer**>(luaL_checkudata(L, 1, "timers.Timer"));
  timer->stop();
  timer->start();
  return 0;
}

int timer_interval(lua_State *L) {
  QTimer *timer =
    *static_cast<QTimer**>(luaL_checkudata(L, 1, "timers.Timer"));
  lua_pushinteger(L, timer->interval());
  return 1;
}

int timer_set_interval(lua_State *L) {
  QTimer *timer =
    *static_cast<QTimer**>(luaL_checkudata(L, 1, "timers.Timer"));
  int msec = luaL_checknumber(L, 2);
  timer->setInterval(msec);
  return 0;
}

int timer_set_single_shot(lua_State *L) {
  QTimer *timer =
    *static_cast<QTimer**>(luaL_checkudata(L, 1, "timers.Timer"));
  bool val = lua_toboolean(L, 2);
  timer->setSingleShot(val);
  return 0;
}

int timer_delete(lua_State *L) {
  QTimer *timer =
    *static_cast<QTimer**>(luaL_checkudata(L, 1, "timers.Timer"));
  delete timer;
  return 0;
}

int luaopen_timers(lua_State *L) {
  lua_newtable(L);

  luaL_newmetatable(L, "timers.Timer");

  lua_newtable(L);
  luaL_Reg timer_functions[] = {
    { "start", &timer_start },
    { "interval", &timer_interval },
    { "stop", &timer_stop },
    { "reset", &timer_reset },
    { "setInterval", &timer_set_interval },
    { "setSingleShot", &timer_set_single_shot },
    { NULL, NULL }
  };
  luaL_setfuncs(L, timer_functions, 0);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, timer_delete);
  lua_setfield(L, -2, "__gc");/*}}}*/

  luaL_Reg timers_functions[] = {
    { "Timer", &timer_create },
    { NULL, NULL }
  };
  luaL_newlib(L, timers_functions);
  return 1;
}
