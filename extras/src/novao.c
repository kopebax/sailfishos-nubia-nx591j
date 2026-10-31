/* novao: hide the OES/ARB vertex array object entry points from an app.
 *
 * MapLibre (Pure Maps) uses VAOs when it can resolve glBindVertexArrayOES.
 * With the Adreno 510 driver under libhybris the buffer bindings recorded in
 * a VAO get lost when zooming, so the driver dereferences buffer offsets as
 * client pointers and crashes in memcpy. Returning NULL for these functions
 * makes MapLibre fall back to plain vertex attribute setup.
 *
 * Use: LD_PRELOAD=/usr/lib64/libnovao.so <app>
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>

typedef void (*proc_t)(void);

static int is_vao(const char *name)
{
    return name && strstr(name, "VertexArray") &&
           (!strncmp(name, "glBindVertexArray", 17) ||
            !strncmp(name, "glGenVertexArrays", 17) ||
            !strncmp(name, "glDeleteVertexArrays", 20) ||
            !strncmp(name, "glIsVertexArray", 15));
}

proc_t eglGetProcAddress(const char *name)
{
    static proc_t (*real)(const char *);
    if (is_vao(name))
        return NULL;
    if (!real)
        real = (proc_t (*)(const char *))dlsym(RTLD_NEXT, "eglGetProcAddress");
    return real ? real(name) : NULL;
}
