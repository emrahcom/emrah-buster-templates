from flask import Flask, request, jsonify, abort, render_template
from app.module import (load_stream_list, save_stream_list,
                        add_stream, remove_stream, update_stream,
                        start_streaming, stop_streaming)


app = Flask(__name__)


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/')
def list_streams_api():
    streams = load_stream_list()
    return jsonify({'status': 'OK', 'value': streams})


@app.route('/api', methods=['POST'])
@app.route('/api/', methods=['POST'])
def add_stream_api():
    name = request.json.get('name')
    src = request.json.get('src')
    dst = request.json.get('dst')
    add_stream(name, src, dst)
    return jsonify({'status': 'OK',
                    'value': {'name': name, 'src': src, 'dst': dst}})


@app.route('/api', methods=['DELETE'])
@app.route('/api/', methods=['DELETE'])
def remove_stream_api():
    name = request.json.get('name')
    remove_stream(name)
    return jsonify({'status': 'OK'})


@app.route('/api', methods=['PUT'])
@app.route('/api/', methods=['PUT'])
def manage_streaming_api():
    name = request.json.get('name')
    command = request.json.get('command')
    result = None
    if command == 'start':
        result = start_streaming(name)
    elif command == 'stop':
        result = stop_streaming(name)
    if not isinstance(result, bool):
        abort(400)
    elif result:
        return jsonify({'status': 'OK'})
    return jsonify({'status': 'ERROR'})


@app.route('/api', methods=['PATCH'])
@app.route('/api/', methods=['PATCH'])
def update_stream_api():
    name = request.json.get('name')
    new_src = request.json.get('new_src')
    new_dst = request.json.get('new_dst')
    result = update_stream(name, new_src, new_dst)
    return jsonify({'status': 'OK', 'value': result})
