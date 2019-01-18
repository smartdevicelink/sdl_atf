#line 12 "network.nw"
#include "network.h"

#include <QAbstractSocket>
#include <QTcpSocket>
#include <QTcpServer>
#include <QWebSocket>
#include <QEventLoop>
#include <QString>
#include <unistd.h>
#include <errno.h>
#include <cstring>
#include <cstdio>
#line 22 "network.nw"
// TcpClient functions/*{{{*/
int network_tcp_client(lua_State *L) {/*{{{*/
  QTcpSocket  *tcpSocket = new QTcpSocket();
  QTcpSocket **p = static_cast<QTcpSocket**>(lua_newuserdata(L, sizeof(QTcpServer*)));
  *p = tcpSocket;
  luaL_getmetatable(L, "network.TcpSocket");
  lua_setmetatable(L, -2);
  return 1;
}/*}}}*/
int tcp_socket_connect(lua_State *L) {/*{{{*/

#line 65 "network.nw"
QTcpSocket *tcpSocket =
  *static_cast<QTcpSocket**>(luaL_checkudata(L, 1, "network.TcpSocket"));
#line 33 "network.nw"
  const char* ip   = luaL_checkstring(L, 2);
  int         port = luaL_checkinteger(L, 3);


  tcpSocket->connectToHost(ip, port);

  QTime timer;
  timer.start();
  while (!tcpSocket->waitForConnected()) {
    tcpSocket->connectToHost(ip, port);
    // Check elapsed time
    const int time_waiting_ms = 3000;
    if (timer.elapsed() > time_waiting_ms){
      fprintf(stderr, "%s\n%s\n", "Error: Connection not established", strerror(errno));
      return 1;
    }
  }
  return 0;
}/*}}}*/
int tcp_socket_read(lua_State *L) {/*{{{*/

#line 65 "network.nw"
QTcpSocket *tcpSocket =
  *static_cast<QTcpSocket**>(luaL_checkudata(L, 1, "network.TcpSocket"));
#line 40 "network.nw"
  int maxSize = luaL_checkinteger(L, 2);
  if(tcpSocket->isOpen()){
    QByteArray result = tcpSocket->read(maxSize);
    lua_pushlstring(L, result.data(), result.count());
  } else {
    fprintf(stderr, "Error: Socket not opened");
  }
  return 1;
}/*}}}*/


int tcp_socket_read_all(lua_State *L) {/*{{{*/

#line 65 "network.nw"
QTcpSocket *tcpSocket =
  *static_cast<QTcpSocket**>(luaL_checkudata(L, 1, "network.TcpSocket"));
#line 40 "network.nw"
  QByteArray result = tcpSocket->readAll();
  lua_pushlstring(L, result.data(), result.count());
  return 1;
}/*}}}*/

int tcp_socket_write(lua_State *L) {/*{{{*/

#line 65 "network.nw"
QTcpSocket *tcpSocket =
  *static_cast<QTcpSocket**>(luaL_checkudata(L, 1, "network.TcpSocket"));
#line 47 "network.nw"
  size_t size;
  const char* data = luaL_checklstring(L, 2, &size);
  if(tcpSocket->isOpen()) {
    int result = tcpSocket->write(data, size);
    lua_pushinteger(L, result);
  } else {
    fprintf(stderr, "Error: Socket not opened");
  }
  return 1;
}/*}}}*/
int tcp_socket_close(lua_State *L) {/*{{{*/

#line 65 "network.nw"
QTcpSocket *tcpSocket =
  *static_cast<QTcpSocket**>(luaL_checkudata(L, 1, "network.TcpSocket"));
#line 55 "network.nw"
  tcpSocket->close();
  return 0;
}/*}}}*/
int tcp_socket_delete(lua_State *L) {/*{{{*/

#line 65 "network.nw"
QTcpSocket *tcpSocket =
  *static_cast<QTcpSocket**>(luaL_checkudata(L, 1, "network.TcpSocket"));
#line 60 "network.nw"
  delete tcpSocket;
  return 0;
}/*}}}*/
/*}}}*/
#line 69 "network.nw"
// TcpServer functions/*{{{*/
int network_tcp_server(lua_State *L) {/*{{{*/
  QTcpServer *tcpServer = new QTcpServer();
  QTcpServer **p = static_cast<QTcpServer**>(lua_newuserdata(L, sizeof(QTcpServer*)));
  *p = tcpServer;
  luaL_getmetatable(L, "network.TcpServer");
  lua_setmetatable(L, -2);
  return 1;
}/*}}}*/
int tcp_server_listen(lua_State *L)/*{{{*/
{

#line 111 "network.nw"
QTcpServer *tcpServer =
  *static_cast<QTcpServer**>(luaL_checkudata(L, 1, "network.TcpServer"));
#line 81 "network.nw"
  const char * ip = luaL_checkstring(L, 2);
  QHostAddress addr(ip);
  int port = luaL_checkinteger(L, 3);
  lua_pushboolean(L, tcpServer->listen(QHostAddress::Any, port));

  return 1;
}/*}}}*/
int tcp_server_get_connection(lua_State *L)/*{{{*/
{

#line 111 "network.nw"
QTcpServer *tcpServer =
  *static_cast<QTcpServer**>(luaL_checkudata(L, 1, "network.TcpServer"));
#line 91 "network.nw"
  QTcpSocket *tcpSocket = tcpServer->nextPendingConnection();
  if (tcpSocket) {
    QTcpSocket **p = static_cast<QTcpSocket**>(lua_newuserdata(L, sizeof(QTcpServer*)));
    *p = tcpSocket;
    luaL_getmetatable(L, "network.TcpSocket");
    lua_setmetatable(L, -2);
  } else {
    lua_pushnil(L);
  }

  return 1;
}/*}}}*/
int tcp_server_delete(lua_State *L) {/*{{{*/

#line 111 "network.nw"
QTcpServer *tcpServer =
  *static_cast<QTcpServer**>(luaL_checkudata(L, 1, "network.TcpServer"));
#line 105 "network.nw"
  delete tcpServer;
  return 0;
}/*}}}*/

