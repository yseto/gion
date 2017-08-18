var Gion = Gion || {};

Gion.Agent = window.superagent;
Gion.PostAgent = function(args, then) {
    var agent = Gion.Agent.post(args.url);
    agent = args.json_request ? agent : agent.type('form');

    agent.set({
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.getElementsByName('csrf-token')[0].content,
        'Cache-Control': 'no-cache'
    })
        .send(args.data)
        .on('error', function() {
        Gion.app.error = true;
    })
        .end(then);
};

Vue.component('gion-header', {
    template: '#tmpl_header'
});

// ピンリストに追加されているエントリの一覧を表示する
Gion.Home = {
    template: '#tmpl_home',
    data: function() {
        return {
            list: [],
        };
    },
    created: function() {
        //console.log('created');
        var self = this;
        if (document.getElementById('app') &&
            document.getElementById('app').getAttribute('data-nopin') === 'true') {
            self.$root.go('#entry');
        }

        Gion.PostAgent({
            url: '/api/get_pinlist'
        }, function(error, res) {
            self.list = res.body;
        });
    },
    methods: {
        // 既読にするをクリックされた時の処理
        apply_read: function(event) {
            var self = this;
            Gion.PostAgent({
                url: '/api/set_pin',
                data: {
                    'readflag': 2,
                    'pinid': encodeURI(event.target.getAttribute('data-guid'))
                },
            }, function() {
                self.list.splice(event.target.getAttribute('data-index'), 1);
            });
        }
    }
};

// 購読フィードの追加
Gion.add_app = {
    template: '#tmpl_add_app',
    data: function() {
        return {
            list: [],
            search_state: false,
            field: {},
            success_feed: false,
            category: null,

            inputCategoryName: null
        };
    },
    created: function() {
        //console.log('created');
        this.fetch_list();
    },
    methods: {
        fetch_list: function() {
            var self = this;
            Gion.PostAgent({
                url: '/api/get_targetlist',
            }, function(err, _data) {
                var data = _data.body;
                self.list = data.category;
                self.category = data.category[0].id;
            });
        },
        // カテゴリの登録
        register_category: function() {
            var self = this;
            if (self.inputCategoryName.length === 0) {
                return false;
            }

            Gion.PostAgent({
                url: '/api/register_category',
                data: {
                    'name': self.inputCategoryName
                },
            }, function(err, j) {
                if (j.body.r === "ERROR_ALREADY_REGISTER") {
                    alert("すでに登録されています。");
                } else {
                    self.fetch_list();
                    alert("登録しました。");
                }
            });
        },
        register_feed: function() {
            var self = this;
            Gion.PostAgent({
                url: '/api/register_target',
                data: {
                    'url': self.field.url,
                    'rss': self.field.rss,
                    'title': self.field.title,
                    'category': self.category,
                },
            }, function(error, j) {
                if (j.body === null) {
                    alert('Failure: Get information.\n please check url... :(');
                    return false;
                }
                if (j.body.r === "ERROR_ALREADY_REGISTER") {
                    alert("すでに登録されています。");
                    return false;
                }
                self.success_feed = true;
                self.field = {};
            });

        },
        // ページの詳細を取得する
        feed_detail: function() {
            var self = this;
            if (typeof self.field.url === 'undefined') {
                return false;
            }
            if (self.field.url.match(/^https?:/g) === null) {
                return false;
            }

            self.success_feed = false;
            self.search_state = true;

            Gion.PostAgent({
                url: '/api/examine_target',
                data: {
                    url: self.field.url
                },
            }, function(err, _j) {
                var j = _j.body;
                if (j === null) {
                    alert('Failure: Get information.\n please check url... :(');
                    return false;
                }
                self.field.rss = j.u;
                self.field.title = j.t;
                setTimeout(function() {
                    self.search_state = false;
                }, 500);
            });
        }
    }
};

