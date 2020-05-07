#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>
#include <asm/prctl.h>
#include <sys/prctl.h>

typedef int (*beginTestType)();

int main(int argc, char const *argv[])
{
    // https://sourceware.org/legacy-ml/libc-alpha/2018-07/msg00747.html
    // Setup the legacy bitmap
    // (dl_cet_allocate_legacy_bitmap): Call arch_prctl with ARCH_CET_LEGACY_BITMAP
    # define ARCH_CET_LEGACY_BITMAP 0x3005
    prctl(ARCH_CET_LEGACY_BITMAP, 0);

    printf("Testing Non CET dynlib\n");
    {
        void* dl = dlopen("./nocet_branch_test_dl_helper.so", RTLD_NOW);
        if (!dl) {
            printf("dlopen failed: %s\n", dlerror());
            abort();
        }

        beginTestType beginTest = (beginTestType) dlsym(dl, "beginTest");
        if (!beginTest) {
            printf("dlsym failed: %s\n", dlerror());
            abort();
        }

        int ret = beginTest();
        if (ret) {
            return ret;
        }
    }

    printf("Testing CET dynlib\n");
    {
        void* dl = dlopen("./cet_branch_test_dl_helper.so", RTLD_NOW);
        if (!dl) {
            printf("dlopen failed: %s\n", dlerror());
            abort();
        }

        beginTestType beginTest = (beginTestType) dlsym(dl, "beginTest");
        if (!beginTest) {
            printf("dlsym failed: %s\n", dlerror());
            abort();
        }

        int ret = beginTest();
        if (ret) {
            return ret;
        }
    }

    return 0;
}
