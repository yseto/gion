$(window).on('load', function() {
    jQuery.ajaxSetup({
        cache: false,
        error: function() {
            $('#myModal').modal('show');
        }
    });
    list();
});

$(document).on('click', '#change-categories', function() {
    jQuery.ajax({
        type: 'POST',
        url: '/manage/change_it',
        data: {
            'id': $('#target-id').val(),
            'cat': $('#selectCat').val(),
        },
        datatype: 'json',
        success: function(b) {
            $('#categoriesModal').modal('hide');
            list();
        }
    });
});


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
            success: function(b) {
                list();
            }
        });
    }
});


$(document).on('click', '.categorybtn', function() {

    $('#selectCat').val($(this).data('name'));
    $('#target-id').val($(this).data('id'));
    $('#categoriesModal').modal('show');
});




function list() {
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

                var linkage = $('<a>').addClass('btn btn-link btn-xs').attr({
                    href: this.h,
                    target: 'blank'
                }).text(this.n);

                if (this.r == -1 || this.r == 404) {
                    linkage.append($('<span>').addClass('badge ').text('取得に失敗しました'));
                    tr.addClass('danger');
                }
                tr.append($('<td>').append(linkage));

                $('#child_' + this.c).after(tr);
            });
        },
    });
}
