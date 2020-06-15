#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <time.h>
#include <stdint.h>

extern "C"
{
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
}

#define ITERATIONS 1000000
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

typedef struct {
    int field1;
    int field2;
    int* field3;
} St;

extern "C"
{
    const int spec_GL_int_val = 5;
    const float spec_GL_float_val = 5.0;
    const char spec_GL_char_val[] = "Testing 123";

    __attribute__((noinline))
    int spec_singleBranch(int val)
    {
        if (val) {
            return spec_GL_int_val;
        } else {
            return 7;
        }
    }

    __attribute__((noinline))
    float spec_singleBranchFloat(float val)
    {
        if (val > 0) {
            return spec_GL_float_val;
        } else {
            return 7.0;
        }
    }

    __attribute__((noinline))
    void spec_printBranch(int val)
    {
        if (val) {
            printf("if side\n");
        } else {
            printf("else side\n");
        }

        printf("%s\n", spec_GL_char_val);

        for(int i = 0; i < val; i++){
            printf("Val: %d\n", val);
        }
    }

    __attribute__((noinline))
    void spec_printBranch2(int val)
    {
        for(int i = 0; i < val; i++){
            printf("Val: %d\n", val);
        }
    }

    __attribute__((noinline))
    void spec_printDoWhile(int val)
    {
        do {
            printf("Val: %d\n", val);
            val--;
        } while (val > 0);
    }

    __attribute__((noinline))
    int spec_switch(int val) {
        switch (val)
        {
        case 1:
            return val + 1;
        case 2:
            printf("Val = 2\n");
            break;
        case 3:
            printf("Val = 3\n");
            return val * 6  - 7;
        default:
            return val;
        }

        return 0;
    }

    __attribute__((noinline))
    int spec_switch2(int val, int val2) {
        switch (val)
        {
            case 1:
                printf("Int:%d\n", val2);
                return 20;
            case 2:
                puts("Case2\n");
                return 27;
        }

        return 33;
    }

        __attribute__((noinline))
    int spec_switch_wierd(int val) {
        switch (val)
        {
        case 23:
            printf("Case 1\n");
        case 41:
            printf("Case 2\n");
            break;
        case 49:
            printf("Case 3\n");
            return val * 6  - 7;
        default:
            return val;
        }

        return 0;
    }

    __attribute__((noinline))
    int spec_if2(int val, int val2) {
        if (val == 1) {
            printf("Int:%d\n", val2);
            return 20;
        } else {
            puts("Case2\n");
            return 27;
        }
    }

    int spec_float_compare(float x, int val2) {
        if (x > 5.5) {
            printf("Int:%d\n", val2);
            return 20;
        } else {
            puts("Case2\n");
            return 27;
        }
    }

    __attribute__((noinline))
    int spec_call_ptr(int(*fn)())
    {
        int ret = 1 + fn();
        spec_printBranch(ret);
        return ret;
    }

    __attribute__((noinline))
    int spec_get_val1() {
        return 7;
    }

    __attribute__((noinline))
    int spec_get_val2() {
        return 9;
    }

    __attribute__((noinline))
    int spec_get_structp_field(St* ptr) {
        return ptr->field2;
    }

    __attribute__((noinline))
    int spec_get_structpp_field(St** ptr) {
        return (*ptr)->field2;
    }

    __attribute__((noinline))
    int spec_get_structpc_field(St* ptr, int c) {
        return (ptr + c)->field2;
    }

    __attribute__((noinline))
    int spec_get_structp_field_arr(St* ptr, int c) {
        return ptr->field3[c];
    }

    __attribute__((noinline))
    unsigned int spec_shr(unsigned int v) {
        return v >> 3;
    }

    __attribute__((noinline))
    unsigned int spec_shl(unsigned int v) {
        return v << 3;
    }

    __attribute__((noinline))
    unsigned int spec_uextend(unsigned short a)
    {
        return a;
    }

    __attribute__((noinline))
    unsigned short spec_ushorten(unsigned int a)
    {
        return a;
    }

    // Any inner loops in C (not C++) functions with name starting with "spec_nestedFor" are index optimized not heap optimized
    __attribute__((noinline))
    unsigned int spec_nestedFor(const char* a) {
        unsigned int ret = 0;
        volatile const char* copy = a;
        while(*copy) {
            copy++;
        }
        ret = copy - a;
        return ret;
    }

    __attribute__((noinline))
    unsigned int spec_NoOptNestedFor(const char* a) {
        unsigned int ret = 0;
        volatile const char* copy = a;
        while(*copy) {
            copy++;
        }
        ret = copy - a;
        return ret;
    }

    // Any inner loops in C (not C++) functions with name starting with "spec_nestedFor" are index optimized not heap optimized
    __attribute__((noinline))
    unsigned int spec_nestedFor2(const char* a, const char* b) {
        unsigned int ret = 0;
        volatile const char* copy = a;
        volatile const char* copyB = b;
        while(*copy && *copyB) {
            copy++;
            copyB++;
        }
        ret = copy - a;
        return ret;
    }

    __attribute__((noinline))
    unsigned int spec_NoOptNestedFor2(const char* a, const char* b) {
        unsigned int ret = 0;
        volatile const char* copy = a;
        volatile const char* copyB = b;
        while(*copy && *copyB) {
            copy++;
            copyB++;
        }
        ret = copy - a;
        return ret;
    }

    // Any inner loops in C (not C++) functions with name starting with "spec_nestedFor" are index optimized not heap optimized
    __attribute__((noinline))
    unsigned int spec_nestedFor3(const char* a, const char* b) {
        unsigned int ret = 0;
        volatile char scratchSpace[1000];
        volatile const char* copy = a;
        volatile const char* copyB = b;
        while(*copy && *copyB) {
            scratchSpace[*copy] = 1;
            scratchSpace[*copy] = 2;
            scratchSpace[*copy] = 3;
            scratchSpace[*copyB] = 4;
            scratchSpace[*copyB] = 5;
            scratchSpace[*copyB] = 6;
            copy++;
            copyB++;
        }
        ret = copy - a;
        return ret;
    }

    __attribute__((noinline))
    unsigned int spec_NoOptNestedFor3(const char* a, const char* b) {
        unsigned int ret = 0;
        volatile char scratchSpace[1000];
        volatile const char* copy = a;
        volatile const char* copyB = b;
        while(*copy && *copyB) {
            scratchSpace[*copy] = 1;
            scratchSpace[*copy] = 2;
            scratchSpace[*copy] = 3;
            scratchSpace[*copyB] = 4;
            scratchSpace[*copyB] = 5;
            scratchSpace[*copyB] = 6;
            copy++;
            copyB++;
        }
        ret = copy - a;
        return ret;
    }
}

