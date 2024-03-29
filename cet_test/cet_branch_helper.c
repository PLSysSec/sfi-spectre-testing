#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

void sig_handler(int sig_num)
{
    printf("CET C: caught invalid jump!!!\n");
    exit(0);
}


int indirect_call() {
    printf("CET C: invalid jump succeeded...\n");
    return 42;
}

typedef int(*FuncType)();

int beginTest()
{
    if (signal(SIGILL, sig_handler) == SIG_ERR) {
        printf("Setting signal handler for SIGILL failed\n");
        exit(1);
    }
    if (signal(SIGABRT, sig_handler) == SIG_ERR) {
        printf("Setting signal handler for SIGABRT failed\n");
        exit(1);
    }
    if (signal(SIGSEGV, sig_handler) == SIG_ERR) {
        printf("Setting signal handler for SIGSEGV failed\n");
        exit(1);
    }

    char* func_ptr = (char*) indirect_call;
    // When compiled with CET branch checking indirect_call starts with the 4 byte endbr instruction
    // Skip past that
    func_ptr += 4;
    // invoke --- this will work on non CET systems and fail if CET branch checking is enabled
    int result = ((FuncType)func_ptr)();
    //sanity check
    if (result != 42)
    {
        printf("CET App Failed\n");
        exit(1);
    }

    signal(SIGILL, SIG_DFL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);

    return 0;
}
