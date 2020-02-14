#include <stdio.h>

extern "C"
{
    int spec_singleBranch(int val)
    {
        if (val) {
            return 5;
        } else {
            return 7;
        }
    }

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
}

int main(int argc, char** argv)
{
    int val = spec_singleBranch(argc);
    if (val != 5) {
        return -1;
    }
}