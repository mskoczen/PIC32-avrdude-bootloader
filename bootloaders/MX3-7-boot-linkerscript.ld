/* Default linker script, for normal executables */
OUTPUT_FORMAT("elf32-tradlittlemips")
OUTPUT_ARCH(pic32mx)
ENTRY(_reset)
/*
 * Provide for a minimum stack and heap size
 * - _min_stack_size - represents the minimum space that must be made
 *                     available for the stack.  Can be overridden from
 *                     the command line using the linker's --defsym option.
 * - _min_heap_size  - represents the minimum space that must be made
 *                     available for the heap.  Can be overridden from
 *                     the command line using the linker's --defsym option.
 */
EXTERN (_min_stack_size _min_heap_size)
PROVIDE(_min_stack_size = 0x400) ;
PROVIDE(_min_heap_size = 0) ;
/*************************************************************************
 * Processor-specific object file.  Contains SFR definitions.
 *************************************************************************/
INPUT("processor.o")

/*************************************************************************
 * For interrupt vector handling
 *************************************************************************/
PROVIDE(_vector_spacing = 0x00000001);

/*************************************************************************
 * Memory Regions
 *
 * Memory regions without attributes cannot be used for orphaned sections.
 * Only sections specifically assigned to these regions can be allocated
 * into these regions.
 *************************************************************************/
MEMORY
{
  kseg1_boot_mem             : ORIGIN = 0xBFC00000, LENGTH = 0x0380
  debug_vectors				 : ORIGIN = 0xBFC00380, LENGTH = 0x110
  kseg0_boot_mem             : ORIGIN = 0x9FC00490, LENGTH = 0x0
  kseg0_program_mem    (rx)  : ORIGIN = 0x9FC00490, LENGTH = 0x1B60
  exception_mem              : ORIGIN = 0xBFC01FF0, LENGTH = 0x10
  debug_exec_mem             : ORIGIN = 0xBFC02000, LENGTH = 0xFF0
  config3                    : ORIGIN = 0xBFC02FF0, LENGTH = 0x4
  config2                    : ORIGIN = 0xBFC02FF4, LENGTH = 0x4
  config1                    : ORIGIN = 0xBFC02FF8, LENGTH = 0x4
  config0                    : ORIGIN = 0xBFC02FFC, LENGTH = 0x4
  kseg1_data_mem       (w!x) : ORIGIN = 0xA0000000, LENGTH = 0x2000
  sfrs                       : ORIGIN = 0xBF800000, LENGTH = 0x100000
  configsfrs                 : ORIGIN = 0xBFC02FF0, LENGTH = 0x10
}

/*************************************************************************
 * Memory Address Equates
 *************************************************************************/
_ebase_address  			= ORIGIN(kseg1_boot_mem);
_RESET_ADDR             	= _ebase_address;
_DBG_EXCPT_ADDR         	= ORIGIN(exception_mem);
_DBG_CODE_ADDR 				= ORIGIN(debug_exec_mem);
_RAM_SKIP_SIZE				= 0x600;

/*_BEV_EXCPT_ADDR          = 0xBFC00FB0; */
/*_GEN_EXCPT_ADDR          = 0xBFC00FC0; */

SECTIONS
{
  .config_BFC02FF0 : {
    KEEP(*(.config_BFC02FF0))
  } > config3
  .config_BFC02FF4 : {
    KEEP(*(.config_BFC02FF4))
  } > config2
  .config_BFC02FF8 : {
    KEEP(*(.config_BFC02FF8))
  } > config1
  .config_BFC02FFC : {
    KEEP(*(.config_BFC02FFC))
  } > config0
}

