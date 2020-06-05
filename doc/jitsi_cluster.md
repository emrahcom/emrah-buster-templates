![Jitsi Cluster](images/jitsi_cluster.png)

Easy way to create Jitsi cluster based on Debian Buster
=======================================================
- [1. About](#1-about)
- [2. Jitsi Meet Server (JMS)](#2-jitsi-meet-server-jms)
  - [2.1 Before installing JMS](#21-before-installing-jms)
  - [2.2 Installing JMS](#22-installing-jms)
    - [2.2.1 Downloading the installer](#221-downloading-the-installer)
    - [2.2.2 Setting the host address](#222-setting-the-host-address)
    - [2.2.3 Running the installer](#223-running-the-installer)
    - [2.2.4 Let's Encrypt certificate](#224-lets-encrypt-certificate)
- [3. Jitsi Videobridge (JVB)](#3-jitsi-videobridge-jvb)
  - [3.1 Adding the JMS public key](#3.1-adding-the-jms-public-key)
  - [3.2 Adding the JVB node to the pool](#3.2-adding-the-jvb-node-to-the-pool)

---

## 1. About
This tutorial provides step by step instructions on how to create Jitsi cluster
based on Debian Buster (Debian 10). Create or install a Debian Buster server
for each node in this tutorial. Please, don't install a desktop environment,
only the standard packages...

## 2. Jitsi Meet Server (JMS)
JMS is a standalone server with conferance room, video recording and streaming
features. If the load level is low and simultaneous recording will not be made,
JMS can operate without an additional JVB or Jibri node.

Additional JVB and Jibri nodes can be added in the future if needed.

#### 2.1 Before installing JMS
- A resolvable host address is required for the JMS server and this address
  should point to this server. Therefore, create the DNS A record before
  starting the installation.

- JMS also needs the `snd_aloop` kernel module but some cloud computers have a
  kernel that doesn't support it. In this case, first install the standart
  kernel and start the machine with this kernel.

Run the following command to check the `snd_aloop` support. If the command has
an output, it means that the kernel doesn't support it.

```bash
modprobe snd_aloop
```

#### 2.2 Installing JMS
Installation will be done with
[emrah-buster](https://github.com/emrahcom/emrah-buster-templates).

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

```bash
some commands
```

## 3. Jitsi Videobridge (JVB)
A standalone JMS installation is good for a limited size of concurrent
conferences but the first limiting factor is the JVB component, that handles
the actual video and audio traffic. It is easy to scale the JVB pool
horizontally by adding as many as JVB node when needed. I

#### 3.1 Adding the JMS public key
Add the JMS public key to the JVB node. On the JVB node:

```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
wget -O - https://meet.mydomain.com/static/jms.pub >> /root/.ssh/authorized_keys
```

#### 3.2 Adding the JVB node to the pool
Let's say the IP address of the JVB node is `200.1.2.3`
On the JMS server:

```bash
add-jvb-node 200.1.2.3
```
