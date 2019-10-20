#include <defs.h>
#include <x86.h>
#include <elf.h>

/* *********************************************************************
 * This a dirt simple boot loader, whose sole job is to boot
 * an ELF kernel image from the first IDE hard disk.
 *
 * DISK LAYOUT
 *  * This program(bootasm.S and bootmain.c) is the bootloader.
 *    It should be stored in the first sector of the disk.
 *
 *  * The 2nd sector onward holds the kernel image.
 *
 *  * The kernel image must be in ELF format.
 *
 * BOOT UP STEPS
 *  * when the CPU boots it loads the BIOS into memory and executes it
 *
 *  * the BIOS intializes devices, sets of the interrupt routines, and
 *    reads the first sector of the boot device(e.g., hard-drive)
 *    into memory and jumps to it.
 *
 *  * Assuming this boot loader is stored in the first sector of the
 *    hard-drive, this code takes over...
 *
 *  * control starts in bootasm.S -- which sets up protected mode,
 *    and a stack so C code then run, then calls bootmain()
 *
 *  * bootmain() in this file takes over, reads in the kernel and jumps to it.
 * */

#define SECTSIZE        512
#define ELFHDR          ((struct elfhdr *)0x10000)      // scratch space

/* waitdisk - wait for disk ready */
static void
waitdisk(void) {
    while ((inb(0x1F7) & 0xC0) != 0x40) //检查磁盘是否准备就绪需要检查0x1F7的最高两位，如果是01，那么证明磁盘准备就绪
        /* do nothing */;
}

/* readsect - read a single sector at @secno into @dst */
static void
readsect(void *dst, uint32_t secno) {
    // wait for disk to be ready
    waitdisk();

    outb(0x1F2, 1);                         // 要读取的扇区数量为1
    outb(0x1F3, secno & 0xFF);              //传入LBA参数的0-7位 将secno的32位分为四个8位传递 带符号右移八位
    outb(0x1F4, (secno >> 8) & 0xFF);       //传入LBA参数的8-15位
    outb(0x1F5, (secno >> 16) & 0xFF);      //传入LBA参数的16-23位
    outb(0x1F6, ((secno >> 24) & 0xF) | 0xE0); //LBA参数24-27位 第28位为0为主盘，为1位从盘 29到31位为1
    outb(0x1F7, 0x20);                      // cmd 0x20 - read sectors 发出读命令0x20

    // wait for disk to be ready
    waitdisk();

    // read a sector
    insl(0x1F0, dst, SECTSIZE / 4);    //从数据端口0x1F0读取字符串数据到dst，除以4是因为此处是以4个字节为单位的
}

/* *
 * readseg - read @count bytes at @offset from kernel into virtual address @va,
 * might copy more than asked.
 * */
static void
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    uintptr_t end_va = va + count;

    // round down to sector boundary  va-（offset % SECTSIZE）可以得到va所在的块的首地址
    va -= offset % SECTSIZE;

    // translate from bytes to sectors; kernel starts at sector 1
    uint32_t secno = (offset / SECTSIZE) + 1;

    // If this is too slow, we could read lots of sectors at a time.
    // We'd write more to memory than asked, but it doesn't matter --
    // we load in increasing order.
    for (; va < end_va; va += SECTSIZE, secno ++) {
        readsect((void *)va, secno);
    }
}

/* bootmain - the entry of bootloader */
void
bootmain(void) {
    // read the 1st page off disk 从磁盘的第一个扇区（第零个扇区为bootloader）中读取OS kenerl最开始的4kB代码，然后判断其最开始四个字节是否等于指定的ELF_MAGIC
    readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);

    // is this a valid ELF?
    if (ELFHDR->e_magic != ELF_MAGIC) {
        goto bad;
    }

    struct proghdr *ph, *eph;  //段表首地址，段表末地址

    // load each program segment (ignores ph flags)
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);//e_phoff，是program header表的位置偏移
    eph = ph + ELFHDR->e_phnum;                //入口数目
    for (; ph < eph; ph ++) {              //从每一个program header中获取到段应该被加载到内存中的位置，以及段的大小，然后调用readseg函数将每一个段加载到内存中
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    }

    // call the entry point from the ELF header
    // note: does not return
    // void(*h)() h为一个没有返回值的函数指针
    // (void(*)())表示一个指向没有返回值的函数的指针”的类型转。
    // ((void(*)())0)，这是取0地址开始的一段内存里面的内容，其内容就是保存在首地址为0的一段区域内的函数。下面的函数同理，第二个void缺省
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();//从ELF header中查询到OS kernel的入口地址，然后使用函数调用的方式跳转到该地址上去

bad:
    outw(0x8A00, 0x8A00);
    outw(0x8A00, 0x8E00);

    /* do nothing */
    while (1);
}

