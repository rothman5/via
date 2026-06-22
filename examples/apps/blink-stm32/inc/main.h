#ifndef MAIN_H
#define MAIN_H

/* App-owned main.h (like a CubeMX Core/Inc/main.h). The SDK's interrupt and MSP
   templates #include "main.h"; this minimal one gives them the HAL and the
   Error_Handler prototype without dragging in the board BSP that the SDK's own
   Templates/main.h pulls. Because the app's inc/ is on the include path ahead
   of the SDK's Templates/Inc, this file is the one they resolve. */

#include "stm32l4xx_hal.h"

void Error_Handler(void);

#endif /* MAIN_H */
