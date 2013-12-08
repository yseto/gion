$(window).on('load', function() {
    jQuery.ajaxSetup({
        cache: false,
        error: function() {
            $('#myModal').modal('show');
        },
    });

    jQuery.ajax({
        type: 'POST',
        url: '/manage/get_numentry',
        datatype: 'json',
        success: function(b) {
            if (b.p == 1) {
                location.href = "/entries/";
            } else {
                refresh();
            }
        }
    });
});

function refresh() {
    jQuery.ajax({
        type: 'POST',
        url: '/inf/get_pinlist',
        datatype: 'json',
        async: false,
        success: function(a) {
            var count = 0;
            $('#pinlist_ul').empty();
            jQuery.each(a, function(a) {
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

}

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
