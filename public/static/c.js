var nav = $('.nav');
nav.on('click', 'a[href="#home"]', function() {
    location.href = "/";
});
nav.on('click', 'a[href="#addasite"]', function() {
    location.href = "/add/";
});
nav.on('click', 'a[href="#subscription"]', function() {
    location.href = "/subscription/";
});
nav.on('click', 'a[href="#logout"]', function() {
    location.href = "/?logout=1";
});

$('#helpmodal').click(function() {
    $('#helpModal').modal('show');
});

$('#returntop').click(function() {
    $('html,body').animate({ scrollTop: 0 }, 'fast');
});