// エントリーを表示する
Gion.reader = {
    template: '#tmpl_reader',
    data: function() {
        return {
            category: Gion.category_store,
            category_list: [],
            content: Gion.content_store,
            content_list: [],
            pin_list_state: false,
            pin_list: [],
            external_api: {},
            move_flag: true, // ピン立てでは移動しない
        };
    },
    created: function() {
        //console.log('created');
        var self = this;
        Gion.PostAgent({
            url: '/api/get_social_service',
        }, function(err, _data) {
            var data = _data.body;
            data.e.forEach(function(_, index) {
                self.external_api[data.e[index].service] = true;
            });
        });

        // CATEGORY
        Gion.PostAgent({
            url: '/api/get_category',
        }, function(err, _data) {
            var data = _data.body;
            self.category_list = data;
            if (data.length === 0) {
                self.category.clear();
                return false;
            }
            self.category.set(self.category_list, 0);
            //console.log(self.category_list);
            //console.log(self.category.category());
            self.content_update();
        });
    },
    destroyed: function() {
        //console.log('destroyed');
        document.removeEventListener('keypress', this.keypress_handler);
    },
    mounted: function() {
        // キーボードのイベント
        document.addEventListener("keypress", this.keypress_handler);
    },
    // 移動
    updated: function() {
        //console.log('updated');
        if (document.querySelectorAll('.tw--active').length === 0) {
            return false;
        }
        //console.log('updated', 'exists');

        if (this.move_flag === false) {
            this.move_flag = true;
            return false;
        }

        var element = document.querySelectorAll('.tw--active');
        if (element.length !== 1) {
            return false;
        }
        var rect = element[0].getBoundingClientRect();
        var positionY = rect.top + window.pageYOffset - 80; // offset: 80
        window.scrollTo(0, positionY);
    },
    methods: {
        keypress_handler: function(e) {
            //console.log('keypress');
            e.preventDefault();
            // http://www.programming-magic.com/file/20080205232140/keycode_table.html
            switch (e.keyCode || e.which) {
                case 97:
                    this.category_previous();
                    break; // A
                case 115:
                    this.category_next();
                    break; // S
                case 111:
                    this.pin_list_switch();
                    break; // O
                case 112:
                    this.toggle_pin();
                    break; // P
                case 114:
                    this.content_update();
                    break; // R
                case 107:
                    this.content_previous();
                    break; // K
                case 106:
                    this.content_next();
                    break; // J 
                case 118:
                    this.item_view();
                    break; // V
                case 105:
                    this.add_bookmark_keyboard('hatena');
                    break; // I
                case 108:
                    this.add_bookmark_keyboard('pocket');
                    break; // L
            }
        },

        // ::: CATEGORY :::
        // カテゴリの移動
        category_next: function() {
            if (this.category_list.length === 0) {
                return false;
            }
            var index = this.category.selected() + 1;
            if (index === this.category_list.length) {
                index = 0;
            }
            this.category.set(this.category_list, index);
            this.content_update();
        },
        category_previous: function() {
            if (this.category_list.length === 0) {
                return false;
            }
            var index = this.category.selected() - 1;
            if (0 > index) {
                index = this.category_list.length - 1;
            }
            this.category.set(this.category_list, index);
            this.content_update();
        },
        // カテゴリ一覧の更新
        category_update: function() {
            var self = this;
            //console.info('category_update');

            Gion.PostAgent({
                url: '/api/get_category',
            }, function(err, _data) {
                var data = _data.body;
                var updated = false;
                self.category_list = data;

                // Vue の dataを更新する
                data.forEach(function(_, index) {
                    // category_id が一致するものがある
                    // 画面描画を更新する必要がある
                    if (self.category.category() === data[index].i) {
                        self.category.set_index(index); // 更新
                        updated = true; // 更新したフラグ
                        return false;
                    }
                });
                // 更新していない場合は、カテゴリ一覧を一番上に設定する
                // ただし、選択可能なカテゴリがない場合は実行しない
                if (data.length > 0 && !updated) {
                    self.category.set(self.category_list, 0);
                    self.content_update();
                }
                //console.log('done');
            });
        },
        // ::: CONTENT :::
        // エントリの移動
        content_next: function() {
            var index = this.content.selected() + 1;
            if (index === this.content_list.length) {
                return false;
            }
            this.content.set(this.content_list, index);
        },
        content_previous: function() {
            var index = this.content.selected() - 1;
            if (0 > index) {
                return false;
            }
            this.content.set(this.content_list, index);
        },
        // エントリ一覧の更新
        content_update: function() {
            var self = this;
            //console.info('content_update');

            // 初期値は0に設定すると、初期状態(カテゴリリストの先頭)のカテゴリを示す
            var id = (self.category.category() === null) ? 0 : self.category.category();

            Gion.PostAgent({
                url: '/api/get_entry',
                data: {
                    'category': id
                },
            }, function(err, _data) {
                var data = _data.body;
                self.content_list = (typeof data.entry !== 'undefined') ? data.entry : [];
                if (self.content_list.length > 0) {
                    self.read_it();
                    self.content.set(self.content_list, 0);
                }
                self.category_update();
            });
        },
        // アイテムを閲覧する
        item_view: function() {
            var index = this.content.selected();
            window.open(this.content_list[index].url);
        },
        // フィードのアイテム既読リストを作成し、既読フラグを付加する
        read_it: function() {
            var self = this;
            //console.warn('flagged');

            var param = [],
                id = this.category.category();
            self.content_list.forEach(function(item) {
                // 未読ステータスのものだけ送るため、
                // フィードのアイテム既読リストを作成をする
                if (item.readflag === 0) {
                    param.push(item.guid);
                }
            });

            //console.warn('read_it > param', param);
            // 未読ステータスのものがなければ抜ける
            if (param.length === 0) {
                return false;
            }

            // ダブルタップやキーボードの連続押下で、誤ってしまった場合、送信前にカテゴリを確認する。
            setTimeout(function() {
                if (id !== Gion.category_store.category()) {
                    //console.warn(id, Gion.category_store.category() );
                    //console.warn('read_it', 'no send');
                    return false;
                }
                //console.warn('read_it', 'send');
                Gion.PostAgent({
                    url: '/api/set_asread',
                    json_request: true,
                    data: JSON.stringify({
                        'guid': param
                    }),
                }, function() {
                    //console.log('read_it', 'send.done');
                });
            }, 500);
        },
        // ::: PINLIST :::
        // ピン立て
        toggle_pin: function(index) {
            var self = this;
            index = (typeof index !== 'undefined') ? index : self.content.selected();
            // サーバーにピン立てを通知する
            //console.log(self.content_list[index].readflag);
            Gion.PostAgent({
                url: '/api/set_pin',
                data: {
                    'readflag': self.content_list[index].readflag,
                    'pinid': self.content_list[index].guid
                },
            }, function(err, data) {
                //console.log(data);
                self.content_list[index].readflag = data.body.readflag;
                self.move_flag = false;
            });
        },
        // ピンリストに追加されているエントリの一覧を表示する
        pin_list_update: function() {
            var self = this;
            Gion.PostAgent({
                url: '/api/get_pinlist',
            }, function(err, data) {
                self.pin_list = data.body;
            });
        },
        pin_list_switch: function() {
            this.pin_list_state = (this.pin_list_state === true) ? false : true;
            if (this.pin_list_state === true) {
                this.pin_list_update();
            }
        },
        pin_list_clean: function() {
            var self = this;
            if (!confirm('ピンをすべて外しますか?')) {
                return false;
            }

            self.pin_list_state = false;
            Gion.PostAgent({
                url: '/api/remove_all_pin',
            }, function() {
                self.pin_list = [];
            });
        },
        // ::: BOOKMARK :::
        // 外部サービスへポストする
        add_bookmark: function(event) {
            var comment;
            var service = event.target.getAttribute('data-service');

            if (service === 'hatena') {
                comment = window.prompt("type a comment", "");
            }

            Gion.PostAgent({
                url: '/external_api/' + service + '/post',
                data: {
                    'url': event.target.getAttribute('data-url'),
                    'comment': comment,
                },
            }, function() {});
        },
        add_bookmark_keyboard: function(service) {
            var self = this;
            var comment;

            if (service === 'hatena') {
                comment = window.prompt("type a comment", "");
            }

            Gion.PostAgent({
                url: '/external_api/' + service + '/post',
                data: {
                    'url': self.content.url(),
                    'comment': comment,
                },
            }, function() {});
        }
    },
};

