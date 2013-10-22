$(window).on('load', function() {
    jQuery.ajaxSetup({
        cache: false,
        error: function() {
            $('#myModal').modal('show');
        }
    });

    jQuery.ajax({
        type: 'POST',
        url: '/manage/get_numentry',
        datatype: 'json',
        success: function(b) {
            $('#numentry').val(b.r);
            if (b.n == 0) {
                $('#noreferrer').attr('checked', false);
                $('#noreferrer').val(0);
            } else {
                $('#noreferrer').attr('checked', true);
                $('#noreferrer').val(1);
            }

            if (b.p == 0) {
                $('#nopinlist').attr('checked', false);
                $('#nopinlist').val(0);
            } else {
                $('#nopinlist').attr('checked', true);
                $('#nopinlist').val(1);
            }

        }
    });
    list();
});

$(document).on('click', '#change-categories', function() {
    jQuery.ajax({
        type: 'POST',
        url: '/manage/change_it',
        data: {
            'target': $('#target-id').val(),
            'cat': $('#selectCat').val(),
        },
        datatype: 'json',
        success: function(b) {
            $('#categoriesModal').modal('hide');
            list();
        }
    });
});

function list() {
    $('#cat_list').empty();
    jQuery.ajax({
        type: 'POST',
        url: '/api/get_targetlist',
        datatype: 'json',
        success: function(b) {
            $('#selectCat').empty();

            jQuery.each(b.n, function() {
                var li = $('<li>');
                li.append($('<span>').text(this.n + ' '));
                li.append($('<a>').attr({
                    href: '#',
                    id: 'c_' + this.i,
                    name: this.n,
                }).text('Delete').click(function() {
                    if (confirm($(this).attr('name') + ' を削除しますか')) {
                        jQuery.ajax({
                            type: 'POST',
                            url: '/manage/delete_it',
                            data: {
                                'target': $(this).attr('id'),
                            },
                            datatype: 'json',
                            success: function(b) {
                                list();
                            }
                        });
                    }
                }));

                var ul = $('<ul>').attr({
                    id: 'child_' + this.i
                });
                li.append(ul);

                $('#cat_list').append(li);

                $('#selectCat').append($('<option>').val(this.i).text(this.n));
            });

            jQuery.each(b.t, function() {
                var li = $('<li>');
                li.append($('<span>').text(this.n + ' '));
                li.append($('<a>').attr({
                    href: '#',
                    id: 'ne_' + this.i,
                    name: this.c,
                }).text('Change Cat.').click(function() {
                    $('#selectCat').val($(this).attr('name'));
                    $('#target-id').val($(this).attr('id'));
                    $('#categoriesModal').modal('show');
                }));
                li.append($('<span>').text(' '));
                li.append($('<a>').attr({
                    href: '#',
                    id: 'e_' + this.i,
                    name: this.n,
                }).text('Delete').click(function() {
                    if (confirm($(this).attr('name') + ' を削除しますか')) {
                        jQuery.ajax({
                            type: 'POST',
                            url: '/manage/delete_it',
                            data: {
                                'target': $(this).attr('id'),
                            },
                            datatype: 'json',
                            success: function(b) {
                                list();
                            }
                        });
                    }
                }));

                if (this.r == 404) {
                    li.append($('<span>').addClass('badge badge-inverse').text('404'));
                }
                if (this.r == -1) {
                    li.append($('<span>').addClass('badge badge-inverse').text('Fail?'));
                }

                li.append($('<span>').text(' '));

                li.append($('<a>').attr({
                    href: this.h,
                    target: 'blank'
                }).text('Open'));

                $('#child_' + this.c).append(li);
            });
        },
    });
}

$('#btn_numentry').click(function() {
    jQuery.ajax({
        type: 'POST',
        url: '/manage/set_numentry',
        datatype: 'json',
        data: {
            'val': $('#numentry').val(),
            'noref': $('#noreferrer').val(),
            'nopin': $('#nopinlist').val(),
        },
        success: function(b) {
            $('#txt_numentry').show();
        }
    });

});

$('#noreferrer').click(function() {
    if ($('#noreferrer').attr('checked') == 'checked') {
        $('#noreferrer').val(1);
    } else {
        $('#noreferrer').val(0);
    }
});

$('#nopinlist').click(function() {
    if ($('#nopinlist').attr('checked') == 'checked') {
        $('#nopinlist').val(1);
    } else {
        $('#nopinlist').val(0);
    }
});