/*}}}*/
#line 115 "network.nw"
// WebSocket functions/*{{{*/
int network_web_socket(lua_State *L) {/*{{{*/
  QWebSocket *webSocket = new QWebSocket();
  QWebSocket **p = static_cast<QWebSocket**>(lua_newuserdata(L, sizeof(QWebSocket*)));
  *p = webSocket;
  luaL_getmetatable(L, "network.WebSocket");
  lua_setmetatable(L, -2);
  return 1;
}/*}}}*/

int web_socket_open(lua_State *L) {/*{{{*/

#line 153 "network.nw"
QWebSocket *webSocket =
  *static_cast<QWebSocket**>(luaL_checkudata(L, 1, "network.WebSocket"));
#line 126 "network.nw"
  QUrl url(luaL_checkstring(L, 2));
  url.setPort(lua_tointegerx(L, 3, NULL));

  QEventLoop loop;
  #line 170 "network.nw"

  // Create connection when websocket connected
  QObject::connect(webSocket, SIGNAL(connected()), &loop, SLOT(quit()));
  QObject::connect(webSocket, SIGNAL(disconnected()), &loop, SLOT(quit()));

  // Wait until socket connection is established
  while (webSocket->state() != QAbstractSocket::ConnectedState) {
    webSocket->open(url);
    loop.exec();
    usleep(100);
  }

  return 0;
}/*}}}*/
int web_socket_close(lua_State *L) {/*{{{*/

#line 153 "network.nw"
QWebSocket *webSocket =
  *static_cast<QWebSocket**>(luaL_checkudata(L, 1, "network.WebSocket"));
#line 133 "network.nw"
  webSocket->close();
  return 0;
}/*}}}*/
int web_socket_write(lua_State *L) {/*{{{*/

#line 153 "network.nw"
QWebSocket *webSocket =
  *static_cast<QWebSocket**>(luaL_checkudata(L, 1, "network.WebSocket"));
#line 138 "network.nw"
  size_t size;
  const char* data = luaL_checklstring(L, 2, &size);
  QByteArray b(data, size);
  int res = webSocket->sendTextMessage(b);
  lua_pushinteger(L, res);
  return 1;
}/*}}}*/

int web_socket_delete(lua_State *L) {/*{{{*/

#line 153 "network.nw"
QWebSocket *webSocket =
  *static_cast<QWebSocket**>(luaL_checkudata(L, 1, "network.WebSocket"));
#line 148 "network.nw"
  delete webSocket;
  return 0;
}/*}}}*/
/*}}}*/
#line 158 "network.nw"
int luaopen_network(lua_State *L) {
  lua_newtable(L);

  // TcpServer metatable/*{{{*/
  luaL_newmetatable(L, "network.TcpServer");

  lua_newtable(L);
  luaL_Reg tcp_server_functions[] = {
    { "listen", &tcp_server_listen },
    { "get_connection", &tcp_server_get_connection },
    { NULL, NULL }
  };
  luaL_setfuncs(L, tcp_server_functions, 0);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, tcp_server_delete);
  lua_setfield(L, -2, "__gc");/*}}}*/
  // TcpSocket metatable/*{{{*/
  luaL_newmetatable(L, "network.TcpSocket");

  lua_newtable(L);
  luaL_Reg tcp_socket_functions[] = {
    { "connect", &tcp_socket_connect },
    { "read", &tcp_socket_read },
    { "read_all", &tcp_socket_read_all },
    { "write", &tcp_socket_write },
    { "close", &tcp_socket_close },
    { NULL, NULL }
  };
  luaL_setfuncs(L, tcp_socket_functions, 0);

  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, tcp_socket_delete);
  lua_setfield(L, -2, "__gc");/*}}}*/
  // WebSocket metatable/*{{{*/
  luaL_newmetatable(L, "network.WebSocket");
  lua_newtable(L);
  luaL_Reg web_socket_functions[] = {
    { "open", &web_socket_open },
    { "close", &web_socket_close },
    { "write", &web_socket_write },
    { NULL, NULL }
  };
  luaL_setfuncs(L, web_socket_functions, 0);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, web_socket_delete);
  lua_setfield(L, -2, "__gc");/*}}}*/

  luaL_Reg network_functions[] = {
    { "TcpClient", &network_tcp_client },
    { "TcpServer", &network_tcp_server },
    { "WebSocket", &network_web_socket },
    { NULL, NULL }
  };
  luaL_newlib(L, network_functions);
  return 1;
}
