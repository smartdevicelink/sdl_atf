#line 5 "main.nw"
#include <stdarg.h>
#include <string.h>
extern "C" {
#include <lua5.2/lua.h>
#include <lua5.2/lualib.h>
#include <lua5.2/lauxlib.h>
}
#line 6 "xml.nw"
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xpath.h>
#include <libxml/xmlsave.h>

#include <iostream>
#include <assert.h>
#include <stdarg.h>
#include <string.h>

namespace {
void genericErrorHandler(void *ctx, const char* message, ...){
  lua_State *L = static_cast<lua_State*>(ctx);
  va_list args;
  va_start(args, message);
  char msg[1024] = { 0 };
  snprintf(msg, 1023, message, args);
  va_end(args);
  lua_pushstring(L, msg);
  lua_error(L);
}

void structuredErrorHandler(void *userData, xmlErrorPtr err) {
  lua_State *L = static_cast<lua_State*>(userData);
  const size_t msg_size = 1024;
  char msg[msg_size];
  int pos = 0;

  switch(err->domain) {
    case XML_FROM_XPATH:
      pos += snprintf(msg, msg_size, "Error evaluating xpath query:\n");
      break;
    case XML_FROM_PARSER:
      pos += snprintf(msg, msg_size, "Error parsing xml file:\n");
      break;
    // TODO(EZamakhov): add more domain errors from xmlErrorDomain enum
    default:
      pos += snprintf(msg, msg_size, "Other error:\n");
      break;
  }

  // append error information to out msg
  if (err->file &&
      pos < msg_size) {
    pos += snprintf(msg + pos, msg_size - pos,
                    "%s:%d: ", err->file, err->line);
  }
  if (err->message &&
      pos < msg_size) {
    pos += snprintf(msg + pos, msg_size - pos,
                   "%s", err->message);
  }
  if (err->str1 &&
      pos < msg_size) {
    pos += snprintf(msg + pos, msg_size - pos,
                    ": %s", err->str1);
  }
  if (err->str2 &&
      pos < msg_size) {
    pos += snprintf(msg + pos, msg_size - pos,
                    ": %s", err->str2);
  }
  if (err->str3 &&
      pos < msg_size) {
    pos += snprintf(msg + pos, msg_size - pos,
                    ": %s", err->str3);
  }
  lua_pushstring(L, msg);
  lua_error(L);
}

int xml_open(lua_State *L) {
  const char *filename = luaL_checkstring(L, 1);
  xmlDoc *doc = xmlReadFile(filename, nullptr, 0);
  if (!doc) {
    lua_pushnil(L);
    lua_pushstring(L, "Invalid xml file");
    return 2;
  }
  xmlDoc **p =  static_cast<xmlDoc**>(lua_newuserdata(L, sizeof(xmlDoc*)));
  *p = doc;
  luaL_getmetatable(L, "xml.Document");
  lua_setmetatable(L, -2);
  return 1;
}

int xml_new(lua_State *L) {
  auto doc = xmlNewDoc(BAD_CAST "1.0");
  xmlDoc **p =  static_cast<xmlDoc**>(lua_newuserdata(L, sizeof(xmlDoc*)));
  *p = doc;
  luaL_getmetatable(L, "xml.Document");
  lua_setmetatable(L, -2);
  return 1;
}
#line 99 "xml.nw"
int eval_xpath(lua_State *L, xmlDocPtr doc, xmlNodePtr node, const xmlChar* query) {
  xmlXPathContextPtr context = xmlXPathNewContext(doc);
  if (!context) {
    lua_pushnil(L);
    lua_pushstring(L, "Error creating xpath context");
    return 2;
  }
  if (node) {
    xmlXPathSetContextNode(node, context);
  }
  xmlXPathObjectPtr result = xmlXPathEvalExpression(query, context);
  xmlXPathFreeContext(context);
  if (!result) {
    lua_pushnil(L);
    lua_pushstring(L, "Error evaluating xpath query: \"");
    lua_pushstring(L, reinterpret_cast<const char*>(query));
    lua_pushstring(L, "\"");
    lua_concat(L, 2);
    lua_concat(L, 2);
    return 2;
  }

  
#line 188 "xml.nw"
switch(result->type) {
  case XPATH_NODESET:
    // Haven't the slightest idea why, but libxml returns result
    // of type XPATH_NODESET but nodesetval == 0 on some queries
    if (!result->nodesetval) {
      lua_pushnil(L);
      break;
    }
    lua_createtable(L, result->nodesetval->nodeNr, 0);
    luaL_getmetatable(L, "xml.Node");
    for (int i = 0; i < result->nodesetval->nodeNr; ++i) {
      auto n = result->nodesetval->nodeTab[i];
      if (n->type == XML_ELEMENT_NODE) {
        xmlNodePtr* p = static_cast<xmlNodePtr*>(lua_newuserdata(L, sizeof(xmlNodePtr)));
        *p = n;
        lua_pushnil(L);
        lua_copy(L, -3, -1);
        lua_setmetatable(L, -2);
      } else if (n->type == XML_TEXT_NODE) {
        lua_pushstring(L, reinterpret_cast<const char*>(n->content));
      } else if (n->type == XML_ATTRIBUTE_NODE) {
        assert(n->children);
        assert(n->children->type == XML_TEXT_NODE);
        lua_pushstring(L, reinterpret_cast<const char*>(n->children->content));
      } else {
        continue;
      }
      lua_rawseti(L, -3, i + 1);
    }
    lua_pop(L, 1);
    break;
  case XPATH_BOOLEAN:
    lua_pushboolean(L, result->boolval);
    break;
  case XPATH_NUMBER:
    lua_pushnumber(L, result->floatval);
    break;
  case XPATH_STRING:
    lua_pushstring(L, reinterpret_cast<const char*>(result->stringval));
    break;
  default:
    lua_pushnil(L);
}
#line 122 "xml.nw"
  
  xmlXPathFreeObject(result);
  return 1;
}

int doc_xpath(lua_State *L) {
  xmlDoc *doc = *static_cast<xmlDoc**>(luaL_checkudata(L, 1, "xml.Document"));
  const xmlChar* query = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 2));
  return eval_xpath(L, doc, nullptr, query);
}

