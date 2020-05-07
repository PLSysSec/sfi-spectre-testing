#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>

typedef int (*beginTestType)();

int main(int argc, char const *argv[])
{
    printf("Testing CET dynlib\n");
    {
        void* dl = dlopen("./cet_branch_test_dl_helper.so", RTLD_NOW);
        if (!dl) {
            printf("dlopen failed\n");
            abort();
        }

        beginTestType beginTest = (beginTestType) dlsym(dl, "beginTest");
        if (!beginTest) {
            printf("dlsym failed\n");
            abort();
        }

        int ret = beginTest();
        if (ret) {
            return ret;
        }
    }
    printf("Testing Non CET dynlib\n");
    {
        void* dl = dlopen("./nocet_branch_test_dl_helper.so", RTLD_NOW);
        if (!dl) {
            printf("dlopen failed\n");
            abort();
        }

        beginTestType beginTest = (beginTestType) dlsym(dl, "beginTest");
        if (!beginTest) {
            printf("dlsym failed\n");
            abort();
        }

        int ret = beginTest();
        if (ret) {
            return ret;
        }
    }

    return 0;
}
