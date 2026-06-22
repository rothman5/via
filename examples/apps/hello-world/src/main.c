#include <stdio.h>

#include "greeting.h"
#include "via_build.h"

/* Default bin (src/main.c) → `nix build .#hello`. */
int main(void)
{
    printf("%s\n", greeting());
    printf("  package:  %s %s\n", VIA_PKG_NAME, VIA_PKG_VERSION);
    printf("  artifact: %s (%s)\n", VIA_ARTIFACT, VIA_PROFILE);
    return 0;
}
