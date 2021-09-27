# Jitsi Development on eb-jitsi

- [1. About](#1-about)
- [2. Installation](#2-installation)
- [3. Login](#3-login)
- [4. Dev folder](#4-dev-folder)
- [5. Working tree](#5-working-tree)
- [6. Build](#6-build)
  - [6.1 Jitsi-meet Build](#61-jitsi-meet-build)
  - [6.2 Jicofo Build](#62-jicofo-build)
- [7. Enable the development web server](#7-enable-the-development-web-server)

## 1. About

This guide provides the base info to use [eb-jitsi](jitsi_cluster.md) as a
`Jitsi` development environment. This guide is for experienced developers who
are comfortable with a Linux environment.

## 2. Installation

Install JMS (Jitsi Meet Server) according to [this guide](jitsi_cluster.md). Set
the following parameters to install the development environment before starting
the installer.

```bash
echo export INSTALL_JICOFO_DEV=true >> eb-jitsi.conf
echo export INSTALL_JITSI_MEET_DEV=true >> eb-jitsi.conf
```

## 3. Login

JMS run in a containerized environment which is named as `eb-jitsi`. There are
two common ways to login this environment:

- Login to the host using `SSH` and then attach to the container

```bash
lxc-attach -n eb-jitsi
```

- Login directly to the container using `SSH`

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

## 5. Working tree

How to change the codes is beyond the scope of this guide. See\
[How to build Jitsi Meet from source: A developer’s guide](https://community.jitsi.org/t/how-to-how-to-build-jitsi-meet-from-source-a-developers-guide/75422)

If you want to edit the codes for the installed version, first check the
installed version and switch to the related working tree.

No need to change the working tree if you will work on the `master` branch.

```bash
TAG=$(apt-cache policy jitsi-meet | grep Installed | egrep -o '[0-9]{4,}')
echo $TAG

cd /home/dev/lib-jitsi-meet
git checkout jitsi-meet_$TAG
git checkout -b $TAG

cd /home/dev/jitsi-meet
git checkout jitsi-meet_$TAG
git checkout -b $TAG

cd /home/dev/jicofo
git checkout jitsi-meet_$TAG
git checkout -b $TAG
```

## 6. Build

#### 6.1 Jitsi-meet build

Use the local `lib-jitsi-meet` repo

```bash
cd /home/dev/lib-jitsi-meet
npm update

cd /home/dev/jitsi-meet
npm install ../lib-jitsi-meet
npm update
```

Apply your changes and to build `lib-jitsi-meet` and `jitsi-meet`

```bash
cd /home/dev/jitsi-meet
npm install ../lib-jitsi-meet --force
make
```

#### 6.2 Jicofo build

```bash
cd /home/dev/jicofo
mvn install
```

## 7. Enable the development web server

The web server run using the stable JMS by default. Use the following command to
switch to the development web server.

```bash
enable-jitsi-meet-dev
```

To activate the stable JMS again, use the following command

```bash
disable-jitsi-meet-dev
```
