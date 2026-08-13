#import <Foundation/Foundation.h>
#include "clipwire.h"

int run_exploit(void);

int main(int argc, char *argv[])
{
    @autoreleasepool {
        LOG("clipwire starting (pid %d)", getpid());

        int rc = run_exploit();
        LOG("clipwire finished rc=%d", rc);

        if (rc == 0) {
            LOG("primitive established - process will exit cleanly");
        }
        sleep(1);
    }
    return 0;
}
