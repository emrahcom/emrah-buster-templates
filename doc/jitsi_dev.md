Jitsi Development on eb-jitsi
=============================

- [1. About](#1-about)
- [2. Installation](#2-installation)
- [3. Login](#3-login)
- [4. Dev folder](#4-dev-folder)
- [5. Development](#5-development)
- [6. Enable the development web server](#6-enable-the-development-web-server)

## 1. About
This guide provides the base info to use [eb-jitsi](jitsi_cluster.md) as a
`Jitsi` development environment. This guide is for experienced developers who
are comfortable with a Linux environment.

## 2. Installation
Install JMS (Jitsi Meet Server) according to [this guide](jitsi_cluster.md).
Set the following parameters to install the development environment before
starting the installer.

```bash
echo export INSTALL_JICOFO_DEV=true >> eb-jitsi.conf
echo export INSTALL_JITSI_MEET_DEV=true >> eb-jitsi.conf
```

if you want to enable the development web server by default, set the following
parameter too:

```bash
echo export ENABLE_JITSI_MEET_DEV=true >> eb-jitsi.conf
```

## 3. Login
JMS run in a containerized environment which is named as `eb-jitsi`. There are
two common ways to login this environment:

* Login to the host using `SSH` and then attach to the container

```bash
lxc-attach -n eb-jitsi
```

* Login directly to the container using `SSH`

```bash
ssh -l root -p 30014 your.domain.com
```

## 4. Dev folder
The development tools are already installed and the related repositories are
already cloned on `/home/dev`. Go there and start working:

```bash
cd /home/dev
ls
```

## 5. Development
How to change the codes is beyond the scope of this guide. See   
[How to build Jitsi Meet from source: A developer’s guide](https://community.jitsi.org/t/how-to-how-to-build-jitsi-meet-from-source-a-developers-guide/75422)

## 6. Enable the development web server
The web server run using the stable JMS by default. Use the following command
to switch to the development web server.

```bash
enable-jitsi-meet-dev
```

To active the stable JMS again, use the following command

```bash
disable-jitsi-meet-dev
```
