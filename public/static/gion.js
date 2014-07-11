if (typeof window.console === "undefined") {
    window.console = {};
}

if (typeof window.console.log !== "function") {
    window.console.log = function() {};
}

var Gion = function() {
    this.initialize.apply(this, arguments);
};

$(function(Gion) {
    var G = Gion.prototype;

    G.initialize = function(opt) {
        var options = $.extend(true, {
            // Read Page
            selection: 0,
            prev_selection: 0,
            service_state: {},
            cat_idx_prev: '',
            cat_idx_next: '',
            cat_idx_selected: '0',
            colour_selected: '#339',
            colour_nonselected: '#999',
            timer_asread: 500,
            service: [{
                name: 'Pocket (formerly read it later)',
                id: 'pocket'
            }],
            actions: function() {},
            /*
             * 外部サービスの接続状態を取得する
             */
            service_connection: function() {
                var self = this;
                jQuery.ajax({
                    type: 'POST',
                    url: '/manage/get_connect',
                    datatype: 'json',
                    async: false,
                    success: function(a) {
                        if (a.e === null) {
                            return false;
                        }
                        jQuery.each(a.e, function() {
                            self.service_state[this.service] = this.username;
                        });
                    },
                    error: function() {},
                });
            }
        }, opt || {});
        this.option = options;
        this.menu();
    };

    G.menu = function() {
        var nav = $('.nav');
        nav.on('click', 'a[href="#home"]', function() {
            location.href = "/";
        });
        nav.on('click', 'a[href="#entries"]', function() {
            location.href = "/entries/";
        });
        nav.on('click', 'a[href="#addasite"]', function() {
            location.href = "/add/";
        });
        nav.on('click', 'a[href="#subscription"]', function() {
            location.href = "/subscription/";
        });
        nav.on('click', 'a[href="#settings"]', function() {
            location.href = "/settings/";
        });
        nav.on('click', 'a[href="#logout"]', function() {
            location.href = "/?logout=1";
        });

        $('#helpmodal').click(function() {
            $('#helpModal').modal('show');
        });

        $('#returntop').click(function() {
            $('html,body').animate({
                scrollTop: 0
            }, 'fast');
        });

        jQuery.ajaxSetup({
            cache: false,
            error: function() {
                $('#myModal').modal('show');
            },
            beforeSend: function() {},
            complete: function() {},
        });
    };

    G.subscription = function() {

        /*
         * 購読フィード一覧を表示する
         */
        var list = function() {
            $('.appendlist').remove();
            jQuery.ajax({
                type: 'POST',
                url: '/inf/get_targetlist',
                datatype: 'json',
                success: function(b) {
                    $('#selectCat').empty();

                    jQuery.each(b.n, function() {
                        var tr = $('<tr>').attr('id', 'child_' + this.i).addClass('appendlist');

                        tr.append($('<td>').attr('colspan', 2).append($('<button>').addClass('deletebtn btn btn-danger btn-xs')
                            .data('name', this.n).data('target', 'category').data('id', this.i).text('削除')));
                        tr.append($('<th>').text(this.n));

                        $('#cat_list').append(tr);

                        $('#selectCat').append($('<option>').val(this.i).text(this.n));
                    });

                    jQuery.each(b.t, function() {
                        var tr = $('<tr>').addClass('appendlist');

                        tr.append($('<td>').append($('<button>').addClass('deletebtn btn btn-danger btn-xs')
                            .data('name', this.n).data('target', 'entry').data('id', this.i).text('削除')));

                        tr.append($('<td>').append($('<button>').addClass('categorybtn btn btn-info btn-xs')
                            .data('name', this.c).data('id', this.i).text('変更')));

                        var cutstr = this.n.substr(0, 20);
                        if (cutstr !== this.n) {
                            cutstr = cutstr + '...';
                        }

                        var linkage = $('<a>').addClass('btn btn-link btn-xs').attr({
                            href: this.h,
                            target: 'blank',
                            title: this.n,
                        }).append($('<span>').addClass('visible-xs').text(cutstr))
                            .append($('<span>').addClass('visible-sm visible-md visible-lg').text(this.n));

                        if (this.r < -5 || this.r === "404") {
                            linkage.append($('<span>').addClass('badge ').text('取得に失敗しました'));
                            tr.addClass('danger');
                        }
                        tr.append($('<td>').append(linkage));

                        $('#child_' + this.c).after(tr);
                    });
                }
            });
        };

        /*
         * カテゴリの変更決定ボタン
         */
        $(document).on('click', '#change-categories', function() {
            jQuery.ajax({
                type: 'POST',
                url: '/manage/change_it',
                data: {
                    'id': $('#target-id').val(),
                    'cat': $('#selectCat').val(),
                },
                datatype: 'json',
                success: function() {
                    $('#categoriesModal').modal('hide');
                    list();
                }
            });
        });

        /*
         * 削除ボタンを表示する
         */
        $(document).on('click', '.deletebtn', function() {
            if (confirm($(this).data('name') + ' を削除しますか')) {
                jQuery.ajax({
                    type: 'POST',
                    url: '/manage/delete_it',
                    data: {
                        'target': $(this).data('target'),
                        'id': $(this).data('id'),
                    },
                    datatype: 'json',
                    success: function() {
                        list();
                    }
                });
            }
        });

        /*
         * エントリのカテゴリの変更ウィンドウを表示する
         */
        $(document).on('click', '.categorybtn', function() {
            $('#selectCat').val($(this).data('name'));
            $('#target-id').val($(this).data('id'));
            $('#categoriesModal').modal('show');
        });

        list();
    };


    G.settings = function() {
        var self = this.option;

        /*
         * 設定を取得
         */
        jQuery.ajax({
            type: 'POST',
            url: '/manage/get_numentry',
            datatype: 'json',
            success: function(b) {
                $('#numentry').val(b.r);
                $('#numsubstr').val(b.s);
                if (b.n === 0) {
                    $('#noreferrer').attr('checked', false);
                    $('#noreferrer').val(0);
                } else {
                    $('#noreferrer').attr('checked', true);
                    $('#noreferrer').val(1);
                }

                if (b.p === 0) {
                    $('#nopinlist').attr('checked', false);
                    $('#nopinlist').val(0);
                } else {
                    $('#nopinlist').attr('checked', true);
                    $('#nopinlist').val(1);
                }

            }
        });
        $('#txt_numentry').hide();
        $('.disconnect').hide();

        /*
         * 外部サービスの設定を取得する
         */
        self.service_connection();
        jQuery.each(self.service, function() {
            var connect = 0;
            var set_connect = '連携する';
            var set_disconnect = 'hide';
            var set_connect_state;

            if (self.service_state[this.id]) {
                connect = 1;
                set_connect = self.service_state[this.id];
                set_disconnect = '';
                set_connect_state = 'disabled';
            }
            var table = $('#service_list');
            var td = $('<td>');
            td.append(
                $('<span>').text(this.name)
            )
                .append(
                    $('<a>').addClass('disconnect ' + set_disconnect).attr({
                        id: 'disconnect' + this.id,
                        href: '/api/' + this.id + '/disconnect'
                    })
                    .append($('<span>').addClass('glyphicon glyphicon-remove')
                        .append($('<span>').text('連携の解除'))
                    )
            );

            var td2 = $('<td>');
            td2.append(
                $('<a>').addClass('btn btn-default').attr({
                    id: 'btn' + this.id,
                    href: '/api/' + this.id + '/connect',
                    disabled: set_connect_state
                })
                .append($('<span>').addClass('glyphicon glyphicon-link')
                    .append($('<span>').text(set_connect))
                )
            );
            var tr = $('<tr>');
            tr.append(td).append(td2);
            table.append(tr);
        });



        /*
         * サービスの切断をする
         */
        $('.disconnect').click(function() {
            if (confirm('続行しますか?')) {} else {
                return false;
            }
        });

        $('#btn_numentry').click(function() {
            jQuery.ajax({
                type: 'POST',
                url: '/manage/set_numentry',
                datatype: 'json',
                data: {
                    'val': $('#numentry').val(),
                    'noref': $('#noreferrer').val(),
                    'nopin': $('#nopinlist').val(),
                    'substr': $('#numsubstr').val()
                },
                success: function() {
                    $('#txt_numentry').show();
                }
            });
        });

        $('.noreferrer').click(function() {
            if ($('#noreferrer').prop('checked') === true) {
                $('#noreferrer').val(1);
            } else {
                $('#noreferrer').val(0);
            }
        });

        $('.nopinlist').click(function() {
            if ($('#nopinlist').prop('checked') === true) {
                $('#nopinlist').val(1);
            } else {
                $('#nopinlist').val(0);
            }
        });
    };



    G.welcome = function() {
        // var self = this.option;
        /*
         * ピンリストに追加されているエントリの一覧を表示する
         */
        var refresh = function() {
            jQuery.ajax({
                type: 'POST',
                url: '/inf/get_pinlist',
                datatype: 'json',
                async: false,
                success: function(a) {
                    var count = 0;
                    $('#pinlist_ul').empty();
                    jQuery.each(a, function() {
                        var li = $('<a>').attr({
                            id: this.g
                        }).addClass('read glyphicon glyphicon-check').text('');
                        li.css('cursor', 'pointer');
                        var lic = $('<span>').text(' ')
                            .append($('<span>').text(this.m))
                            .append($('<span>').text(' '))
                            .append($('<a>').attr({
                                href: this.u,
                                target: 'blank',
                            }).text(this.t));
                        $('#pinlist_ul').append($('<li>').append(li).append(lic).addClass('list-group-item'));
                        count++;
                    });
                    $('#pincount').text(count);
                },
            });
        };

        /*
         * 設定を参照して、ピンリストを表示するか調べる
         */
        jQuery.ajax({
            type: 'POST',
            url: '/manage/get_numentry',
            datatype: 'json',
            success: function(b) {
                if (b.p === 1) {
                    location.href = "/entries/";
                } else {
                    refresh();
                }
            }
        });

        /*
         * 既読にするをクリックされた時の処理
         */
        $(document).on('click', '.read', function() {
            jQuery.ajax({
                type: 'POST',
                url: '/inf/set_pin',
                data: {
                    'flag': 0,
                    'pinid': encodeURI($(this).attr('id'))
                },
                datatype: 'text',
                success: function() {
                    refresh();
                },
            });
        });
    };

    G.register = function() {
        // var self = this.option;

        /*
         * カテゴリリスト
         */
        var get_targetlist = function() {
            $('#selectCat').empty();
            jQuery.ajax({
                type: 'POST',
                url: '/inf/get_targetlist',
                datatype: 'json',
                success: function(b) {
                    jQuery.each(b.n, function() {
                        $('#selectCat').append($('<option>').val(this.i).text(this.n));
                    });
                },
            });
        };

        /*
         * ページの詳細を取得する
         */
        var get_detail = function() {
            if ($('#inputURL').val().match(/^http/g) === null) {
                return false;
            }
            $('#url-search').show();
            jQuery.ajax({
                type: 'POST',
                url: '/manage/examine_target',
                data: {
                    'm': $('#inputURL').val()
                },
                datatype: 'json',
            })
                .done(function(j) {
                    if (j === null) {
                        alert('Failure: Get information.\n please check url... :(');
                    } else {
                        $('#inputRSS').val(j.u);
                        $('#inputTitle').val(j.t);
                    }
                })
                .always(function() {
                    $('#url-search').delay(400).fadeOut();
                });
        };

        /*
         * 初期化
         */

        /*
         * カテゴリの登録
         */
        $('#cat_submit').click(function() {
            if ($('#inputCategoryName').val().length === 0) {
                return false;
            }
            jQuery.ajax({
                type: 'POST',
                url: '/manage/register_categories',
                data: {
                    'name': $('#inputCategoryName').val(),
                },
                datatype: 'json',
                success: function(j) {
                    if (j.r === "ERROR_ALREADY_REGISTER") {
                        alert("すでに登録されています。");
                    } else {
                        get_targetlist();
                        $('#return_cat').text('Thanks! add your request.');
                    }
                }
            });
        });

        /*
         * フィードエントリの登録
         */
        $('#submit').click(function() {

            $('#return').empty();
            jQuery.ajax({
                type: 'POST',
                url: '/manage/register_target',
                data: {
                    'url': $('#inputURL').val(),
                    'rss': $('#inputRSS').val(),
                    'title': $('#inputTitle').val(),
                    'cat': $('#selectCat option:selected').val(),
                },
                datatype: 'json',
                success: function(j) {
                    if (j === null) {
                        alert('Failure: Get information.\n please check url... :(');
                    } else {
                        if (j.r === "ERROR_ALREADY_REGISTER") {
                            alert("すでに登録されています。");
                        } else {
                            $('#return').text('Thanks! add your request.');
                        }
                    }
                }
            });
        });

        $('#inputURL').focusout(function() {
            get_detail();
        });

        $('#get_detail').click(function() {
            get_detail();
        });

        get_targetlist();
        $('#url-search').hide();
    };



    G.reader = function() {
        var self = this.option;

        /*
         * フォーカス移動
         */
        var moveselector = function() {
            var topoffset = -80;
            var selector = '.tw:eq(' + self.selection + ')';

            // 移動を許されている範囲を逸脱している場合、return
            if (!(self.selection >= 0 && $('.tw').length > self.selection)) {
                self.selection = 0;
                return;
            }

            // 色換え
            $(selector).css("border-color", self.colour_selected);
            if (self.prev_selection !== self.selection) {
                $('.tw:eq(' + self.prev_selection + ')').css("border-color", self.colour_nonselected);
            }

            // 移動
            $($.browser.msie || $.browser.mozilla || ($.browser.opera && !$.browser.webkit) ? 'html' : 'body').animate({
                scrollTop: $(selector).offset().top + topoffset,
            }, 0);
        };

        /*
         * カテゴリリストの作成
         */
        var cat_list = function(qp) {
            var q;
            if (typeof qp !== 'undefined') {
                q = parseInt(qp);
            }
            var frag = document.createDocumentFragment();
            jQuery.ajax({
                type: 'POST',
                url: '/inf/get_categories',
                datatype: 'json',
                async: false,
                success: function(b) {
                    var link = [];
                    jQuery.each(b, function(i, data) {
                        var li = $('<a>').addClass('categories_link list-group-item').attr({
                            id: 'categories_link_' + data.i,
                            href: '/#' + data.i
                        }).text(data.n).append($('<span>').addClass('badge hidden-sm').text(data.c));
                        frag.appendChild(li[0]);
                        link[i] = '/#' + data.i;
                    });
                    $('#cat_list').empty().append(frag);

                    jQuery.each(b, function(i, data) {
                        if (q === undefined) { // not selected (first)
                            self.cat_idx_prev = link[b.length - 1];
                            self.cat_idx_next = link[1];
                        }else if(q === parseInt(data.i)) { // selected
                            if(link[i-1] !== undefined){ 
                                self.cat_idx_prev = link[i-1];
                            }else{ // when nothing previous
                                self.cat_idx_prev = link[b.length - 1];
                            }
                            if(link[i+1] !== undefined){ 
                                self.cat_idx_next = link[i+1];
                            }else{ // when nothing next
                                self.cat_idx_next = link[0];
                            }
                        }
                    });
                }
            });
        };

        /*
         * フィードのアイテムを表示する
         */
        var entries = function(b) {

            if (typeof b === 'undefined' || b.length === 0 ) {
                var div = $('<div>').addClass('tw panel panel-default');
                div.append($('<h3>').text('Nothing Entries.'));
                $('#contents_view_box').empty().append(div);
                return false;
            }

            var frag = document.createDocumentFragment();

            jQuery.each(b, function() {

                var div = $('<div>');
                div.addClass('tw panel panel-default');

                div.attr({
                    id: this.g // ピン立てなどに利用する
                });

                var texttitle = '[nothing title...]';
                if (this.t.length > 0) {
                    texttitle = this.t;
                }

                var titleh4 = $('<h4>').addClass('viewpage').append($('<a>').attr({
                    href: this.u,
                    target: 'blank',
                    rel: 'noreferrer', // リファラを送らない(だめな時はリファラを抑制するオプションを使って外部リダイレクタを利用する)
                }).text(texttitle).click(function() {
                    window.open(this.href);
                    return false;
                }).css('color', '#333'));

                if (this.r === "2") { // ピン立てしているアイテム
                    titleh4.css('background-color', '#6cf');
                }

                div.append(titleh4);

                div.append($('<p>').text(this.d)); // description

                var pintarget = $('<p>').addClass('add pull-right').append($('<span>').addClass('glyphicon glyphicon-ok')).append(' Pin!');

                if (this.r !== "2") { //ピン立てしていない時の状態
                    pintarget.hide();
                }

                div.append($('<a>').addClass('pinlink hidden-md hidden-lg btn btn-info btn-sm').text('Pin!')); //スマホ用ピン立て

                // 外部サービスごとのボタンを生成する
                var btn = $('<div>').addClass('text-right').prepend($('<br>').addClass('hidden-md hidden-lg'));
                var service_link = this.s;
                $.each(self.service_state, function(i) {
                    btn.append($('<span>').css('margin-left', '1em'));
                    btn.append($('<button>').addClass('service btn btn-danger btn-sm').text(i).data('service', i).data('url', service_link));
                });

                div.append(btn);
                div.append(pintarget);
                div.append($('<p>').text(this.p));

                frag.appendChild(div[0]);
            });

            $('#contents_view_box').empty().append(frag);
        };

        /*
         * フィードのアイテム既読リストを作成をする
         */
        var send_read = function(param, id) {
            /*
             * ダブルタップやキーボードの連続押下で、
             * 誤ってしまった場合、送信前にカテゴリを確認する。
             */
            if ('/#' + id !== self.cat_idx_selected) {
                return false;
            }
            jQuery.ajax({
                type: 'POST',
                url: '/inf/set_asread',
                data: {
                    'g': param
                },
                datatype: 'json',
                success: function() {},
            });
        };

        /*
         * フィードのアイテム既読リストを作成をする
         */
        var send_read_register = function(content, id) {
            if ( content === undefined ) {
                return false;
            }
            var param = [];
            jQuery.each(content, function() {
                if (this.r === "0") { // 未読ステータスのものだけ送る
                    param.push(this.g);
                }
            });
            if (param.length > 0) { // 未読ステータスのものがあるか
                setTimeout(function() {
                    send_read(param, id);
                }, self.timer_asread);
            }
        };

        /*
         * コンテンツを取得する
         */
        var get_contents = function(id) {

            jQuery.ajax({
                type: 'POST',
                url: '/inf/get_entries',
                data: {
                    'cat': id
                },
                datatype: 'json',
                success: function(b) {
                    entries(b.c);
                    moveselector();
                    self.cat_idx_selected = '/#' + b.id;
                    send_read_register(b.c, b.id);
                },
            });
        };

        // カテゴリ移動
        var categories_link = function(q) {
            q = q.replace('/#', '');
            if (jQuery.isNumeric(q)) {
                cat_list(q);
                $('.categories_link').removeClass('active');
                get_contents(q);
                if (parseInt(q) === 0) {
                    $('.categories_link:first').addClass('active');
                } else {
                    $('#categories_link_' + q).addClass('active');
                }
                self.selection = 0;
                moveselector();
            }
        };

        /*
         * サーバーにピン立てを通知する
         */
        var post_pin = function(id) {
            jQuery.ajax({
                type: 'POST',
                url: '/inf/set_pin',
                data: {
                    'flag': is_toggle_pin(id),
                    'pinid': encodeURI(id.attr('id'))
                },
                datatype: 'text',
                success: function() {},
            });
        };

        /*
         * ピン立て
         */
        var item_pin = function() {
            var it = $('.tw:eq(' + self.selection + ')');
            it.children('.add').toggle();
            post_pin(it);
        };

        /*
         * アイテムを閲覧する
         */
        var item_view = function() {
            $('.tw:eq(' + self.selection + ') > .viewpage > a').click();
        };

        /*
         * フォーカスを戻す
         */
        var item_prev_focus = function() {
            self.prev_selection = self.selection; //色換えのため
            self.selection--;

            //範囲を超えた場合
            if (self.selection < 0) {
                self.selection = 0;
            }

            moveselector();
        };

        /*
         * フォーカスを進める
         */
        var item_next_focus = function() {

            //最終端を指定している場合、次はないので抑制
            if (self.selection === $('.tw').length - 1 && $('.tw').length - 1 > 0) {
                self.selection--;
            }

            self.prev_selection = self.selection; //色換えのため
            self.selection++;

            //範囲を超えた場合
            if ($('.tw').length - 1 < self.selection) {
                self.selection = $('.tw').length - 1;
            }

            moveselector();
        };

        /*
         * ピンの状態を検出する
         */
        var is_toggle_pin = function(id) {
            var titleh4 = id.children('h4');
            if (id.children('.add').css("display") === "block") {
                titleh4.css('background-color', '#6cf');
                return 1;
            }
            titleh4.css('background-color', 'inherit');
            return 0;
        };

        /*
         * 次のカテゴリへ移動する
         */
        var categories_next = function() {
            if (self.cat_idx_next !== undefined) {
                categories_link(self.cat_idx_next);
            }
        };

        $('#btn_categories_next').click(function() {
            categories_next();
        });

        /*
         * 前のカテゴリへ移動する
         */
        var categories_prev = function() {
            if (self.cat_idx_prev !== undefined) {
                categories_link(self.cat_idx_prev);
            }
        };

        $('#btn_categories_prev').click(function() {
            categories_prev();
        });

        /*
         * 指定された外部サービスのボタンをクリックしたことにする
         */
        var item_service = function(service_name) {
            var it = $('.tw:eq(' + self.selection + ') * ');
            var scope = it.children('.service');
            for (var i = 0; i < scope.length; i++) {
                if (scope.eq(i).text() === service_name) {
                    scope.eq(i).click();
                }
            }
        };

        // 外部サービスの状態を取得
        self.service_connection();

        /*
         * カテゴリリストを取得し、先頭一件目を選択状態にする
         * またそのコンテンツを取得する
         */
        cat_list();
        $('.categories_link').removeClass('active');
        get_contents(0);
        $('.categories_link:first').addClass('active');
        $('#pinlist').hide();
        moveselector();

        /*
         * カテゴリリストのリンクをクリック
         */
        $('#cat_list').on('click', '.categories_link', function(e) {
            categories_link($(this).attr('href'));
            e.preventDefault();
        });

        /*
         *  ピンリスト
         */
        $('#toggle_pinlist').click(function() {
            if ($('#pinlist').css("display") !== "block") {

                jQuery.ajax({
                    type: 'POST',
                    url: '/inf/get_pinlist',
                    datatype: 'json',
                    async: false,
                    success: function(a) {
                        var count = 0;
                        $('#pinlist_ul').empty();
                        jQuery.each(a, function() {
                            $('#pinlist_ul').append($('<a>').attr({
                                href: this.u
                            }).text(this.t).addClass('list-group-item'));
                            count++;
                        });
                        $('#pincount').text(count);
                    },
                });

            }
            $('#pinlist').toggle();
        });

        /*
         * すべてのピンを外す
         */
        $('#remove_all_pin').click(function() {
            if (confirm('ピンをすべて外しますか?')) {
                jQuery.ajax({
                    type: 'POST',
                    url: '/inf/remove_all_pin',
                    datatype: 'json',
                    success: function() {
                        cat_list();
                        $('.categories_link').removeClass('active');
                        get_contents(0);
                        $('.categories_link:first').addClass('active');
                        self.selection = 0;
                        moveselector();
                    },
                });
            }
        });

        /*
         * ピン立てのボタン
         */
        $(document).on('click', '.pinlink', function() {
            var it = $(this).closest('div');
            it.children('.add').toggle();
            post_pin(it);
        });

        /*
         * 外部サービスへポストする
         */
        $(document).on('click', '.service', function() {
            var r = $(this);
            jQuery.ajax({
                type: 'POST',
                url: '/api/' + $(this).data('service') + '/post',
                datatype: 'json',
                data: {
                    'url': $(this).data('url'),
                },
                success: function(a) {
                    if (a.e === 'ok') {
                        r.text('posted').attr('disabled', 'disabled');
                    }
                }
            });
        });

        /*
         * キーボードのイベント
         */
        $(document).keypress(function(e) {

            e.preventDefault();

            // http://www.programming-magic.com/file/20080205232140/keycode_table.html

            switch (e.keyCode || e.which) {
                case 97:
                    // A
                    categories_prev();
                    break;

                case 115:
                    // S
                    categories_next();
                    break;

                case 111:
                    // O
                    $('#toggle_pinlist').click();
                    break;

                case 112:
                    // P
                    item_pin();
                    //item_next_focus();
                    break;

                case 114:
                    // R
                    categories_link(self.cat_idx_selected);
                    break;

                case 107:
                    // K
                    item_prev_focus();
                    break;

                case 106:
                    // J
                    item_next_focus();
                    break;

                case 118:
                    // V
                    item_view();
                    break;

                case 108:
                    // L
                    item_service('pocket');
                    break;
            }
        });
    };

}(Gion));
