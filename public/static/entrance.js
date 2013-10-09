$(window).on('load', function() {
    jQuery.ajaxSetup({
        cache: false,
        error: function() {
            $('#myModal').modal('show');
        },
    });
    refresh();
});

function refresh() {
    jQuery.ajax({
        type: 'POST',
        url: '/pin/get_pinlist',
        datatype: 'json',
        async: false,
        success: function(a) {
            var count = 0;
            $('#pinlist_ul').empty();
            jQuery.each(a, function(a) {
                var li = $('<a>').attr({
                    id: this.g
                }).addClass('read icon-check').text('');
                li.css('cursor', 'pointer');
                var lic = $('<span>').text(' ')
                    .append($('<span>').text(this.m))
                    .append($('<span>').text(' '))
                    .append($('<a>').attr({
                    href: this.u,
                    target: 'blank',
                }).text(this.t));
                $('#pinlist_ul').append($('<li>').append(li).append(lic));
                count++;
            });
            $('#pincount').text(count);
        },
    });

}

$(document).on('click', '.read', function() {
    jQuery.ajax({
        type: 'POST',
        url: '/pin/set_pin',
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
