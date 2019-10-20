OBJPREFIX	:= __objs_

.SECONDEXPANSION:
# -------------------- function begin --------------------
# $(if condition,then-part[,else-part])
# list all files in some directories: (#directories, #types) 
#选择某一目录下.$(2)的后缀形式的文件
listf = $(filter $(if $(2),$(addprefix %.,$(2)),%),\          
		  $(wildcard $(addsuffix $(SLASH)*,$(1)))) #wildcard $(1)/* 匹配$(1)目录下的所有文件

# get .o obj files: (#files[, packet])     把传入的文件名列表的所有后缀都改为.o  $(basename names) 把文件的的后缀名去掉
toobj = $(addprefix $(OBJDIR)$(SLASH)$(if $(2),$(2)$(SLASH)),\      
		$(addsuffix .o,$(basename $(1))))

# get .d dependency files: (#files[, packet])  $(patsubst %.o,%.d,x.o.o bar.o)->‘x.o.d bar.d’.
todep = $(patsubst %.o,%.d,$(call toobj,$(1),$(2)))

totarget = $(addprefix $(BINDIR)$(SLASH),$(1))

# change $(name) to $(OBJPREFIX)$(name): (#names)
packetname = $(if $(1),$(addprefix $(OBJPREFIX),$(1)),$(OBJPREFIX))

# cc compile template, generate rule for dep, obj: (file, cc[, flags, dir])
# 后文中将对这个部分执行eval，$$ shell variable $ make variable $$$$ secondary expression enabled and a literal dollar sign in the prerequisites list
# $(dir src/foo.c hacks)
# produces the result ‘src/ ./’.
# targets : normal-prerequisites | order-only-prerequisites
# $@ the object file name
# $< the source file name
# -I dir search the directories(dir) in the order specified.
# $(1),$(CC),$(CFLAGS) $(3),libs,$(4)
#-MM输出一个make规则来描述源文件的依赖，但不包括系统头文件路径里的头文件
#$(V)就是@ 但是在make时加入"V="会输出gcc的编译选项
define cc_template    
@ echo $$(call todep,$(1),$(4)): $(1) | $$$$(dir $$$$@)
	@$(2) -I$$(dir $(1)) $(3) -MM $$< -MT "$$(patsubst %.d,%.o,$$@) $$@"> $$@
@ echo $$(call toobj,$(1),$(4)): $(1) | $$$$(dir $$$$@)
	@echo + cc $$<
	$(V)$(2) -I$$(dir $(1)) $(3) -c $$< -o $$@
ALLOBJS += $$(call toobj,$(1),$(4))
endef


# compile file: (#files, cc[, flags, dir]) 每一个传入的文件列表都用cc_template生成编译模板 $(foreach var,list,text)list中的字符串按空格分开分别传入text中
define do_cc_compile
$$(foreach f,$(1),$$(eval $$(call cc_template,$$(f),$(2),$(3),$(4))))
endef

# add files to packet: (#files, cc[, flags, packet, dir])如果为未定义，则__temp_packet__初始化为空
#之后生成packet所需的.o文件名列表
#使用cc_template生成packet生成的.d和.o文件
#将生成的.o文件名列表添加到__temp_packet__中 
define do_add_files_to_packet 
__temp_packet__ := $(call packetname,$(4)) 
ifeq ($$(origin $$(__temp_packet__)),undefined)
$$(__temp_packet__) :=
endif
__temp_objs__ := $(call toobj,$(1),$(5))
$$(foreach f,$(1),$$(eval $$(call cc_template,$$(f),$(2),$(3),$(5))))
$$(__temp_packet__) += $$(__temp_objs__)
endef

# add objs to packet: (#objs, packet)
define do_add_objs_to_packet
__temp_packet__ := $(call packetname,$(2))
ifeq ($$(origin $$(__temp_packet__)),undefined)  
$$(__temp_packet__) :=
endif
$$(__temp_packet__) += $(1)
endef

# add packets and objs to target (target, #packes, #objs[, cc, flags])
# 将第一个参数和第三个参数都添加到TAEGETS中去，再判断第四个参数是否传入来确定gcc的编译命令
define do_create_target
__temp_target__ = $(call totarget,$(1))
__temp_objs__ = $$(foreach p,$(call packetname,$(2)),$$($$(p))) $(3)
TARGETS += $$(__temp_target__)
ifneq ($(4),)
$$(__temp_target__): $$(__temp_objs__) | $$$$(dir $$$$@)
	$(V)$(4) $(5) $$^ -o $$@
else
$$(__temp_target__): $$(__temp_objs__) | $$$$(dir $$$$@)
endif
endef

# finish all  ALLOBJS中的.o替换为.d sort 去重按字母从小到大排序
define do_finish_all
ALLDEPS = $$(ALLOBJS:.o=.d)
$$(sort $$(dir $$(ALLOBJS)) $(BINDIR)$(SLASH) $(OBJDIR)$(SLASH)):
	@$(MKDIR) $$@
endef

# --------------------  function end  --------------------
# compile file: (#files, cc[, flags, dir]) eval 对比info，info将参数替换，eval在此基础上将其当makefile执行
cc_compile = $(eval $(call do_cc_compile,$(1),$(2),$(3),$(4)))

# add files to packet: (#files, cc[, flags, packet, dir]) 
add_files = $(eval $(call do_add_files_to_packet,$(1),$(2),$(3),$(4),$(5)))

# add objs to packet: (#objs, packet)
add_objs = $(eval $(call do_add_objs_to_packet,$(1),$(2)))

# add packets and objs to target (target, #packes, #objs, cc, [, flags])
create_target = $(eval $(call do_create_target,$(1),$(2),$(3),$(4),$(5)))
# 加__objs_的前缀
read_packet = $(foreach p,$(call packetname,$(1)),$($(p)))

add_dependency = $(eval $(1): $(2))

finish_all = $(eval $(call do_finish_all))

