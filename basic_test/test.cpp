#include <stdio.h>

extern "C"
{
    int singleBranch(int val)
    {
        if (val) {
            return 5;
        } else {
            return 7;
        }
    }

    void printBranch(int val)
    {
        if (val) {
            printf("if side\n");
        } else {
            printf("else side\n");
        }
    }
}

int main(int argc, char** argv)
{
    singleBranch(argc);
}