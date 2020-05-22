#define _GNU_SOURCE

#include "measure.h"
#include <time.h>
#include <stdio.h>
#include <stdint.h>

static void timespec_diff(struct timespec *start, struct timespec *stop,
                   struct timespec *result)
{
    if ((stop->tv_nsec - start->tv_nsec) < 0) {
        result->tv_sec = stop->tv_sec - start->tv_sec - 1;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec + 1000000000;
    } else {
        result->tv_sec = stop->tv_sec - start->tv_sec;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec;
    }

    return;
}

#define StartTimer(name) \
    struct timespec tstart_##name={0,0}, tend_##name={0,0}; \
    clock_gettime(CLOCK_MONOTONIC, &tstart_##name); \
    do {} while (0)


#define EndTimer(name) \
    clock_gettime(CLOCK_MONOTONIC, &tend_##name); \
    struct timespec timer_##name; \
    timespec_diff(&tstart_##name, &tend_##name, &timer_##name); \
    uint64_t totalTime_##name = (uint64_t)(timer_##name.tv_sec) * 1000000000  + timer_##name.tv_nsec; \
    double time_##name = ((double)totalTime_##name) / ITERATIONS; \
    printf(#name " took %.5f nanoseconds\n", time_##name); \
    do {} while (0)


uint32_t test_func_invocation() {
    return 42;
}

uint32_t hostcall_get_value();

void host_call_invocation() {
    StartTimer(Hostcall);
    for (uint64_t i = 0; i < ITERATIONS; i++) {
        hostcall_get_value();
    }
    EndTimer(Hostcall);
    fflush(stdout);
}


int main(int argc, char const *argv[])
{
    test_func_invocation();
    host_call_invocation();
    return 0;
}