SECTIONS
{
  /* Boot Sections */
  .reset _RESET_ADDR :
  {
    KEEP(*(.reset))
/*    KEEP(*(.startup)) */
    KEEP(*(.reset.startup)) 
  } > kseg1_boot_mem
/*
  .bev_excpt _BEV_EXCPT_ADDR :
  {
    KEEP(*(.bev_handler))
  } > kseg1_boot_mem
*/
  /*  Starting with C32 v2.00, the startup code is in the .reset.startup section.
   *  Keep this here for backwards compatibility.
   */
/*
  .startup ORIGIN(kseg0_boot_mem) :
  {
    KEEP(*(.startup))
  } > kseg0_boot_mem
*/ 
  /* Code Sections - Note that input sections *(.text) and *(.text.*)
  ** are not mapped here. Starting in C32 v2.00, the best-fit allocator
  ** locates them, so that .text may flow around absolute sections
  ** as needed.
  */
  .text :
  {
    *(.stub .gnu.linkonce.t.*)
    KEEP (*(.text.*personality*))
    *(.mips16.fn.*)
    *(.mips16.call.*)
    *(.gnu.warning)
  } >kseg0_program_mem
  /* Read-only sections */
  .rodata   :
  {
    *( /* .rodata */  .rodata.* .gnu.linkonce.r.*)
    *(.rodata1)
    . = ALIGN(4) ;
  } >kseg0_program_mem
  /*
   * Small initialized constant global and static data can be placed in the
   * .sdata2 section.  This is different from .sdata, which contains small
   * initialized non-constant global and static data.
   */
  .sdata2 ALIGN(4)   :
  {
    *(.sdata2 .sdata2.* .gnu.linkonce.s2.*)
    . = ALIGN(4) ;
  } >kseg0_program_mem
  /*
   * Uninitialized constant global and static data (i.e., variables which will
   * always be zero).  Again, this is different from .sbss, which contains
   * small non-initialized, non-constant global and static data.
   */
  .sbss2 ALIGN(4)   :
  {
    *(.sbss2 .sbss2.* .gnu.linkonce.sb2.*)
    . = ALIGN(4) ;
  } >kseg0_program_mem
  .eh_frame_hdr : { *(.eh_frame_hdr) }
  .eh_frame       : ONLY_IF_RO { KEEP (*(.eh_frame)) }

 
   /*
	* We always need to keep this space, if it is not
	* used by the debugger, it is used by shared RAM
	* with the loading sketch.	
	*/	
  .dbg_data ORIGIN(kseg1_data_mem) :
  {
   _skip_ram_space_addr = . ;
     . += 0x200;
  } >kseg1_data_mem

   /*
	* Now we need to reserve the max shared ram
	*/	
  .skip_ram_space :
  {
    . += (_RAM_SKIP_SIZE - SIZEOF(.dbg_data));
	_skip_ram_space_end_adder = .;
  } >kseg1_data_mem

  .eh_frame       : ONLY_IF_RW { KEEP (*(.eh_frame)) }
  . = .;
   _gp = ALIGN(16) + 0x7ff0;

  .got ALIGN(4)   :
  {
     *(.got.plt) *(.got)
  } >kseg1_data_mem /* AT>kseg0_program_mem */
  /*
   * Note that "small" data sections are still mapped in the linker
   * script. This ensures that they are grouped together for
   * gp-relative addressing. Absolute sections are allocated after
   * the "small" data sections so small data cannot flow around them.
   */
  /*
   * We want the small data sections together, so single-instruction offsets
   * can access them all, and initialized data all before uninitialized, so
   * we can shorten the on-disk segment size.
   */
  .sdata ALIGN(4) /*   */ :
  {
    _sdata_begin = . ;
    *(.sdata .sdata.* .gnu.linkonce.s.*)
    _sdata_end = . ;
  } >kseg1_data_mem
  .lit8           :
  {
    *(.lit8)
  } >kseg1_data_mem
  .lit4           :
  {
    *(.lit4)
  } >kseg1_data_mem
  . = ALIGN (4) ;
  _data_end = . ;
  _bss_begin = . ;
  .sbss ALIGN(4)   :
  {
    _sbss_begin = . ;
    *(.dynsbss)
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
    _sbss_end = . ;
  } >kseg1_data_mem
  /*
   * Note that input sections named .data* are no longer mapped here.
   * Starting in C32 v2.00, the best-fit allocator locates them, so
   * that they may flow around absolute sections as needed.
   */
  /*
   * Align here to ensure that the .bss section occupies space up to
   * _end.  Align after .bss to ensure correct alignment even if the
   * .bss section disappears because there are no input sections.
   *
   * Note that input sections named .bss* are no longer mapped here.
   * Starting in C32 v2.00, the best-fit allocator locates them, so
   * that they may flow around absolute sections as needed.
   *
   */
  .bss   :
  {
    *(.dynbss)
    *(COMMON)
    . = ALIGN(4) ;
  } >kseg1_data_mem
  . = ALIGN(4) ;
  _end = . ;
  _bss_end = . ;
 /* Starting with C32 v2.00, the heap and stack are dynamically
   * allocated by the linker.
   */
  /*
   * RAM functions go at the end of our stack and heap allocation.
   * Alignment of 2K required by the boundary register (BMXDKPBA).
   *
   * RAM functions are now allocated by the linker. The linker generates
   * _ramfunc_begin and _bmxdkpba_address symbols depending on the
   * location of RAM functions.
   */
  _bmxdudba_address = LENGTH(kseg1_data_mem) ;
  _bmxdupba_address = LENGTH(kseg1_data_mem) ;
    /* The .pdr section belongs in the absolute section */
    /DISCARD/ : { *(.pdr) }
    /* We don't load .reginfo onto the target, so don't locate it
     * in real memory
     */
    /DISCARD/ : { *(.reginfo) }
  /* Stabs debugging sections.  */
  .stab          0 : { *(.stab) }
  .stabstr       0 : { *(.stabstr) }
  .stab.excl     0 : { *(.stab.excl) }
  .stab.exclstr  0 : { *(.stab.exclstr) }
  .stab.index    0 : { *(.stab.index) }
  .stab.indexstr 0 : { *(.stab.indexstr) }
  .comment       0 : { *(.comment) }
  /* DWARF debug sections.
     Symbols in the DWARF debugging sections are relative to the beginning
     of the section so we begin them at 0.  */
  /* DWARF 1 */
  .debug          0 : { *(.debug) }
  .line           0 : { *(.line) }
  /* GNU DWARF 1 extensions */
  .debug_srcinfo  0 : { *(.debug_srcinfo) }
  .debug_sfnames  0 : { *(.debug_sfnames) }
  /* DWARF 1.1 and DWARF 2 */
  .debug_aranges  0 : { *(.debug_aranges) }
  .debug_pubnames 0 : { *(.debug_pubnames) }
  /* DWARF 2 */
  .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
  .debug_abbrev   0 : { *(.debug_abbrev) }
  .debug_line     0 : { *(.debug_line) }
  .debug_frame    0 : { *(.debug_frame) }
  .debug_str      0 : { *(.debug_str) }
  .debug_loc      0 : { *(.debug_loc) }
  .debug_macinfo  0 : { *(.debug_macinfo) }
  /* SGI/MIPS DWARF 2 extensions */
  .debug_weaknames 0 : { *(.debug_weaknames) }
  .debug_funcnames 0 : { *(.debug_funcnames) }
  .debug_typenames 0 : { *(.debug_typenames) }
  .debug_varnames  0 : { *(.debug_varnames) }
  .debug_pubtypes 0 : { *(.debug_pubtypes) }
  .debug_ranges   0 : { *(.debug_ranges) }
  /DISCARD/ : { *(.rel.dyn) }
  .gnu.attributes 0 : { KEEP (*(.gnu.attributes)) }
  /DISCARD/ : { *(.note.GNU-stack) }
  /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) *(.discard) }
}