// 設定ページ
Gion.settings = {
    template: '#tmpl_settings',
    data: function() {
        return {
            checked: [],
            numentry: 0,
            numsubstr: 0,
            external_api: {
                pocket: {
                    name: 'Pocket (formerly read it later)',
                    state: false,
                },
                hatena: {
                    name: 'Hatena Bookmark',
                    state: false,
                },
            },
            finished: false,
            password: null,
            password_old: null,
            passwordc: null,
            username: null,
            user_password: null
        };
    },
    created: function() {
        //console.log('created');
        var self = this;
        Gion.PostAgent({
            url: '/api/get_numentry',
        }, function(err, _a) {
            var a = _a.body;
            if (a.noreferrer === 1) {
                self.checked.push('noreferrer');
            }
            if (a.nopinlist === 1) {
                self.checked.push('nopinlist');
            }
            self.numsubstr = a.numsubstr;
            self.numentry = a.numentry;
        });
        Gion.PostAgent({
            url: '/api/get_social_service',
        }, function(err, _data) {
            var data = _data.body;
            data.e.forEach(function(_, index) {
                self.external_api[data.e[index].service].state = true;
                self.external_api[data.e[index].service].username = data.e[index].username;
            });
        });
    },
    methods: {
        apply: function() {
            var self = this;
            Gion.PostAgent({
                url: '/api/set_numentry',
                data: {
                    'numentry': self.numentry,
                    'noreferrer': (self.checked.indexOf('noreferrer') >= 0) ? 1 : 0,
                    'nopinlist': (self.checked.indexOf('nopinlist') >= 0) ? 1 : 0,
                    'numsubstr': self.numsubstr,
                },
            }, function() {
                self.finished = true;
                setTimeout(function() {
                    self.finished = false;
                }, 1000);
            });
        },
        update_password: function() {
            var self = this;
            Gion.PostAgent({
                url: '/api/update_password',
                data: {
                    password_old: self.password_old,
                    password: self.password,
                    passwordc: self.passwordc
                }
            }, function(err, p) {
                alert(p.body.e);
            });
        },
        create_user: function() {
            var self = this;
            Gion.PostAgent({
                url: '/api/create_user',
                data: {
                    username: self.username,
                    password: self.user_password
                }
            }, function(err, p) {
                alert(p.body.e);
            });
        }
    }
};

