function list(){$("#selectCat").empty(),jQuery.ajax({type:"POST",url:"/inf/get_targetlist",datatype:"json",success:function(a){jQuery.each(a.n,function(){$("#selectCat").append($("<option>").val(this.i).text(this.n))})}})}function get_detail(){return null==$("#inputURL").val().match(/^http/g)?!1:($("#url-search").show(),void jQuery.ajax({type:"POST",url:"/manage/examine_target",data:{m:$("#inputURL").val()},datatype:"json"}).done(function(a){null==a?alert("Failure: Get information.\n please check url... :("):($("#inputRSS").val(a.u),$("#inputTitle").val(a.t))}).always(function(){$("#url-search").delay(400).fadeOut()}))}$("#get_detail").click(function(){get_detail()}),$("#cat_submit").click(function(){return 0==$("#inputCategoryName").val().length?!1:void jQuery.ajax({type:"POST",url:"/manage/register_categories",data:{name:$("#inputCategoryName").val()},datatype:"json",success:function(a){"ERROR_ALREADY_REGISTER"==a.r?alert("すでに登録されています。"):(list(),$("#return_cat").text("Thanks! add your request."))}})}),$("#submit").click(function(){$("#return").empty(),jQuery.ajax({type:"POST",url:"/manage/register_target",data:{url:$("#inputURL").val(),rss:$("#inputRSS").val(),title:$("#inputTitle").val(),cat:$("#selectCat option:selected").val()},datatype:"json",success:function(a){null==a?alert("Failure: Get information.\n please check url... :("):"ERROR_ALREADY_REGISTER"==a.r?alert("すでに登録されています。"):$("#return").text("Thanks! add your request.")}})}),$(window).on("load",function(){jQuery.ajaxSetup({cache:!1,error:function(){$("#myModal").modal("show")}}),list(),$("#url-search").hide()}),$("#inputURL").focusout(function(){get_detail()});var nav=$(".nav");nav.on("click",'a[href="#home"]',function(){location.href="/"}),nav.on("click",'a[href="#entries"]',function(){location.href="/entries/"}),nav.on("click",'a[href="#addasite"]',function(){location.href="/add/"}),nav.on("click",'a[href="#subscription"]',function(){location.href="/subscription/"}),nav.on("click",'a[href="#settings"]',function(){location.href="/settings/"}),nav.on("click",'a[href="#logout"]',function(){location.href="/?logout=1"}),$("#helpmodal").click(function(){$("#helpModal").modal("show")}),$("#returntop").click(function(){$("html,body").animate({scrollTop:0},"fast")});