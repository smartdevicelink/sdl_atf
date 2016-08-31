#pragma once

extern "C" {
#include <lua5.2/lua.h>
#include <lua5.2/lualib.h>
#include <lua5.2/lauxlib.h>
}

#include <QString>
#include <QDateTime>
#include <QtGlobal>

int luaopen_qdatetime(lua_State *L);
