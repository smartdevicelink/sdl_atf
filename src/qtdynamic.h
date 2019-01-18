#line 16 "dynamic_object.nw"
#pragma once
#include <QObject>
#include <QMetaObject>
#include <QHash>
#include <QByteArray>
#line 5 "main.nw"
extern "C" {
#include <lua5.2/lua.h>
#include <lua5.2/lualib.h>
#include <lua5.2/lauxlib.h>
}
#line 21 "dynamic_object.nw"
#include "marshal.h"
#line 26 "dynamic_object.nw"
class DynamicSlot
{
 public:
  DynamicSlot(lua_State *L, int objidx, const char* signature);
  void call(QObject *sender, void **arguments);
 private:
  lua_State *lua_state;
  QList<Marshaller*> marshallers_;
  int objidx_;
  QString slot_;
};
#line 44 "dynamic_object.nw"
class DynamicObject : public QObject {
 public:
  DynamicObject(QObject *parent);
  virtual int qt_metacall(QMetaObject::Call c, int id, void **arguments);
  bool emitDynamicSignal(const char *signal, void **arguments);
  bool connectDynamicSignal(const char *signal, QObject *obj, const char *slot);
  bool connectDynamicSlot(QObject *obj, const char *signal, const char *slot, DynamicSlot *s);
  static bool connectDynamicSignalToDynamicSlot(
    DynamicObject* sender,
    const char *signal,
    DynamicObject* receiver,
    const char *slot,
    DynamicSlot *s);
 private:
  QHash<QByteArray, int> slotIndices;
  QList<DynamicSlot *> slotList;
  QHash<QByteArray, int> signalIndices;
};
