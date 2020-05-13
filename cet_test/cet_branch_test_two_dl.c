#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <sys/mman.h>
#include <asm/prctl.h>
#include <sys/prctl.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

typedef int (*beginTestType)();

extern void *__libc_stack_end;

void* dlopen_with_cetflag(const char* path, int disable_indirect_branch_checking, unsigned char *bitmap) {
    void* dl = dlopen(path, RTLD_NOW);
    if (!dl) {
        printf("dlopen failed: %s\n", dlerror());
        abort();
    }

    // Assume that dl is just one page for now
    // TODO: fix this later
    if (disable_indirect_branch_checking) {
        // Hack to get the code page of the dl
        // TODO: cleanup using dladdr
        void* dl_codepage = *((void**)dl);
        // Disable checking in the legacy bitmap
        unsigned long page = (unsigned long)dl_codepage / 0x1000;
        unsigned long byte = page / 8;
        unsigned long bit = page % 8;
        bitmap[byte] |= (0x01 << bit);
    }
    return dl;
}

int main(int argc, char const *argv[])
{
    // Setup the legacy bitmap. Need a bit for all pages of userspace memory
    // Userspace ends with the stack so use that as a reference point
    size_t bitmap_size = ((uintptr_t) __libc_stack_end / sysconf(_SC_PAGESIZE) / 8);
    unsigned char *bitmap = mmap(NULL,
        bitmap_size,
        PROT_READ | PROT_WRITE,
        MAP_ANON | MAP_PRIVATE | MAP_NORESERVE,
        -1,
        0);

    if (bitmap == MAP_FAILED) {
        printf("mmap failed: %s\n", strerror(errno));
        abort();
    }

    unsigned long legacy_bitmap[2];
    legacy_bitmap[0] = (uintptr_t)bitmap;
    legacy_bitmap[1] = bitmap_size;

    printf("\nstack_end:%p, size:%lx, bitmap:%p, *bitmap:%x\n",
        __libc_stack_end, bitmap_size, (void*) bitmap, *bitmap);

    // Set the bitmap
    // (dl_cet_allocate_legacy_bitmap): Call arch_prctl with ARCH_CET_LEGACY_BITMAP
    # define ARCH_CET_LEGACY_BITMAP 0x3006
    int ret = prctl(ARCH_CET_LEGACY_BITMAP, legacy_bitmap);
    if (ret != 0) {
        printf("Setting the legacy bitmap failed: %s\n", strerror(errno));
        abort();
    }

    printf("Testing Non CET dynlib\n");
    {
        void* dl = dlopen_with_cetflag("./nocet_branch_test_dl_helper.so",
            /* disable_indirect_branch_checking */ 1,
            bitmap);

        beginTestType beginTest = (beginTestType) dlsym(dl, "beginTest");
        if (!beginTest) {
            printf("dlsym failed: %s\n", dlerror());
            abort();
        }

        int ret = beginTest();
        if (ret) {
            return ret;
        }
    }

    printf("Testing CET dynlib\n");
    {
        void* dl = dlopen_with_cetflag("./nocet_branch_test_dl_helper.so",
            /* disable_indirect_branch_checking */ 0,
            bitmap);

        beginTestType beginTest = (beginTestType) dlsym(dl, "beginTest");
        if (!beginTest) {
            printf("dlsym failed: %s\n", dlerror());
            abort();
        }

        int ret = beginTest();
        if (ret) {
            return ret;
        }
    }

    return 0;
}
