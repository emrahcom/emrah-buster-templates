# from app.config import FILE_PATH
import json
from os import listdir, remove, path
from pprint import pprint
from config import FILE_PATH, PID_FILE_DIR
from hashlib import md5
from subprocess import run


def load_stream_list():
    with open(FILE_PATH) as f:
        streams = json.load(f)
    stream_list = []
    for name, data in streams.items():
        served_copy = data.copy()
        served_copy['name'] = name
        served_copy['streaming'] = False
        stream_hash = md5(name.encode('utf8')).hexdigest()
        if 'stream_cloner_{}.pid'.format(stream_hash) in listdir(PID_FILE_DIR):
            served_copy['streaming'] = True
        stream_list.append(served_copy)
    return stream_list


def save_stream_list(stream_list):
    streams_dict = {}
    for s in stream_list:
        streams_dict[s['name']] = s
        del s['name']
        if 'streaming' in s:
            del s['streaming']

    with open(FILE_PATH, 'w') as f:
        json.dump(streams_dict, f, sort_keys=True, indent=4)


def add_stream(name, src, dst):
    stream_list = load_stream_list()
    if name not in [s['name'] for s in stream_list]:
        stream_list.append({'name': name, 'src': src, 'dst': dst})
        save_stream_list(stream_list)


def remove_stream(name):
    stream_list = load_stream_list()
    stream_list = [s for s in stream_list if s['name'] != name]
    save_stream_list(stream_list)


def update_stream(name, new_src, new_dst):
    stream_list = load_stream_list()
    print(stream_list)
    try:
        s = [r for r in stream_list if r['name'] == name][0]
    except IndexError:
        return False
    s['src'] = new_src
    s['dst'] = new_dst
    save_stream_list(stream_list)
    return True


def start_streaming(name):
    try:
        run(['python3', 'stream_cloner.py', 'start', name])
    # stream_hash = md5(name.encode('utf8')).hexdigest()
    # fpath = path.join(PID_FILE_DIR, 'stream_cloner_{}.pid'.format(stream_hash))
    # with open(fpath, 'w'):
    #     pass
    except:
        return False
    return True


def stop_streaming(name):
    # stream_hash = md5(name.encode('utf8')).hexdigest()
    # try:
    #     remove(path.join(PID_FILE_DIR,
    #                      'stream_cloner_{}.pid'.format(stream_hash)))
    # except:
    #     return False
    try:
        run(['python3', 'stream_cloner.py', 'stop', name])
    except:
        return False
    return True

if __name__ == '__main__':
    streams = {
        'facebook': {'src': 'facebook.com', 'dst': 'facebook.com1'},
        'youtube': {'src': 'youtube.com', 'dst': 'youtube.com1'},
        'periscope': {'src': 'periscope.com', 'dst': 'periscope.com1'},
        'twitch': {'src': 'twitch.com', 'dst': 'twitch.com1'}
    }

    save_stream_list(streams)
    add_stream('hello', 'taramali', 'fuze')
    remove_stream('youtube')
    streams = load_stream_list()
    pprint(streams)
