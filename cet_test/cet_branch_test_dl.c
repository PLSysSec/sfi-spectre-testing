#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>

typedef int (*beginTestType)();

int main(int argc, char const *argv[])
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

    return beginTest();
}