// 購読フィード一覧を表示する
Gion.subscription = {
    template: '#tmpl_subscription',
    data: function() {
        return {
            category: [],
            target: [],
            lists: [],
            field_category: null,
            field_id: null,
            categoryModal: false
        };
    },
    created: function() {
        //console.log('created');
        this.fetch_list();
    },
    methods: {
        // エントリのカテゴリの変更ウィンドウを表示する
        change_category: function(id, category) {
            this.field_category = category;
            this.field_id = id;
            this.categoryModal = true;
        },
        remove_it: function(id, type, name) {
            var self = this;
            if (!confirm(name + ' を削除しますか')) {
                return false;
            }
            Gion.PostAgent({
                url: '/api/delete_it',
                data: {
                    target: type,
                    id: id
                }
            }, function() {
                self.fetch_list();
            });
        },
        // カテゴリの変更
        submit: function() {
            var self = this;
            Gion.PostAgent({
                url: '/api/change_it',
                data: {
                    id: self.field_id,
                    category: self.field_category,
                },
            }, function() {
                self.categoryModal = false;
                self.fetch_list();
            });
        },
        fetch_list: function() {
            var self = this;
            var tmp = [],
                list = {};
            Gion.PostAgent({
                url: '/api/get_targetlist'
            }, function(err, _a) {
                var a = _a.body;
                self.category = a.category;
                self.target = a.target;

                self.category.forEach(function(_, i) {
                    list[self.category[i].id] = {
                        id: self.category[i].id,
                        list: [],
                        name: self.category[i].name
                    };
                });
                self.target.forEach(function(_, i) {
                    list[self.target[i].category_id].list.push(self.target[i]);
                });

                // combined
                Object.keys(list).forEach(function(i) {
                    tmp.push({
                        id: list[i].id,
                        name: list[i].name,
                        type: 'title',
                    });
                    list[i].list.forEach(function(_, j) {
                        var value = list[i].list[j];
                        value.type = 'item';
                        tmp.push(value);
                    });
                }, list);
                self.lists = tmp;
            });
        }
    }
};

// 状態管理 ref. https://jp.vuejs.org/v2/guide/state-management.html
Gion.category_store = {
    state: {
        category: null,
        selected: 0
    },
    set: function(list, index) {
        this.state.category = list[index].i;
        this.state.selected = index;
    },
    set_index: function(index) {
        this.state.selected = index;
    },
    clear: function() {
        this.state.category = null;
        this.state.selected = 0;
    },
    selected: function() {
        return this.state.selected;
    },
    category: function() {
        return this.state.category;
    }
};
Gion.content_store = {
    state: {
        guid: null,
        selected: 0
    },
    set: function(list, index) {
        this.state.guid = list[index].guid;
        this.state.url = list[index].raw_url;
        this.state.selected = index;
    },
    clear: function() {
        this.state.guid = null;
        this.state.url = null;
        this.state.selected = 0;
    },
    selected: function() {
        return this.state.selected;
    },
    guid: function() {
        return this.state.guid;
    },
    url: function() {
        return this.state.url;
    }
};

// ref https://jp.vuejs.org/v2/guide/routing.html

Gion.NotFound = {
    template: '<div><gion-header></gion-header><div class="container"><h1>Not Found <small>oops...</small></h1></div></div>'
};

Gion.routes = {
    '': Gion.Home,
    '#add': Gion.add_app,
    '#entry': Gion.reader,
    '#settings': Gion.settings,
    '#subscription': Gion.subscription
};

Gion.app = new Vue({
    el: '#app',
    data: {
        currentRoute: window.location.hash,
        helpModal: false,
        error: false,
        navbarState: false
    },
    computed: {
        ViewComponent: function() {
            return Gion.routes[this.currentRoute] || Gion.NotFound;
        }
    },
    methods: {
        go: function(value) {
            window.location.hash = value;
            this.currentRoute = value;
            this.navbarState = false;
        },
        returntop: function() {
            window.scrollTo(0, 0);
        },
        navbar: function() {
            this.navbarState = this.navbarState ? false : true;
        },
    },
    render: function(h) {
        //console.log(this.ViewComponent);
        //console.log(this.currentRoute);
        return h(this.ViewComponent);
    }
});
