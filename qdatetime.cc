#include "qdatetime.h"

int qdatetime_get_datetime(lua_State *L) {
  const QDateTime time(QDateTime::currentDateTime());
  const char* const format_raw = luaL_checkstring(L, 1);
  const QString format(format_raw);
  const QString time_string(time.toString(format));
  const char* const time_string_raw = qPrintable(time_string);
  lua_pushstring(L, time_string_raw);
  return 1;
}

int luaopen_qdatetime(lua_State *L) {
  const luaL_Reg qdatetime_lib [] = {
    {"get_datetime", qdatetime_get_datetime},
    {NULL, NULL}
  };
  luaL_newlib(L, qdatetime_lib);
  return 1;
}
