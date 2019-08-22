app = new Vue({
    'el': '#app',
    'data': {
        'streams': null,
        'new_stream_name': '',
        'new_stream_src': '',
        'new_stream_dst': '',
        'old_stream_name': ''
    },
    'created': function () {
        this.load_streams();
        c = setInterval(this.load_streams, 5000);
    },
    'methods': {
        'request': function (method, location, headers, data, on_success, on_failed) {
            let r = new XMLHttpRequest();
            r.open(method, location);
            r.ontimeout = on_failed;
            header_keys = Object.keys(headers);
            for (var i = header_keys.length - 1; i >= 0; i--) {
                r.setRequestHeader(header_keys[i], headers[header_keys[i]]);
            }
            r.onreadystatechange = function() {
                if (r.readyState == 4 && r.status == 200){
                    on_success(r.responseText);
                } else if (r.readyState == 4) {
                    on_failed(r.responseText);
                }
            };
            r.send(data);
        },
        'load_streams': function () {
            this.request('GET', '/api/', {'Content-Type': 'application/json'}, null,
                (r) => {
                    let streams = JSON.parse(r).value
                    for (var i = 0; i < streams.length; i++) {
                        streams[i].src = decodeURI(streams[i].src);
                        streams[i].dst = decodeURI(streams[i].dst);
                    }
                    this.streams = streams });
        },
        'add_stream': function () {
            data = JSON.stringify({'name': this.new_stream_name,
                                   'src': this.new_stream_src,
                                   'dst': this.new_stream_dst});
            this.reset_modals();
            this.request('POST', '/api/', {'Content-Type': 'application/json'}, data,
                (r) => { this.load_streams(JSON.parse(r).value); });
        },
        'reset_modals': function() {
            $("#stream-add-modal").modal('hide');
            $("#stream-edit-modal").modal('hide');
            $("#deletion-dialog").modal('hide');
            this.$root.old_stream_name = '';
            this.$root.new_stream_name = '';
            this.$root.new_stream_src = '';
            this.$root.new_stream_dst = '';
        },
        'delete_stream': function (name) {
            data = JSON.stringify({'name': name, 'command': 'stop'});
            this.reset_modals();
            application = this;
            this.request('PUT', '/api/', {'Content-Type': 'application/json'}, data,
                (r) => { application.request('DELETE', '/api/', {'Content-Type': 'application/json'}, data,
                            (r) => { application.load_streams(); }) });
        },
        'start_stream': function (name) {
            data = JSON.stringify({'name': name, 'command': 'start'})
            this.request('PUT', '/api/', {'Content-Type': 'application/json'}, data,
                (r) => { this.load_streams(); })
        },
        'stop_stream': function (name) {
            data = JSON.stringify({'name': name, 'command': 'stop'})
            this.request('PUT', '/api/', {'Content-Type': 'application/json'}, data,
                (r) => { this.load_streams(); })
        },
        'update_stream': function() {
            data = JSON.stringify({'name': this.old_stream_name,
                                   'new_src': encodeURI(this.new_stream_src),
                                   'new_dst': encodeURI(this.new_stream_dst)});
            this.reset_modals();
            this.request('PATCH', '/api/', {'Content-Type': 'application/json'}, data,
                (r) => { this.load_streams(); })
        }
    },
    'components': {
        'stream-record': {
            'props': ['s'],
            'template': '\
                <transition name="fade">\
                <a class="list-group-item clearfix" @click.self="open_edit_interface">\
                    <span class="stream-name" @click.self="open_edit_interface">{{ s.name }}</span>\
                    <span class="pull-right">\
                        <button class="btn btn-success" v-show="!s.streaming" @click="$root.start_stream(s.name)"><span class="glyphicon glyphicon-play"></span>&nbsp;Start</button>\
                        <button class="btn btn-danger" v-show="s.streaming" @click="$root.stop_stream(s.name)"><span class="glyphicon glyphicon-stop"></span>&nbsp;Stop</button>\
                        <button class="btn btn-danger" @click="open_delete_interface" :disabled="s.streaming"><span class="glyphicon glyphicon-trash" ></span></button>\
                    </span>\
                </a>\
                </transition>',
            'methods': {
                'save': function() {
                    this.$root.update_stream(
                        this.s.name,
                        this.$root.new_stream_name,
                        this.$root.new_stream_src,
                        this.$root.new_stream_dst);
                },
                'open_edit_interface': function() {
                    this.$root.old_stream_name = this.s.name;
                    this.$root.new_stream_name = this.s.name;
                    this.$root.new_stream_src = this.s.src;
                    this.$root.new_stream_dst = this.s.dst;
                    $('#stream-edit-modal').modal('show');
                },
                'open_delete_interface': function() {
                    this.$root.old_stream_name = this.s.name;
                    console.log('AHOY "', this.$root.old_stream_name, '"')
                    $('#deletion-dialog').modal('show');
                }
            }
        }
    }
})
