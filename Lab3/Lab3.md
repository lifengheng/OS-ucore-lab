##                                           Lab3

### 给未被映射的地址映射上物理页

![](D:\os_lab\Lab3\do_pagefault.png)

练习一只需要将未映射的虚拟地址映射上物理页，首先获取当前发生缺页的虚拟页对应的PTE，如果虚拟的物理页只是没有分配而不是被换出，就分配新的物理页。

### 2.补充完成基于FIFO的页面替换算法

上一问的else就是现在需要实现的。如果交换机制被正确初始化，调用swap_in()将物理页面换入内存中

wap_in函数会进一步调用alloc_page函数进行分配物理页，一旦没有足够的物理页，则会使用swap_out函数将当前物理空间的某一页换出到外存，该函数会进一步调用sm（swap manager）中封装的swap_out_victim函数来选择需要换出的物理页，该函数是一个函数指针进行调用的，具体对应到了`_fifo_swap_out_victim`函数（因为在本练习中使用了FIFO替换算法），在FIFO算法中，按照物理页面换入到内存中的顺序建立了一个链表，因此链表头处便指向了最早进入的物理页面，也就在在本算法中需要被换出的页面，因此只需要将链表头的物理页面取出，然后删掉对应的链表项即可；具体的代码实现如下所示：

![](D:\os_lab\Lab3\swappable.png)

![](D:\os_lab\Lab3\victim.png)

###如果要在ucore上实现"extended clock页替换算法"请给你的设计方案，现有的swap_manager框架是否足以支持在ucore中实现此算法？如果是，请给你的设计方案。
如果不是，请给出你的新的扩展和基此扩展的设计方案。并需要回答如下问题，需要被换出的页的特征是什么？
在ucore中如何判断具有这样特征的页？
何时进行换入和换出操作？
是。因为PTE中就有dirty位和访问位。被换出的页是脏位和访问位都为0

执行在ucore中增加如果访问某页，就将访问位置1，修改某页，将两位都置1.然后再在链表中循环查找，如果预计（0,0）就替换。第一次访问将访问位置0，第二次访问将脏位置0，也就是将内存中被修改的数据写回磁盘。如果这期间没有新的访问，那么最多只需两次遍历当前页表项，就能找到可以被替换的页表。