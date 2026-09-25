/*
 * LD_PRELOAD shim for building packages on Modal.
 *
 * Modal runs functions under gVisor, which does not implement openat2(2)
 * (ENOSYS). GNU tar (via gnulib) uses openat2 to walk paths and has no
 * fallback, so every `dpkg-deb --build` fails with "Cannot stat: Function not
 * implemented". This maps openat2 to plain openat. The RESOLVE_* restrictions
 * are dropped, which is fine in a throwaway build container that only packs
 * its own files.
 *
 * Build: gcc -shared -fPIC -O2 -o /usr/local/lib/openat2-shim.so openat2-shim.c -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h> /* glibc >= 2.42 declares openat2 and struct open_how */
#include <stdarg.h>
#include <sys/syscall.h>
#include <unistd.h>

static long emulate(int dirfd, const char *path, const struct open_how *how)
{
    return openat(dirfd, path, (int)how->flags, (mode_t)how->mode);
}

int openat2(int dirfd, const char *path, const struct open_how *how, size_t size)
{
    (void)size;
    return (int)emulate(dirfd, path, how);
}

long syscall(long number, ...)
{
    va_list ap;
    va_start(ap, number);
    long a[6];
    for (int i = 0; i < 6; i++)
        a[i] = va_arg(ap, long);
    va_end(ap);

    if (number == SYS_openat2)
        return emulate((int)a[0], (const char *)a[1], (const struct open_how *)a[2]);

    static long (*real)(long, ...);
    if (!real)
        real = (long (*)(long, ...))dlsym(RTLD_NEXT, "syscall");
    return real(number, a[0], a[1], a[2], a[3], a[4], a[5]);
}
