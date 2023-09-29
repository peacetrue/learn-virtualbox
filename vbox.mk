# 以下代码在 macOS 运行测试
# https://www.virtualbox.org/manual/
# https://www.virtualbox.org/manual/ch08.html 命令手册

# 下载安装包到 SRC 目录
VBOX_VERSION:=7.0.10
VBOX_NAME:=VirtualBox-7.0.10a-158379-OSX.dmg
VBOX_SRC:=$(SRC)/$(VBOX_NAME)
# 已经存在该文件，但仍可能执行内容以更新文件
ifeq ($(wildcard $(VBOX_SRC)),)
$(VBOX_SRC):; wget -P $(SRC) https://download.virtualbox.org/virtualbox/$(VBOX_VERSION)/$(VBOX_NAME);
endif

# 下载扩展包到 SRC 目录
EXTPACK_NAME:=Oracle_VM_VirtualBox_Extension_Pack-7.0.10.vbox-extpack
EXTPACK_SRC:=$(SRC)/$(EXTPACK_NAME)
ifeq ($(wildcard $(EXTPACK_SRC)),)
$(EXTPACK_SRC):; wget -P $(SRC) https://download.virtualbox.org/virtualbox/$(VBOX_VERSION)/$(EXTPACK_NAME);
endif

BREW:=/usr/local/bin/brew
ifeq ($(wildcard $(BREW)),)
$(BREW):; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
$(info brew -v: $(shell brew -v))
$(info brew info virtualbox: $(shell brew info virtualbox))
endif

VBOXMANAGE:=/usr/local/bin/VBoxManage
VBOX_INSTALLED:=$(wildcard $(VBOXMANAGE))
ifeq ($(VBOX_INSTALLED),)
$(VBOXMANAGE): $(BREW); brew install virtualbox
else

# GitHub Action 中 macOS 已经安装了 6.x 版本的 virtualbox，删除低版本，安装高版本
VBOX_VERSION:=$(firstword $(subst ., ,$(shell VBoxManage -v)))
ifeq ($(VBOX_VERSION),6)
$(info $(shell sudo rm -rf /Applications/VirtualBox.app))
$(info brew install virtualbox: $(shell brew install virtualbox))
endif

$(info VBoxManage -v: $(shell VBoxManage -v))
endif

# 安装扩展包，需要密码确认
vbox.extpack.install: $(VBOXMANAGE) $(EXTPACK_SRC)
	yes | vboxmanage extpack install $(word 2,$^)

# 查看虚拟机信息
$(BUILD)/%.txt: $(BUILD); vboxmanage list $* > $@
vbox.list: $(addsuffix .txt,$(addprefix $(BUILD)/,ostypes natnets hostonlynets extpacks vms));
vbox.list.subdir:; make vbox.list BUILD=$(BUILD)/vbox
# 获取网络名称，gsub 删除前置空格
$(BUILD)/%.name: $(BUILD)/%.txt
	cat $< | grep -w Name | awk -F':' '{print $$NF}' | awk '{gsub(/^ +/, ""); print $$0}' > $@
# Host Only Network management
vbox.hostonlynet.add:
	VBoxManage hostonlynet add --name=vboxnet1 --netmask=255.255.255.0 --lower-ip=192.168.150.3 --upper-ip=192.168.150.254 --enable
vbox.init: $(VBOXMANAGE) vbox.hostonlynet.add;
