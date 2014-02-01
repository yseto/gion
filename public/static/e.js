var colour_s = '#339';
var colour = '#999';

var selection = 0;
var prev_selection = 0;

var service_state = {};

$(window).on('load', function() {
    jQuery.ajaxSetup({
        cache: false,
        error: function() {
            $('#myModal').modal('show');
        },
    });

    service_state = {};
    jQuery.ajax({
        type: 'POST',
        url: '/manage/get_connect',
        datatype: 'json',
        success: function(a) {
            if (a.e == null) { return false; }
            jQuery.each(a.e, function() {
                service_state[this.service] = 1;
            });
        },
        error: function() {},
    });

    cat_list();
    $('.categories_link').removeClass('active');
    get_contents(0);
    $('.categories_link:first').addClass('active');
    $('#pinlist').hide();
    moveselector();
});

$('#cat_list').on('click', '.categories_link', function(e) {
    categories_link($(this).attr('href'));
    e.preventDefault();
});

function categories_link(q) {
    q = q.replace('/#', '');
    if (jQuery.isNumeric(q)) {
        cat_idx_selected = q;
        cat_list(q);
        $('.categories_link').removeClass('active');
        get_contents(q);
        if (q == 0) {
            $('.categories_link:first').addClass('active');
        } else {
            $('#categories_link_' + q).addClass('active');
        }
        selection = 0;
        moveselector();
    }
}

