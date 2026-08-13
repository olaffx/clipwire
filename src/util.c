#include "clipwire.h"

U64 g_kern_slide = 0;
U64 g_kern_base = KERNEL_TEXT_BASE_STATIC;

static bool g_initialized = false;



void clipwire_init(void)
{
    if (g_initialized) return;
    setbuf(stdout, NULL);
    g_kern_slide = get_kernel_slide();
    g_kern_base = KERNEL_TEXT_BASE_STATIC + g_kern_slide;
    g_initialized = true;
}

void nsleep(U64 ns)
{
    struct timespec ts;
    ts.tv_sec = ns / 1000000000ULL;
    ts.tv_nsec = ns % 1000000000ULL;
    nanosleep(&ts, NULL);
}

bool check_target(void)
{
    struct utsname u;
    if (uname(&u) != 0) {
        LOGBAD("uname failed (%d)", errno);
        return false;
    }
    LOG("running on %s %s", u.machine, u.version);

    if (strcmp(u.machine, "iPhone12,1") != 0) {
        LOGWARN("device is %s, offsets/validation written for iPhone12,1 (A13)", u.machine);
        LOGWARN("continuing anyway - static addresses only used for diagnostics");
    }

    char osver[256] = {0};
    size_t len = sizeof(osver);
    if (sysctlbyname("kern.osversion", osver, &len, NULL, 0) == 0) {
        LOG("kern.osversion: %s", osver);
        if (strcmp(osver, "23B85") != 0) {
            LOGWARN("expected 23B85 (iOS 26.1), got %s", osver);
        }
    }
    return true;
}
