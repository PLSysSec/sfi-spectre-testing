#include "measure.h"
#include <stdint.h>

void beginTest(uint64_t);

int main(int argc, char const *argv[])
{
    beginTest(ITERATIONS);
    return 0;
}