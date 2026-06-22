#ifndef GREETING_H
#define GREETING_H

/* Shared app logic (the "<app>_core"): linked by every artifact — the default
   bin, the sim bin, and the unit test. Lives outside main.c so tests can
   exercise it without a duplicate main(). */
const char *greeting(void);

#endif /* GREETING_H */
