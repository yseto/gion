$('#get_detail').click(function() {
    get_detail();
});


$('#cat_submit').click(function() {
    if ($('#inputCategoryName').val().length == 0) return false;
    jQuery.ajax({
        type: 'POST',
        url: '/manage/register_categories',
        data: {
            'name': $('#inputCategoryName').val(),
        },
        datatype: 'json',
        success: function(j) {
            if (j.r == "ERROR_ALREADY_REGISTER") {
                alert("すでに登録されています。");
            } else {
                list();
                $('#return_cat').text('Thanks! add your request.');
            }
        },
    });
});

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
            if (j == null) {
                alert('Failure: Get information.\n please check url... :(');
            } else {
                if (j.r == "ERROR_ALREADY_REGISTER") {
                    alert("すでに登録されています。");
                } else {
                    $('#return').text('Thanks! add your request.');
                }
            }
        },
    });
});

$(window).on('load', function() {
    jQuery.ajaxSetup({
        cache: false,
        error: function() {
            $('#myModal').modal('show');
        }
    });
    list();
    $('#url-search').hide();
});

function list() {

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
}

$('#inputURL').focusout(function() {
    get_detail();
});

function get_detail() {
    if ($('#inputURL').val().match(/^http/g) == null) return false;
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
        if (j == null) {
            alert('Failure: Get information.\n please check url... :(');
        } else {
            $('#inputRSS').val(j.u);
            $('#inputTitle').val(j.t);
        }
    })
        .always(function() {
        $('#url-search').delay(400).fadeOut();
    });
}