int doc_rootNode(lua_State *L) {
  xmlDoc *doc = *static_cast<xmlDoc**>(luaL_checkudata(L, 1, "xml.Document"));
  if (doc->children) {
    auto c = doc->children;
    while (c && c->type != XML_ELEMENT_NODE) { c = c->next; };
    if (c)
    {
      xmlNodePtr* p = static_cast<xmlNodePtr*>(lua_newuserdata(L, sizeof(xmlNodePtr)));
      *p = c;
      luaL_getmetatable(L, "xml.Node");
      lua_setmetatable(L, -2);
      return 1;
    }
  }
  lua_pushnil(L);
  return 1;
}

int doc_write(lua_State *L) {
  xmlDoc *doc = *static_cast<xmlDoc**>(luaL_checkudata(L, 1, "xml.Document"));
  const char* filename = luaL_checkstring(L, 2);
  bool format = lua_gettop(L) == 2 || lua_toboolean(L, 3);

  auto ctx = xmlSaveToFilename(filename, "utf-8", (format ? XML_SAVE_FORMAT : 0));
  xmlSaveDoc(ctx, doc);
  xmlSaveClose(ctx);
  return 0;
}

int doc_createRootNode(lua_State *L) {
  xmlDoc *doc = *static_cast<xmlDoc**>(luaL_checkudata(L, 1, "xml.Document"));
  const xmlChar* name = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 2));
  const xmlChar* content = nullptr;
  if (lua_gettop(L) > 2) {
    content = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 3));
  }
  auto node = xmlNewDocNode(doc, nullptr, name, content);
  xmlDocSetRootElement(doc, node);

  xmlNodePtr* p = static_cast<xmlNodePtr*>(lua_newuserdata(L, sizeof(xmlNodePtr)));
  *p = node;
  luaL_getmetatable(L, "xml.Node");
  lua_setmetatable(L, -2);
  return 1;
}

int node_addChild(lua_State *L) {
  xmlNodePtr parent = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  auto name = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 2));
  auto node = xmlNewNode(nullptr, name);
  xmlAddChild(parent, node);
  xmlNodePtr* p = static_cast<xmlNodePtr*>(lua_newuserdata(L, sizeof(xmlNodePtr)));
  *p = node;
  luaL_getmetatable(L, "xml.Node");
  lua_setmetatable(L, -2);
}

int xml_close(lua_State *L) {
  xmlDoc *doc = *static_cast<xmlDoc**>(luaL_checkudata(L, 1, "xml.Document"));
  xmlFreeDoc(doc);
  return 0;
}

int node_text(lua_State *L) {
  xmlNodePtr node = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  const xmlChar* text = nullptr;
  if (lua_gettop(L) > 1) {
    text = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 2));
    xmlNodeSetContent(node, text);
    lua_pop(L, 1);
    return 1;
  } else {
    xmlChar* text = xmlNodeGetContent(node);
    if (text) {
      lua_pushstring(L, reinterpret_cast<const char*>(text));
      xmlFree(text);
    } else {
      lua_pushstring(L, "<nil>");
    }
    return 1;
  }
}

int node_name(lua_State *L) {
  xmlNodePtr node = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  const xmlChar* text = node->name;
  if (text) {
    lua_pushstring(L, reinterpret_cast<const char*>(text));
  } else {
    lua_pushstring(L, "<nil>");
  }
  return 1;
}