void indexMaskingTest1() {

    const char* a =
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
    ;

    unsigned int loop;

    {
        // warmup
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor(a);
        }
    }

    {
        StartTimer(test_strlen_heapmask_first);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor(a);
        }
        EndTimer(test_strlen_heapmask_first);
        printf("Loop ret: %u\n", loop);
    }

    {
        // warmup
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_nestedFor(a);
        }
    }

    {
        StartTimer(test_strlen_indexmask);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_nestedFor(a);
        }
        EndTimer(test_strlen_indexmask);
        printf("Loop ret: %u\n", loop);
    }

    {
        // warmup
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor(a);
        }
    }

    {
        StartTimer(test_strlen_heapmask_again_just_in_case);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor(a);
        }
        EndTimer(test_strlen_heapmask_again_just_in_case);
        printf("Loop ret: %u\n", loop);
    }

    printf("-----------------------Perf test 1 complete -------------------\n");
}



void indexMaskingTest2() {

    const char* a =
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
    ;

    const char* b =
        "if (spec_if2(2, 100) != 27) {"
        "    printf(Test4 failed\n);"
        "    return -1;"
        "}"
        "if (spec_if2(3, 100) != 27) {"
        "    printf(Test5 failed\n);"
        "    return -1;"
        "}";

    unsigned int loop;

    {
        // warmup
        loop = spec_NoOptNestedFor2(a, b);
    }

    {
        StartTimer(test_strlen_heapmask_first);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor2(a, b);
        }
        EndTimer(test_strlen_heapmask_first);
        printf("Loop ret: %u\n", loop);
    }

    {
        // warmup
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_nestedFor2(a, b);
        }
    }

    {
        StartTimer(test_strlen_indexmask);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_nestedFor2(a, b);
        }
        EndTimer(test_strlen_indexmask);
        printf("Loop ret: %u\n", loop);
    }

    {
        // warmup
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor2(a, b);
        }
    }

    {
        StartTimer(test_strlen_heapmask_again_just_in_case);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor2(a, b);
        }
        EndTimer(test_strlen_heapmask_again_just_in_case);
        printf("Loop ret: %u\n", loop);
    }

    printf("-----------------------Perf test 2 complete -------------------\n");
}


