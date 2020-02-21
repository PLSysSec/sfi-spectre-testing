#include <stdio.h>

typedef struct {
    int field1;
    int field2;
    int* field3;
} St;

extern "C"
{
    __attribute__((noinline))
    int spec_singleBranch(int val)
    {
        if (val) {
            return 5;
        } else {
            return 7;
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

        for(int i = 0; i < val; i++){
            printf("Val: %d\n", val);
        }
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

}

int main(int argc, char** argv)
{
    int val = spec_singleBranch(argc);
    if (val != 5) {
        return -1;
    }

    int (*fn)() = 0;
    if (argc) {
        fn = spec_get_val1;
    } else {
        fn = spec_get_val2;
    }
    int val2 = spec_call_ptr(fn);
    if (val != 8) {
        return -1;
    }
}