int node_attr(lua_State *L) {
  xmlNodePtr node = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  auto attr = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 2));
  if (lua_gettop(L) < 3) {
    xmlChar* text = xmlGetProp(node, attr);
    if (text) {
      lua_pushstring(L, reinterpret_cast<const char*>(text));
      xmlFree(text);
    } else {
      lua_pushnil(L);
    }
    return 1;
  } else {
    if (lua_isnil(L, 3)) {
      xmlUnsetProp(node, attr);
    } else {
      const xmlChar* text = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 3));
      xmlSetProp(node, attr, text);
    }
    lua_pop(L, 2);
    return 1;
  }
}

int node_xpath(lua_State *L) {
  xmlNode *node = *static_cast<xmlNode**>(luaL_checkudata(L, 1, "xml.Node"));
  if (!node->doc) {
    return luaL_error(L, "Invalid xml.Node object: must be included in a document");
  }
  const xmlChar* query = reinterpret_cast<const xmlChar*>(luaL_checkstring(L, 2));
  return eval_xpath(L, node->doc, node, query);
}

int node_parent(lua_State *L) {
  xmlNodePtr node = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  if (node->parent) {
    xmlNodePtr* p = static_cast<xmlNodePtr*>(lua_newuserdata(L, sizeof(xmlNodePtr)));
    *p = node->parent;
    luaL_getmetatable(L, "xml.Node");
    lua_setmetatable(L, -2);
  } else {
    lua_pushnil(L);
  }
  return 1;
}

int node_children(lua_State *L) {
  xmlNodePtr node = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  const xmlChar* filter = nullptr;
  if (lua_isstring(L, 2)) {
    filter = reinterpret_cast<const xmlChar*>(lua_tostring(L, 2));
  }
  if (node->type == XML_ELEMENT_NODE) {
    lua_newtable(L);
    auto n = node->children;
    int i = 0;
    luaL_getmetatable(L, "xml.Node");
    while (n) {
      if (n->type == XML_ELEMENT_NODE) {
        if (!filter || xmlStrEqual(n->name, filter)) {
          xmlNodePtr* p = static_cast<xmlNodePtr*>(lua_newuserdata(L, sizeof(xmlNodePtr)));
          lua_pushnil(L);
          lua_copy(L, -3, -1);
          lua_setmetatable(L, -2);
          lua_rawseti(L, -3, ++i);
          *p = n;
        }
      }
      n = n->next;
    }
    lua_pop(L, 1);
  } else {
    lua_pushnil(L);
  }
  return 1;
}

int node_remove(lua_State *L) {
  xmlNodePtr node = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  xmlUnlinkNode(node);
  xmlFreeNode(node);
  return 0;
}

int node_attributes(lua_State *L) {
  xmlNodePtr node = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  if (node->type == XML_ELEMENT_NODE) {
    lua_newtable(L);
    auto n = node->properties;
    int i = 0;
    while (n) {
      if (n->type == XML_ATTRIBUTE_NODE) {
        lua_pushstring(L, reinterpret_cast<const char*>(n->name));
        lua_pushstring(L, reinterpret_cast<const char*>(xmlGetProp(node, n->name)));
        lua_rawset(L, -3);
      }
      n = n->next;
    }
  } else {
    lua_pushnil(L);
  }
  return 1;
}

int node_eq(lua_State *L) {
  xmlNodePtr a = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 1, "xml.Node"));
  xmlNodePtr b = *static_cast<xmlNodePtr*>(luaL_checkudata(L, 2, "xml.Node"));
  lua_pushboolean(L, a == b);
  return 1;
}
}
extern "C"
int luaopen_xml(lua_State *L, int ) {
  LIBXML_TEST_VERSION

  xmlSetGenericErrorFunc(L, &genericErrorHandler);
  xmlSetStructuredErrorFunc(L, &structuredErrorHandler);

  luaL_Reg functions[] = {
    { "open", &xml_open },
    { "new", &xml_new },
    { NULL, NULL }
  };

  luaL_newmetatable(L, "xml.Document");
  lua_newtable(L);
  luaL_Reg doc_functions[] = {
    { "xpath", &doc_xpath },
    { "rootNode", &doc_rootNode },
    { "write", &doc_write },
    { "createRootNode", &doc_createRootNode },
    { NULL, NULL }
  };
  luaL_setfuncs(L, doc_functions, 0);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, &xml_close);
  lua_setfield(L, -2, "__gc");

  luaL_newmetatable(L, "xml.Node");
  lua_newtable(L);
  luaL_Reg node_functions[] = {
    { "text", &node_text },
    { "name", &node_name },
    { "attr", &node_attr },
    { "xpath", &node_xpath },
    { "children", &node_children },
    { "parent", &node_parent },
    { "attributes", &node_attributes },
    { "addChild", &node_addChild },
    { "remove", &node_remove },
    { NULL, NULL }
  };
  luaL_setfuncs(L, node_functions, 0);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, &node_eq);
  lua_setfield(L, -2, "__eq");

  luaL_newlib(L, functions);
  return 1;
}
