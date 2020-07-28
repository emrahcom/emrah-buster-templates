![Jitsi Cluster](images/jitsi_cluster.png)

Easy way to create a Jitsi cluster based on Debian Buster
=========================================================
- [1. About](#1-about)
- [2. Jitsi Meet Server (JMS)](#2-jitsi-meet-server-jms)
  - [2.1 Prerequisites](#21-prerequisites)
    - [2.1.1 DNS A record](#211-dns-a-record)
    - [2.1.2 The snd_aloop module](#212-the-snd_aloop-module)
    - [2.1.3 Public ports](#213-public-ports)
  - [2.2 Installing JMS](#22-installing-jms)
    - [2.2.1 Downloading the installer](#221-downloading-the-installer)
    - [2.2.2 Setting the host address](#222-setting-the-host-address)
    - [2.2.3 Running the installer](#223-running-the-installer)
    - [2.2.4 Let's Encrypt certificate](#224-lets-encrypt-certificate)
- [3. Additional Jitsi Videobridge (JVB) node](#3-additional-jitsi-videobridge-jvb-node)
  - [3.1 Prerequisites](#31-prerequisites)
    - [3.1.1 Public ports](#311-public-ports)
  - [3.2 Installing JVB](#32-installing-jvb)
    - [3.2.1 Adding the JMS public key](#321-adding-the-jms-public-key)
    - [3.2.2 Adding the JVB node to the pool](#322-adding-the-jvb-node-to-the-pool)
- [4. Additional Jibri node](#4-additional-jibri-node)
  - [4.1 Prerequisites](#41-prerequisites)
    - [4.1.1 The snd_aloop module](#411-the-snd_aloop-module)
    - [4.1.2 Public ports](#412-public-ports)
  - [4.2 Installing Jibri](#42-installing-jibri)
    - [4.2.1 Adding the JMS public key](#421-adding-the-jms-public-key)
    - [4.2.2 Adding the Jibri node to the pool](#422-adding-the-jibri-node-to-the-pool)
- [5- FAQ](#5-faq)

---

## 1. About
This tutorial provides step by step instructions on how to create a Jitsi
cluster based on Debian Buster (Debian 10).

Create or install a Debian Buster server for each node in this tutorial.
Please, don't install a desktop environment, only the standard packages...
Reserve at least 4 cores and 8 GB RAM for each node.

Run each command on this tutorial as `root`.


## 2. Jitsi Meet Server (JMS)
JMS is a standalone server with conference room, video recording and streaming
features. If the load level is low and simultaneous recording will not be made,
JMS can operate without an additional JVB or Jibri node.

Additional JVB and Jibri nodes can be added in the future if needed.

#### 2.1 Prerequisites
Complete the following steps before starting the JMS installation.

##### 2.1.1 DNS A record
A resolvable host address is required for the JMS server and this address
should point to this server. Therefore, create the DNS `A record` before
starting the installation.

##### 2.1.2 The snd_aloop module
JMS needs the `snd_aloop` kernel module but some cloud computers have a kernel
that doesn't support it. In this case, first install the standart Linux kernel
and reboot the node with this kernel.

Run the following command to check the `snd_aloop` support. If the command has
an output, it means that the kernel doesn't support it.

```bash
modprobe snd_aloop
```

##### 2.1.3 Public ports
If the JMS server is behind a firewall, open the following ports:

* TCP/80
* TCP/443
* TCP/5222
* UDP/10000

#### 2.2 Installing JMS
Installation will be done with
[emrah-buster](https://github.com/emrahcom/emrah-buster-templates) installer.

##### 2.2.1 Downloading the installer

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-base/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-templates/master/installer/eb-jitsi.conf
```

##### 2.2.2 Setting the host address
Set the host address on the installer config file `eb-jitsi.conf`. This must be
an FQDN, not IP address... Let's say the host address is `meet.mydomain.com`

```bash
echo export JITSI_HOST=meet.mydomain.com >> eb-jitsi.conf
```

##### 2.2.3 Running the installer

```bash
bash eb eb-jitsi
```

##### 2.2.4 Let's Encrypt certificate
Let's say the host address is `meet.mydomain.com`
To set the Let's Encrypt certificate:

```bash
set-letsencrypt-cert meet.mydomain.com
```


## 3. Additional Jitsi Videobridge (JVB) node
A standalone JMS installation is good for a limited size of concurrent
conferences but the first limiting factor is the JVB component, that handles
the actual video and audio traffic. It is easy to scale the JVB pool
horizontally by adding as many as JVB node when needed.

#### 3.1 Prerequisites
Complete the following steps before starting the JVB installation.

##### 3.1.1 Public ports
If the JVB server is behind a firewall, open the following ports:

* TCP/22 (at least for JMS server)
* UDP/10000

#### 3.2 Installing JVB
##### 3.2.1 Adding the JMS public key
If `openssh-server` is not installed on the JVB node, install it first!

```bash
apt-get -y --allow-releaseinfo-change update
apt-get install openssh-server curl
```

Add the JMS public key to the JVB node.

```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
curl https://meet.mydomain.com/static/jms.pub >> /root/.ssh/authorized_keys
```

##### 3.2.2 Adding the JVB node to the pool
Let's say the IP address of the JVB node is `100.1.2.3`
On the JMS server:

```bash
add-jvb-node 100.1.2.3
```


## 4. Additional Jibri node
A standalone JMS installation can only record a limited number of concurrent
conferences but the CPU and RAM capacities are the limiting factor for the
Jibri component. It is easy to scale the Jibri pool horizontally by adding
as many as Jibri node when needed.

#### 4.1 Prerequisites
Complete the following steps before starting the Jibri installation.

##### 4.1.1 The snd_aloop module
The Jibri node needs the `snd_aloop` module too. Therefore check the kernel
first.

##### 4.1.2 Public ports
If the Jibri server is behind a firewall, open the following ports:

* TCP/22 (at least for JMS server)

#### 4.2 Installing Jibri
##### 4.2.1 Adding the JMS public key
If `openssh-server` is not installed on the Jibri node, install it first!

```bash
apt-get -y --allow-releaseinfo-change update
apt-get install openssh-server curl
```

Add the JMS public key to the Jibri node.

```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
curl https://meet.mydomain.com/static/jms.pub >> /root/.ssh/authorized_keys
```

##### 4.2.2 Adding the Jibri node to the pool
Let's say the IP address of the Jibri node is `200.7.8.9`
On the JMS server:

```bash
add-jibri-node 200.7.8.9
```


## 5. FAQ
#### My kernel has no support for the snd_aloop module. How can I install the standard Linux kernel?

The cloud kernel used in most cloud machines has no support for the `snd_aloop`
module. It's easy to install the standart Linux kernel on a Debian system.
Execute the following commands as `root`

```
apt-get update
apt-get install linux-image-amd64
```

However, activating this kernel can be a bit complicated in some cases. `GRUB`
decides which kernel will be active at the next boot. If the standart Linux
kernel is not on the top order, you need to force `GRUB` to choice the right
kernel.

First, check the `GRUB` config using the following command

```
egrep '(^\s*initrd|submenu)' /boot/grub/grub.cfg | cut -c1-80
```

If the standart kernel is on the top, there is no problem. If the standard
kernel is under the `submenu` line, you need to force `GRUB` to choice it.

Edit the `GRUB_DEFAULT` value in `/etc/default/grub`. Let's say the standart
kernel is the third `menuentry` after the `submenu` line, the value will be

```
GRUB_DEFAULT='1>2'
```

'*1*' means the `submenu` and '*2*' means the third menuentry (start counting
from *0*)

Save the file, update the `GRUB` config and reboot

```
update-grub
reboot
```

Check the active kernel after reboot

```
uname -a
```

But it's not completed yet. An `upgrade` can easily break the boot order. It's
time to delete the cloud kernel packages completely.

```
apt-get purge 'linux-image-*cloud*'
```

Now, we can reset the default value for `GRUB_DEFAULT` again.
In `/etc/default/grub`

```
GRUB_DEFAULT=0
```

Save the file, update the `GRUB` config and reboot again.

```
update-grub
reboot
```

#### How can I change the Jitsi config?
First, connect to the Jitsi container `eb-jitsi` then edit the config files.

```bash
lxc-attach -n eb-jitsi
cd /etc/jitsi
ls
```

#### I’ve setup the initial JMS node successfully, but getting a 'recording unavailable' error when trying to record.

At least 4 cores are required to start a `Jibri` instance. The first two cores
are reserved for the base processes. After these two cores, one Jibri instance
is started for each additional 2 cores.

Just shutdown the machine, increase the number of cores and reboot.

#### How can I make a change/addition permanent in Jibri?

All running Jibri instances are ephemeral and changes made will disappear after
shutdown. Apply to the `eb-jibri-template` container to make a change permanent
and restart the Jibri instances.

#### How can I restart all running Jibri instances?

Use the related `systemd` service.

```bash
systemctl stop jibri-ephemeral-container.service
systemctl start jibri-ephemeral-container.service
```

#### Where are the recorded files?

Jibri creates a randomly named folder for each recording and puts the MP4
file in it. The recording folder is `/usr/local/eb/recordings` and the MP4
files are in the subfolders of this folder.

```bash
ls -alh /usr/local/eb/recordings/*
```

#### Is it possible to broadcast to a stream server other than Youtube?

Jibri can only stream to Youtube but there is a little customization on
`eb-jitsi`. So It is possible to stream to any RTMP server from `eb-jitsi`.
Just use the full RTMP address as the stream key.
