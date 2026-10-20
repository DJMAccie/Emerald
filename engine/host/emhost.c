/* emhost: run a Lua script on the game's own LuaJIT (the Lua.framework inside gen1recomp.app).
 *
 *   emhost script.lua [args...]      (arg[0]=script, arg[1..]=args, as the luajit command line)
 *
 * Why not the system luajit: the headless dump must be byte-identical to the in-game one, and two LuaJIT
 * builds disagree on number formatting -- the game's 2.1.1700008891 writes string.format('%.1f', 35.25) as
 * "35.3" (ties away from zero), a 2026 build as "35.2" (ties to even) -- which alone moved 3750 of Route 103's
 * triangles. Same VM, same text. Built by engine/geo.sh into the engine cache (never committed):
 *   clang -O2 -o emhost emhost.c -F<app>/Contents/Frameworks -framework Lua -Wl,-rpath,<app>/Contents/Frameworks
 * Only the stock Lua 5.1 C API is used; the prototypes are declared here (the app ships no headers). */
#include <stdio.h>
#include <stddef.h>

typedef struct lua_State lua_State;
extern lua_State *luaL_newstate(void);
extern void luaL_openlibs(lua_State *L);
extern int luaL_loadstring(lua_State *L, const char *s);
extern int lua_pcall(lua_State *L, int nargs, int nresults, int errfunc);
extern const char *lua_tolstring(lua_State *L, int idx, size_t *len);
extern void lua_createtable(lua_State *L, int narr, int nrec);
extern void lua_pushstring(lua_State *L, const char *s);
extern void lua_rawseti(lua_State *L, int idx, int n);
extern void lua_setfield(lua_State *L, int idx, const char *k);
extern void lua_close(lua_State *L);
#define LUA_GLOBALSINDEX (-10002)

static const char *BOOT =
  "local script=arg[0]\n"
  "local f,err=loadfile(script)\n"
  "if not f then io.stderr:write(tostring(err)..'\\n') os.exit(2) end\n"
  "local ok,e=xpcall(function() return f(unpack(arg)) end,debug.traceback)\n"
  "if not ok then io.stderr:write(tostring(e)..'\\n') io.stderr:flush() os.exit(1) end\n";

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: emhost script.lua [args...]\n"); return 2; }
  lua_State *L = luaL_newstate();
  if (!L) { fprintf(stderr, "emhost: no Lua state\n"); return 3; }
  luaL_openlibs(L);
  lua_createtable(L, argc, 1);
  for (int i = 1; i < argc; i++) { lua_pushstring(L, argv[i]); lua_rawseti(L, -2, i - 1); }
  lua_setfield(L, LUA_GLOBALSINDEX, "arg");
  if (luaL_loadstring(L, BOOT) != 0 || lua_pcall(L, 0, 0, 0) != 0) {
    const char *m = lua_tolstring(L, -1, NULL);
    fprintf(stderr, "emhost: %s\n", m ? m : "error");
    lua_close(L);
    return 1;
  }
  lua_close(L);
  return 0;
}
