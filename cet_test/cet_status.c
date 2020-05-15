#include <asm/prctl.h>
#include <sys/prctl.h>
#include <stdio.h>
#include <unistd.h>

#define ARCH_CET_STATUS 0x3001

int main(int argc, char *argv[])
{
    unsigned long long stat[3];
    int r = prctl(ARCH_CET_STATUS, stat);
    if (r) {
        printf("ARCH_CET_STATUS failed!\n");
        return -1;
    }

    printf("self pid = %d, features: %llx, shstk_base = %016lx, size = %016lx\n",
        getpid(), stat[0], (long) stat[1], (long) stat[2]);

    return 0;
}
