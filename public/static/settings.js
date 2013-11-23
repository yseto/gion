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
    $('#txt_numentry').hide();

    $('.disconnect').hide();

    jQuery.ajax({
        type: 'POST',
        url: '/manage/get_connect',
        datatype: 'json',
        success: function(a) {
            jQuery.each(a.e, function() {
                $('#connect' + this.service).text('連携しています。ユーザ名: ' + this.username);
                $('#btn' + this.service).attr('disabled', 'disabled');
                $('#' + this.service).show();
            });
        },
        error: function() {},
    });
});

$('.disconnect').click(function() {
    jQuery.ajax({
        type: 'POST',
        url: '/manage/set_connect',
        datatype: 'json',
        data: {
            'service': $(this).attr('id'),
        },
        success: function() {
            location.reload();
        }
    });
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
        },
        success: function(b) {
            $('#txt_numentry').show();
        }
    });

});

$('.noreferrer').click(function() {
    if ($('#noreferrer').prop('checked') == true) {
        $('#noreferrer').val(1);
    } else {
        $('#noreferrer').val(0);
    }
});

$('.nopinlist').click(function() {
    if ($('#nopinlist').prop('checked') == true) {
        $('#nopinlist').val(1);
    } else {
        $('#nopinlist').val(0);
    }
});
