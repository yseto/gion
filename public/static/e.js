var colour_s = '#339';
var colour = '#999';

var selection = 0;
var prev_selection = 0;

$(window).on('load', function() {
    jQuery.ajaxSetup({
        cache: false,
        error: function() {
            $('#myModal').modal('show');
        },
    });

    cat_list();
    $('.cat_link').removeClass('active');
    get_contents(0);
    $('.cat_link:first').addClass('active');
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
        $('.cat_link').removeClass('active');
        get_contents(q);
        if ( q == 0 ){
            $('.cat_link:first').addClass('active');
        }else{
            $('#cat_link_' + q).addClass('active');
        }
        selection = 0;
        moveselector();
    }
}

$(document).keypress(function(e) {

    e.preventDefault();

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
            //K
            item_prev_focus();
            break;

        case 106:
            //J
            item_next_focus();
            break;

        case 118:
            //V
            item_view();
            break;
    }
});

// PinList
$('#toggle_pinlist').click(function() {
    if ($('#pinlist').css("display") != "block") {

        jQuery.ajax({
            type: 'POST',
            url: '/pin/get_pinlist',
            datatype: 'json',
            async: false,
            success: function(a) {
                var count = 0;
                $('#pinlist_ul').empty();
                jQuery.each(a, function(a) {
                    $('#pinlist_ul').append($('<li>').append($('<a>').attr({
                        href: this.u
                    }).text(this.t)));
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
            url: '/pin/remove_all_pin',
            datatype: 'json',
            success: function() {
                cat_list();
                $('.cat_link').removeClass('active');
                get_contents(0);
                $('.cat_link:first').addClass('active');
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
        url: '/api/get_categories',
        datatype: 'json',
        /* cache: true, */
        async: false,
        success: function(b) {
            var link = [];
            var i = 0;
            var j = undefined;
            jQuery.each(b, function() {
                var li = $('<li>').addClass('cat_link').attr({
                    id: 'cat_link_' + this.i
                });
                li.append($('<a>').attr({
                    href: '/#' + this.i
                }).text(this.n).addClass('categories_link').append(' ').append($('<span>').addClass('badge').text(this.c)));
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
    $('#contents_view_box').prepend($('<p>').text('Please Wait...'));

    jQuery.ajax({
        type: 'POST',
        url: '/api/get_entries',
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
        div.addClass('tw');
        div.attr({
            id: this.g
        });

        var titleh4 = $('<h4>').addClass('viewpage').append($('<a>').attr({
            href: this.u,
            target: 'blank',
            rel: 'noreferrer',
        }).text(this.t).click(function() {
            window.open(this.href);
            return false;
        }).css('color', '#333'));

        if (this.r == 2) {
            titleh4.css('background-color', '#6cf');
        } else {}

        div.append(titleh4);

        div.append($('<p>').text(this.d));

        var pintarget = $('<p>').addClass('add pull-right').append($('<i>').addClass('icon-ok')).append(' Pin!');

        if (this.r == 2) {} else {
            pintarget.hide();
        }

        div.append($('<a>').addClass('pinlink btn btn-info hidden-desktop').text('Pin!'));
        div.append(pintarget);
        div.append($('<p>').text(this.p));

        $('#contents_view_box').append(div);
    });

    if (b.length == 0) {
        var div = $('<div>').addClass('tw');
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
        url: '/pin/set_pin',
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
    $($.browser.msie || $.browser.mozilla || $.browser.opera ? 'html' : 'body').animate({
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
