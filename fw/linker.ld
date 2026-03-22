ENTRY(_start)

MEMORY {
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  SRAM (rwx): ORIGIN = 0x10000000, LENGTH = 512K
}

SECTIONS {
  .text : {
    KEEP(*(.text.start))
    *(.text*)
    *(.rodata*)
  } > SRAM

  .data : { *(.data*) } > SRAM
  .bss  : {
    __bss_start = .;
    *(.bss*) *(COMMON)
    __bss_end = .;
  } > SRAM

  . = ALIGN(64);
  .dma_src (NOLOAD) : { *(.dma_src*) } > SRAM
  . = ALIGN(64);
  .dma_dst (NOLOAD) : { *(.dma_dst*) } > SRAM

  _stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}
