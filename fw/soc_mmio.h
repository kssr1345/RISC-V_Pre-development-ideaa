#pragma once

#define COUNTER_BASE 0x20000000u
#define INTC_BASE    0x20001000u
#define DMA_BASE     0x20002000u

#define REG32(addr) (*(volatile unsigned int *)(addr))