void indexMaskingTest3() {

    const char* a =
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
        "A long string to test for strlength static void timespec_diff(struct timespec *start, struct timespec *stop, "
        "if ((stop->tv_nsec - start->tv_nsec) < 0) {"
        "StartTimer(test);"
        "loop = spec_nestedFor(a, i, j);"
        "EndTimer(test);"
    ;

    const char* b =
        "if (spec_if2(2, 100) != 27) {"
        "    printf(Test4 failed\n);"
        "    return -1;"
        "}"
        "if (spec_if2(3, 100) != 27) {"
        "    printf(Test5 failed\n);"
        "    return -1;"
        "}";

    unsigned int loop;

    {
        // warmup
        loop = spec_NoOptNestedFor2(a, b);
    }

    {
        StartTimer(test_strlen_heapmask_first);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor2(a, b);
        }
        EndTimer(test_strlen_heapmask_first);
        printf("Loop ret: %u\n", loop);
    }

    {
        // warmup
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_nestedFor2(a, b);
        }
    }

    {
        StartTimer(test_strlen_indexmask);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_nestedFor2(a, b);
        }
        EndTimer(test_strlen_indexmask);
        printf("Loop ret: %u\n", loop);
    }

    {
        // warmup
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor2(a, b);
        }
    }

    {
        StartTimer(test_strlen_heapmask_again_just_in_case);
        for (int i = 0; i < ITERATIONS; i++) {
            loop = spec_NoOptNestedFor2(a, b);
        }
        EndTimer(test_strlen_heapmask_again_just_in_case);
        printf("Loop ret: %u\n", loop);
    }

    printf("-----------------------Perf test 3 complete -------------------\n");
}

int main(int argc, char** argv)
{
    int val = spec_singleBranch(argc);
    if (val != 5) {
        printf("Test1 failed\n");
        return -1;
    }

    int (*fn)() = 0;
    if (argc) {
        fn = spec_get_val1;
    } else {
        fn = spec_get_val2;
    }
    int val2 = spec_call_ptr(fn);
    if (val2 != 8) {
        printf("Test2 failed\n");
        return -1;
    }

    int val3 = spec_switch(3);
    if (val3 != 11) {
        printf("Test3 failed\n");
        return -1;
    }

    if (spec_if2(1, 100) != 20) {
        printf("Test3 failed\n");
        return -1;
    }
    if (spec_if2(2, 100) != 27) {
        printf("Test4 failed\n");
        return -1;
    }
    if (spec_if2(3, 100) != 27) {
        printf("Test5 failed\n");
        return -1;
    }

    if (spec_singleBranchFloat (1.0) > 6.5) {
        printf("Test6 failed\n");
        return -1;
    }

    // Perf tests for index op

    // Tests are of the form
    // warmup heap mask --- run first
    // test heap mask --- run first
    // warmup index mask
    // test index mask
    // warmup heap mask --- run again to make sure we aren't biasing something weird
    // test heap mask --- run again to make sure we aren't biasing something weird

    indexMaskingTest1();
    indexMaskingTest2();
    indexMaskingTest3();


    return 0;
}
