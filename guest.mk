# 客户机相关。make 不按依赖顺序执行命令，按依赖层级

########### 生命周期相关 ###########
# % = 客户机名称
guest.init.%: guest.create.% guest.prerequisites.% guest.additions.%;
# 必须条件
guest.prerequisites.%: guest.vdi.load.% guest.nic.load.%;
# 可选条件
guest.additions.%: guest.share.% guest.ssh-copy-id.% guest.install.make.%;

# 创建客户机
GUEST_MEMORY?=4096# 内存默认 4G
GUEST_CPU_COUNT?=2# CPU 核心数默认为 2
guest.create.%:
#	创建客户机，主要是生成虚拟机相关的配置，--basefolder 虚拟机配置位置（绝对路径），--ostype 操作系统类型，--register 虚拟机中会显示客户机（反之不会）
	vboxmanage createvm --name $* --basefolder=$(shell pwd)/$(BUILD) --ostype=Ubuntu22_LTS_64 --register
#	修改客户机，--cpus 设置 cpu 数目，--memory 设置内存
	vboxmanage modifyvm $* --cpus=$(GUEST_CPU_COUNT) --memory=$(GUEST_MEMORY)
# 配置 2 号网卡
guest.nic.load.%: $(BUILD)/hostonlynets.vbox.name
#	修改客户机，1 号网卡默认为 NAT，--nic2 设置 2 号网卡类型，--host-only-net2 设置 2 号网卡使用的网络名称
	vboxmanage modifyvm $* --nic2 hostonlynet --host-only-net2=$(shell cat $< | head -n 1)
# 挂载存储设备
guest.vdi.load.%: $(BUILD)/%.vdi
#	操作存储控制器，$* 客户机名称，--name 存储控制器名称，--add 添加 SATA 存储控制器，--bootable 引导盘
	vboxmanage storagectl $* --name=$* --add=sata --bootable=on
#	存储控制器操作存储设备，$* 客户机名称，--storagectl 存储控制器名称，--port 端口号，--device 设备号，--type 存储设备类型，--medium 存储设备位置，--setuuid="" 随机生成存储设备 uuid
	vboxmanage storageattach $* --storagectl=$* --port=0 --device=0 --type=hdd --medium $< --setuuid=""
#	vboxmanage storageattach $* --storagectl=$* --port=1 --device=0 --type=dvddrive --medium /Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso

# 共享目录
GUEST_HOST_PATH?=$(shell pwd)
GUEST_SHARED_FOLDER?=$(shell basename $(GUEST_HOST_PATH))
GUEST_MOUNT_POINT?=/media/$(GUEST_SHARED_FOLDER)
guest.share.%: guest.shutdown.% # 需要关机才能执行 sharedfolder 命令，否则出错
	vboxmanage sharedfolder add $* --name $(GUEST_SHARED_FOLDER) --hostpath $(GUEST_HOST_PATH) --automount --auto-mount-point=$(GUEST_MOUNT_POINT)

# 客户机是否已安装
GUEST_INSTALLED=vboxmanage list vms | grep $* > /dev/null
# 客户机是否在运行中。grep "\"$*\"" 严格名称匹配，例如："test-node01" {430830c0-5386-43e6-8ea4-6e6c73f87b0e}
GUEST_RUNNING=vboxmanage list runningvms | grep "\"$*\"" > /dev/null
# 客户机扩展程序是否在运行中
GUEST_ADDITIONS_RUNNING=$(GUEST_PROPERTY_ENUMERATE) | grep '/VirtualBox/GuestInfo/Net' > /dev/null
# 客户机属性列举
GUEST_PROPERTY_ENUMERATE=vboxmanage guestproperty enumerate $*
# 启动客户机（如未启动）
guest.start.%:; @if ! $(GUEST_RUNNING); then vboxmanage startvm $* --type=headless;  fi
# 客户机扩展服务运行中（从启动到服务运行有一段时间间隔）
guest.running.%: guest.start.%
	while ! $(GUEST_ADDITIONS_RUNNING); do echo "waiting 2 seconds for guest started..." && sleep 2; done

# 配置免密登录
ID_RSA:=$(HOME)/.ssh/id_rsa
ifeq ($(wildcard $(ID_RSA)),)
$(ID_RSA):; ssh-keygen -t rsa -b 2048;
endif
# 自动设置密码：https://serverfault.com/questions/306541/automating-ssh-copy-id
# 不检查指纹：https://unix.stackexchange.com/questions/33271/how-to-avoid-ssh-asking-permission
guest.ssh-copy-id.%: $(BUILD)/%.ip $(ID_RSA)
# 	sshpass 自动设置密码，StrictHostKeyChecking=no 不检查指纹
	sshpass -p$(US_PWD) ssh-copy-id -o StrictHostKeyChecking=no $(US_USER)@$(shell cat $<)