$(document).keypress(function(e) {

    e.preventDefault();

    // http://www.programming-magic.com/file/20080205232140/keycode_table.html

    switch (e.keyCode) {
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
            categories_link(cat_idx_selected);
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

// PinList
$('#toggle_pinlist').click(function() {
    if ($('#pinlist').css("display") != "block") {

        jQuery.ajax({
            type: 'POST',
            url: '/inf/get_pinlist',
            datatype: 'json',
            async: false,
            success: function(a) {
                var count = 0;
                $('#pinlist_ul').empty();
                jQuery.each(a, function(a) {
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

// Remove All Pin

$('#remove_all_pin').click(function() {
    if (confirm('Are you sure?')) {
        jQuery.ajax({
            type: 'POST',
            url: '/inf/remove_all_pin',
            datatype: 'json',
            success: function() {
                cat_list();
                $('.categories_link').removeClass('active');
                get_contents(0);
                $('.categories_link:first').addClass('active');
                selection = 0;
                moveselector();
            },
        });
    }
});

//CreateCategories List 

var cat_idx_prev = '';
var cat_idx_next = '';
var cat_idx_selected = '0';

function cat_list(q) {
    $('#cat_list').empty();
    jQuery.ajax({
        type: 'POST',
        url: '/inf/get_categories',
        datatype: 'json',
        /* cache: true, */
        async: false,
        success: function(b) {
            var link = [];
            var i = 0;
            var j = undefined;
            jQuery.each(b, function() {
                var li = $('<a>').addClass('categories_link list-group-item').attr({
                    id: 'categories_link_' + this.i,
                    href: '/#' + this.i
                }).text(this.n).append($('<span>').addClass('badge hidden-sm').text(this.c));
                $('#cat_list').append(li);
                link[i] = '/#' + this.i;
                i++;
                if (q == this.i) {
                    j = i;
                }
            });
            var tmp;
            if (j === undefined) { /* First Access:Pointer Top*/
                tmp = i - 1;
                cat_idx_prev = link[tmp];
                if (i == 1) { /* item count is one ? */
                    cat_idx_next = link[0]; /* yes! */
                } else {
                    cat_idx_next = link[1]; /* no!! there is next item */
                }
            } else { /* Not First Access : Pointer Variable */
                tmp = j - 2; /* j = i ... After i is increment*/
                if (link[tmp] === undefined) { /* undefined maybe pointer head */
                    tmp = i - 1; /* pointer set tail */
                    cat_idx_prev = link[tmp];
                } else {
                    cat_idx_prev = link[tmp];
                }

                tmp = j + 0; /* j = i ... After i is increment*/
                if (link[tmp] === undefined) { /* undefined maybe pointer tail */
                    cat_idx_next = link[0]; /* pointer set head */
                } else {
                    cat_idx_next = link[tmp];
                }
            }
        },
    });
}

// Get Contents From Server

function get_contents(id) {
    $('#contents_view_box').prepend($('<p>').text('Please Wait...').addClass('alert alert-info'));

    jQuery.ajax({
        type: 'POST',
        url: '/inf/get_entries',
        data: {
            'cat': id
        },
        datatype: 'json',
        success: function(b) {
            entries(b);
            moveselector();
        },
    });
}

//Put Contents To Contents_View_Box ( RIGHT SIDE )

function entries(b) {

    $('#contents_view_box').empty();

    jQuery.each(b, function() {

        var div = $('<div>');
        div.addClass('tw panel panel-default');
        div.attr({
            id: this.g
        });

        var texttitle = '[nothing title...]';
        if (this.t.length > 0){ texttitle = this.t; }
        var titleh4 = $('<h4>').addClass('viewpage').append($('<a>').attr({
            href: this.u,
            target: 'blank',
            rel: 'noreferrer',
        }).text(texttitle).click(function() {
            window.open(this.href);
            return false;
        }).css('color', '#333'));

        if (this.r == 2) {
            titleh4.css('background-color', '#6cf');
        } else {}

        div.append(titleh4);

        div.append($('<p>').text(this.d));

        var pintarget = $('<p>').addClass('add pull-right').append($('<span>').addClass('glyphicon glyphicon-ok')).append(' Pin!');

        if (this.r != 2) {
            pintarget.hide();
        }

        div.append($('<a>').addClass('pinlink hidden-md hidden-lg btn btn-info btn-sm').text('Pin!'));

        var btn = $('<div>').addClass('text-right').prepend($('<br>').addClass('hidden-md hidden-lg'));
        var service_link = this.s;
        $.each(service_state, function(i) {
            btn.append($('<span>').css('margin-left','1em'));
            btn.append($('<button>').addClass('service btn btn-danger btn-sm').text(i).data('service', i).data('url', service_link));
        });

        div.append(btn);
        div.append(pintarget);
        div.append($('<p>').text(this.p));

        $('#contents_view_box').append(div);
    });

    if (b.length == 0) {
        var div = $('<div>').addClass('tw panel panel-default');
        div.append($('<h3>').text('Nothing Entries.'));
        $('#contents_view_box').append(div);
    }
}

$(document).on('click', '.pinlink', function() {
    var it = $(this).closest('div');
    it.children('.add').toggle();
    post_pin(it);
});

function item_pin() {
    var it = $('.tw:eq(' + selection + ')');
    it.children('.add').toggle();
    post_pin(it);
}

function post_pin(id) {
    jQuery.ajax({
        type: 'POST',
        url: '/inf/set_pin',
        data: {
            'flag': is_toggle_pin(id),
            'pinid': encodeURI(id.attr('id'))
        },
        datatype: 'text',
        success: function(a) {},
    });
}


function item_view() {
    $('.tw:eq(' + selection + ') > .viewpage > a').click();
}

function item_prev_focus() {
    prev_selection = selection; //色換えのため
    selection--;

    //範囲を超えた場合
    if (selection < 0) {
        selection = 0;
    }

    moveselector();
}

function item_next_focus() {

    //最終端を指定している場合、次はないので抑制
    if (selection == $('.tw').length - 1) {
        selection--;
    }

    prev_selection = selection; //色換えのため
    selection++;

    //範囲を超えた場合
    if ($('.tw').length - 1 < selection) {
        selection = $('.tw').length - 1;
    }

    moveselector();
}

//フォーカス移動

function moveselector() {
    var topoffset = -80;
    var selector = '.tw:eq(' + selection + ')';

    //移動を許されている範囲を逸脱している場合、return
    if (!(selection >= 0 && $('.tw').length > selection)) {
        selection = 0;
        return;
    }

    //色換え
    $(selector).css("border-color", colour_s);
    if (prev_selection != selection) {
        $('.tw:eq(' + prev_selection + ')').css("border-color", colour);
    }

    //移動
    $($.browser.msie || $.browser.mozilla || ($.browser.opera && !$.browser.webkit) ? 'html' : 'body').animate({
        scrollTop: $(selector).offset().top + topoffset,
    }, 0);
}

function is_toggle_pin(id) {
    var titleh4 = id.children('h4');
    if (id.children('.add').css("display") == "block") {
        titleh4.css('background-color', '#6cf');
        return 1;
    }
    titleh4.css('background-color', 'inherit');
    return 0;
}

function categories_next() {
    if (cat_idx_next != undefined) {
        categories_link(cat_idx_next);
    }
}

function categories_prev() {
    if (cat_idx_prev != undefined) {
        categories_link(cat_idx_prev);
    }
}

function item_service(service_name) {
    var it = $('.tw:eq(' + selection + ') * ');
    var scope = it.children('.service');
    for (var i = 0 ; i < scope.length; i++ ){
        if ( scope.eq(i).text() == service_name ) {
            scope.eq(i).click();
        }
    }
}

$(document).on('click', '.service', function() {
    var r = $(this);
    jQuery.ajax({
        type: 'POST',
        url: '/api/' + $(this).data('service') + '/post',
        datatype: 'json',
        data: {
            'service': $(this).data('service'),
            'url': $(this).data('url'),
        },
        success: function(a) {
            if (a.e == 'ok') {
                r.text('posted').attr('disabled', 'disabled');
            }
        },
    });
});
