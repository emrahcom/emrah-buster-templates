Table of contents
=================

- [About](#about)
- [Usage](#usage)
- [Example](#example)
- [Available templates](#available-templates)
    - [eb-base](#eb-base)
        - [To install eb-base](#to-install-eb-base)
    - [eb-livestream](#eb-livestream)
        - [Main components of eb-livestream](#main-components-of-eb-livestream)
        - [To install eb-livestream](#to-install-eb-livestream)
        - [After install eb-livestream](#after-install-eb-livestream)
        - [Related links to eb-livestream](#related-links-to-eb-livestream)
- [Requirements](#requirements)

---

About
=====

`emrah-buster` is an installer to create the containerized systems on Debian
Buster host. It built on top of LXC (Linux containers). This repository
contains the `emrah-buster`s templates.

Usage
=====

Download the installer, run it with a template name as an argument and drink a
coffee. That's it.

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-base/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-templates/master/installer/<TEMPLATE_NAME>.conf
bash eb <TEMPLATE_NAME>
```

Example
=======

To install a streaming media system, login a Debian Buster host as `root` and

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-base/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-templates/master/installer/eb-livestream.conf
bash eb eb-livestream
```

Available templates
===================

eb-base
-------

Install only a containerized Debian Buster.

### To install eb-base

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-base/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-templates/master/installer/eb-base.conf
bash eb eb-base
```

---

eb-livestream
-------------

Install a ready-to-use live streaming media system.

### Main components of eb-livestream

-  Nginx server with nginx-rtmp-module as a stream origin.
   It gets the RTMP stream and convert it to HLS and DASH.

-  Nginx server with standart modules as a stream edge.
   It publish the HLS and DASH stream.

-  Web based HLS video player.

-  Web based DASH video player.

### To install eb-livestream

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-base/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster-templates/master/installer/eb-livestream.conf
bash eb eb-livestream
```

### After install eb-livestream

-  `rtmp://<IP_ADDRESS>/livestream/<CHANNEL_NAME>` to push
    an RTMP stream.

-  `http://<IP_ADDRESS>/livestream/hls/<CHANNEL_NAME>/index.m3u8` to pull
   the HLS stream.

-  `http://<IP_ADDRESS>/livestream/dash/<CHANNEL_NAME>/index.mpd` to pull
   the DASH stream.

-  `http://<IP_ADDRESS>/livestream/hlsplayer/<CHANNEL_NAME>` for
   the HLS video player page.

-  `http://<IP_ADDRESS>/livestream/dashplayer/<CHANNEL_NAME>` for
   the DASH video player page.

-  `http://<IP_ADDRESS>:8000/livestream/status` for the RTMP status page.

-  `http://<IP_ADDRESS>:8000/livestream/cloner` for the stream cloner page.
   Thanks to [nejdetckenobi](https://github.com/nejdetckenobi)

### Related links to eb-livestream

-  [nginx-rtmp-module](https://github.com/arut/nginx-rtmp-module)

-  [video.js](https://github.com/videojs/video.js)

-  [videojs-contrib-hls](https://github.com/videojs/videojs-contrib-hls)

-  [dash.js](https://github.com/Dash-Industry-Forum/dash.js/)

---

Requirements
============

`emrah-buster` requires a Debian Buster host with a minimal install and the
Internet access during the installation. It's not a good idea to use your
desktop machine or an already in-use production server as a host machine.
Please, use one of the followings as a host:

-  a cloud host from a hosting/cloud service
   ([Digital Ocean](https://www.digitalocean.com/?refcode=92b0165840d8)'s
   droplet, [Amazon](https://console.aws.amazon.com) EC2 instance etc)

-  a virtual machine (VMware, VirtualBox etc)

-  a Debian Buster container

-  a physical machine with a fresh installed [Debian Buster](https://www.debian.org/distrib/netinst)
