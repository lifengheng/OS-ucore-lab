#include <asm.h>

# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG,        0x8                     # kernel code segment selector
.set PROT_MODE_DSEG,        0x10                    # kernel data segment selector
.set CR0_PE_ON,             0x1                     # protected mode enable flag

# start address should be 0:7c00, in real mode, the beginning address of the running bootloader
.globl start
start:
.code16                                             # Assemble for 16-bit mode 关中断
    cli                                             # 0 -> IF Disable interrupts Clears the interrupt flag if the current privilege level is at least as privileged
                                                    # as IOPL; affects no other flags. External interrupts disabled at the end of the
                                                    # cli instruction or from that point on until the interrupt flag is set.

    

    cld                                             # 0 -> DF String operations increment Clears the direction flag; affects no other flags or registers. Causes all
                                                    # subsequent string operations to increment the index registers, (E)SI and/or
                                                    # (E)DI, used during the operation.

    # Set up the important data segment registers (DS, ES, SS).
    xorw %ax, %ax                                   # Segment number zero
    movw %ax, %ds                                   # -> Data Segment (w short for word,16bits) 
    movw %ax, %es                                   # -> Extra Segment
    movw %ax, %ss                                   # -> Stack Segment

    # Enable A20:
    #  For backwards compatibility with the earliest PCs, physical
    #  address line 20 is tied low, so that addresses higher than
    #  1MB wrap around to zero by default. This code undoes this.
    # 对于8042芯片来说，有两个端口地址60h和64h。对于这两个端口来说，0x64用来发送一个键盘控制命令，0x60用来传递参数
seta20.1:                                           # inb -> al inw ->ax inl ->eax 
                                                    # 读status register的值到al中，其中SR的第二位值是1表示 input register（60h/64h）中有数据
    inb $0x64, %al                                  # Input from Port Wait for not busy(8042 input buffer empty).
    testb $0x2, %al                                 # logical AND 如果读出来的值与00000010（0x2）进行逻辑与运算，为1则重复此操作
                                                    # The OF and CF flags are cleared; SF, ZF and PF flags are set according to theresult.
    jnz seta20.1                                    # jump if not zero

    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port

seta20.2:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.2

    movb $0xdf, %al                                 # 0xdf -> port 0x60
    outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1
    #     理论上讲，我们只要操作8042芯片的输出端口（64h）的bit 1，就可以控制A20 Gate，但实际上，当你
    # 准备向8042的输入缓冲区里写数据时，可能里面还有其它数据没有处理，所以，我们要首先
    # 禁止键盘操作，同时等待数据缓冲区中没有数据以后，才能真正地去操作8042打开或者关闭
    # A20 Gate。
    # Switch from real to protected mode, using a bootstrap GDT
    # and segment translation that makes virtual addresses
    # identical to physical addresses, so that the
    # effective memory map does not change during the switch.
   
    lgdt gdtdesc             #Load the Global/Interrupt Descriptor Table Register from memory address
    movl %cr0, %eax          #需要将%cr0的最低位置为1，才能开启保护模式
    orl $CR0_PE_ON, %eax        #0x1 or的结果在eax中
    movl %eax, %cr0

    # Jump to next instruction, but in 32-bit code segment.
    # Switches processor into 32-bit mode.
    ljmp $PROT_MODE_CSEG, $protcseg              # long jump 将$PROT_MODE_CSEG作为CS寄存器的值, $protcseg为EIP寄存器的值 

.code32                                             # Assemble for 32-bit mode
protcseg:
    # Set up the protected-mode data segment registers
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    movw %ax, %ds                                   # -> DS: Data Segment
    movw %ax, %es                                   # -> ES: Extra Segment
    movw %ax, %fs                                   # -> FS  General-purpose segment register
    movw %ax, %gs                                   # -> GS  General-purpose segment register
    movw %ax, %ss                                   # -> SS: Stack Segment

    # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
    movl $0x0, %ebp
    movl $start, %esp
    call bootmain

    # If bootmain returns (it shouldn't), loop.
spin:
    jmp spin

# Bootstrap GDT
.p2align 2                                          # force 4 byte alignment
gdt:                                                # GDT全局描述符表由三个全局描述符组成，第一个均为空描述符，第二个为代码段描述符，第三个为数据段描述符
    SEG_NULLASM 
    SEG_ASM(STA_X|STAR,0x0, 0xffffffff)           # code seg for bootloader and kernel
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel

gdtdesc:
    .word 0x17                                      # sizeof(gdt) - 1 GDT表的大小
    .long gdt                                       # address gdt  GDT表的入口地址