$(BUILD)/%.ip: $(BUILD)/%.guestproperty
#	网络 1 对应网卡 2，起始序号不同
	cat $< | grep '/Net/1/V4/IP' | awk -F"'" '{print $$2}' > $@
# 获取客户机属性，必须获取到网络信息，需要等到客户机扩展服务启动
$(BUILD)/%.guestproperty: guest.running.%
	$(GUEST_PROPERTY_ENUMERATE) > $@

# 关闭客户机并等其完全停止（如果在运行中）
guest.shutdown.%:
	if $(GUEST_RUNNING); then vboxmanage controlvm $* shutdown; fi;
	while $(GUEST_RUNNING); do echo "waiting 2 seconds for guest shutdown..."; sleep 2; done;

# 销毁客户机
guest.clean.%: guest.shutdown.% clean/%.*
	vboxmanage unregistervm $* --delete

########### 服务相关 ###########
guest.install.make.%: guest.start.%; make guest.sudo.$* GUEST_CMD="apt install make -y"
# 共享目录后，在宿主机中执行 make 命令，实际在客户机中执行 make 中的 GUEST_MAKE_TARGET 命令
GUEST_MAKE_EXEC?=/usr/bin/make -C $(GUEST_MOUNT_POINT)
GUEST_MAKE_TARGET?=system.init
guest.make.%:; make guest.sudo.$* GUEST_CMD="$(GUEST_MAKE_EXEC) $(GUEST_MAKE_TARGET)"
# 以管理员身份执行命令，https://superuser.com/questions/67765/sudo-with-password-in-one-command-line
VBOX_SUDO=$(call SUDO,$(US_PWD))
guest.sudo.%:; make guest.exe.$* GUEST_CMD="$(VBOX_SUDO) $(GUEST_CMD)"
# 以普通用户身份执行命令
guest.exe.%: guest.ssh.%;
# guest.exe.%: guest.control.run.%; # 替代方案

# SSH 登录后跳转到工作目录：https://stackoverflow.com/questions/626533/how-can-i-ssh-directly-to-a-particular-directory
guest.cwd.%:; make guest.ssh.$* GUEST_CMD="cd /media/$(GUEST_SHARED_FOLDER); $(VBOX_SUDO) pwd; bash --login"
# SSH 登录或登录后执行命令
GUEST_CMD?=#有命令执行命令，无命令直接登录
guest.ssh.%: $(BUILD)/%.ip; ssh $(US_USER)@$(shell cat $<) "$(GUEST_CMD)"
# 借助虚拟机指令在客户机中执行命令，与 SSH 执行命令类似，不需要 IP 但需要先启动客户机扩展 guest.running.%
GUEST_EXE?=/usr/bin/sh
guest.control.run.%:; vboxmanage guestcontrol $* run --username=$(US_USER) --password=$(US_PWD) --exe="$(GUEST_EXE)" -- -c "$(GUEST_CMD)"

# make 快捷调用方式
GUEST_MAKE_TARGETS?=test system.init
$(foreach item,$(GUEST_MAKE_TARGETS),$(eval make.$(item).%:; make guest.make.$$* GUEST_MAKE_TARGET=$(item).$$* ))
test.%:; whoami

# 客户机软件初始化
system.init.%: system.init
# 	设置主机名并永久生效
	sudo hostnamectl set-hostname $*
system.init:
# 	添加用户到 vboxsf 组，否则不能访问挂载的共享目录
	sudo usermod -a -G vboxsf $(US_USER)
#	设置时区，默认为 UTC，改为 CST
	sudo timedatectl set-timezone Asia/Shanghai
#	同时使系统日志时间戳也立即生效
	sudo systemctl restart rsyslog
#	安装网络工具命令
	sudo apt install net-tools -y

# 生命周期测试
# guest.lifecycle.test: guest.init.vbox make.test.vbox guest.clean.vbox;
# 上述写法存在问题：执行 guest.clean.vbox 时，未执行 guest.shutdown.vbox？
# 在整个规则链中不重复执行：guest.share.% 依赖 guest.shutdown.% 已经执行了
# 改成以下方式，拆分为不同的规则链：
guest.lifecycle.test:
	make guest.init.vbox make.test.vbox
	make guest.clean.vbox
