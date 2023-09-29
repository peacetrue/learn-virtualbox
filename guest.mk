guest.init.%: guest.create.% guest.vdi.load.% guest.nic.load.% guest.start.% guest.ssh-copy-id.%;
# 创建客户机
guest.create.%:
#	创建客户机，主要是生成虚拟机相关的配置，--basefolder 虚拟机配置位置，--ostype 操作系统类型，--register 虚拟机中会显示客户机（反之不会）
	vboxmanage createvm --name $* --basefolder=$(shell pwd)/$(BUILD) --ostype=Ubuntu22_LTS_64 --register
#	修改客户机，--memory 设置内存为 4G
	vboxmanage modifyvm $* --memory 4096
# 挂载存储设备
guest.vdi.load.%: $(BUILD)/%.vdi
#	操作存储控制器，$* 客户机名称，--name 存储控制器名称，--add 添加 SATA 存储控制器，--bootable 引导盘
	vboxmanage storagectl $* --name=$* --add=sata --bootable=on
#	存储控制器操作存储设备，$* 客户机名称，--storagectl 存储控制器名称，--port 端口号，--device 设备号，--type 存储设备类型，--medium 存储设备位置，--setuuid="" 随机生成存储设备 uuid
	vboxmanage storageattach $* --storagectl=$* --port=0 --device=0 --type=hdd --medium $(shell pwd)/$< --setuuid=""
#	vboxmanage storageattach $* --storagectl=$* --port=1 --device=0 --type=dvddrive --medium /Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso
# 配置 2 号网卡
guest.nic.load.%: $(BUILD)/hostonlynets.name
#	修改客户机，1 号网卡默认为 NAT，--nic2 设置 2 号网卡类型，--host-only-net2 设置 2 号网卡使用的网络名称
	vboxmanage modifyvm $* --nic2 hostonlynet --host-only-net2=$(shell cat $< | head -n 1)

# 启动客户机
guest.start.%:; vboxmanage startvm $* --type=headless

# 配置免密登录
guest.ssh-copy-id.%: $(BUILD)/%.ip $(ID_RSA)
	ssh-copy-id $(US_USER)@$(shell cat $<)
$(BUILD)/%.ip: $(BUILD)/%.guestproperty
#	网络 1 对应网卡 2，起始序号不同
	cat $< | grep '/Net/1/V4/IP' | awk -F"'" '{print $$2}' > $@
# 获取客户机属性，必须获取到网络信息，需要等到客户机扩展服务启动
$(BUILD)/%.guestproperty:
	while ! $(GUEST_PROPERTY) | grep '/VirtualBox/GuestInfo/Net'; do echo "waiting 2 seconds for guest ready..." && sleep 2; done && $(GUEST_PROPERTY) > $@;
GUEST_PROPERTY=vboxmanage guestproperty enumerate $*
ID_RSA:=$(HOME)/.ssh/id_rsa
ifeq ($(wildcard $(ID_RSA)),)
$(ID_RSA):; ssh-keygen -t rsa -b 2048;
endif

ssh.%: $(BUILD)/%.ip; ssh $(US_USER)@$(shell cat $<) || true

guest.shutdown.%:; vboxmanage controlvm $* shutdown
guest.clean.%: clean/%.*; vboxmanage unregistervm $* --delete
