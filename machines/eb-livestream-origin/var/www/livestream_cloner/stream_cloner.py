#!/usr/bin/python3
# -*- coding:utf-8 -*-

###############################################################################
# This script clones the stream to a new location.
#
# The process terminates when it finishes its works. Use "stop" parameter to
# force to stop immediately.
#
# stream_key is the uniq key to get the stream related values from the json
# file.
#
# Usage:
#       stream_cloner.py start|stop|restart stream_key
#
###############################################################################

import os
import sys
import time
import atexit
import argparse
import config as c
import json
from hashlib import md5
from subprocess import Popen, TimeoutExpired
from mydaemon import Daemon

# Daemon name. It's only used in messages.
DAEMON_NAME = 'Stream Cloner (id: #ID#)'
# Cleanstop wait time before to kill the process.
DAEMON_STOP_TIMEOUT = 10
# Daemon pid file.
PIDFILE = '/tmp/stream_cloner_#ID#.pid'
# Deamon run file. "stop" request deletes this file to inform the process and
# waits DAEMON_STOP_TIMEOUT seconds before to send SIGTERM. The process has a
# change to stop cleanly if it's written appropriately.
RUNFILE = '/tmp/stream_cloner_#ID#.run'
# Debug mode.
DEBUG = 0



# -----------------------------------------------------------------------------
def get_args():
    '''
    >>> get_args()
    ('start', 5)
    >>> get_args()
    ('stop', 4)
    '''

    try:
        parser =  argparse.ArgumentParser()
        parser.add_argument('action', help='action',
                            choices=['start', 'stop', 'restart'])
        parser.add_argument('stream_key', help='Stream key')
        args = parser.parse_args()

        result = (args.action, args.stream_key)
    except Exception as err:
        if DEBUG:
            raise
        else:
            sys.stderr.write('%s\n' % (err))

        result = (None, None)

    return result



# -----------------------------------------------------------------------------
def get_stream_set(stream_key):
    '''
    >>> get_stream_set()
    ('a9f0c4de327373979b5c30da58c027fa',
     {'src' : 'rtmp://127.0.0.1/livestream/test',
      'dst' : 'rtmp://127.0.0.1/livestream/clone'})
    >>> get_stream_set()
    ('a9f0c4de327373979b5c30da58c027fa', {})
    '''

    try:
        uniqid = None
        uniqid = md5(stream_key.encode()).hexdigest()

        with open(c.FILE_PATH, 'r') as f:
            sdict = json.load(f).get(stream_key, {})

        result = (uniqid, sdict)
    except Exception as err:
        if DEBUG:
            raise
        else:
            sys.stderr.write('%s\n' % (err))

        result = (uniqid, None)

    return result



# -----------------------------------------------------------------------------
class StreamCloner(Daemon):
    src = None
    dst = None

    def run(self):
        '''
        Process start to run here.
        '''

        # Delete the run file at exit. Maybe there will be no stop request.
        atexit.register(self.delrun)

        # Run while there is no stop request.
        while os.path.exists(RUNFILE):
            time.sleep(1)

            cmd = ['ffmpeg', '-v', 'quiet',
                   '-i', self.src,
                   '-c:v', 'copy', '-c:a', 'copy',
                   '-f', 'flv', self.dst]
            self.wait(Popen(cmd, shell=False))

    def wait(self, p):
        while True:
            try:
                p.wait(1)
            except TimeoutExpired:
                if not os.path.exists(RUNFILE):
                    p.terminate()
                    break

                continue
            else:
                break



# -----------------------------------------------------------------------------
if __name__ == '__main__':
    try:
        # Get arguments.
        (action, stream_key) = get_args()
        (uniqid, sdict) = get_stream_set(stream_key)
        if not uniqid:
            raise NameError('Invalid stream_key')

        # Create daemon object.
        DAEMON_NAME = DAEMON_NAME.replace('#ID#', uniqid)
        PIDFILE = PIDFILE.replace('#ID#', uniqid)
        RUNFILE = RUNFILE.replace('#ID#', uniqid)
        d = StreamCloner(name=DAEMON_NAME, pidfile=PIDFILE, runfile=RUNFILE,
                     stoptimeout=DAEMON_STOP_TIMEOUT, debug=DEBUG)

        # Action requested.
        if action == 'start':
            d.src = sdict['src']
            d.dst = sdict['dst']
            d.start()
        elif action == 'stop':
            d.stop()
        elif action == 'restart':
            d.restart()
        else:
            raise NameError('Unknown action')

        sys.exit(0)
    except Exception as err:
        if DEBUG:
            raise
        else:
            sys.stderr.write('%s\n' % err)

        sys.exit(1)
