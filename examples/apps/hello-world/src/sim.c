#include <stdio.h>

#include "greeting.h"
#include "via_build.h"

/* Named bin (src/bin/sim.c) → `nix build .#hello-sim`. A "host simulator" that
   reuses the same core logic as the default bin. */
int main(void)
{
    for (int i = 0; i < 3; i++) {
        printf("[sim %d] %s (%s)\n", i, greeting(), VIA_ARTIFACT);
    }
    return 0;
}
