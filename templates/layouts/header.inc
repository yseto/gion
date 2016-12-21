<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Gion</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, minimal-ui">
    <meta name="author" content="Gion">
    <meta name="referrer" content="no-referrer">
    <script src="//ajax.aspnetcdn.com/ajax/jQuery/jquery-2.0.3.min.js"></script>

    <!-- Le styles -->
    <style type="text/css">
      body {
        padding-top: 60px;
        padding-bottom: 40px;
        overflow-y:scroll;
      }
      .tw {
        margin:0 0 5px !important;
        padding:0 10px;
      }
      .list-group .category_link, #pinlist_ul .list-group-item {
        padding:4px 10px;
      }
    </style>
    <link href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css" rel="stylesheet">

    <!-- Le HTML5 shim, for IE6-8 support of HTML5 elements -->
    <!--[if lt IE 9]>
      <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]-->

  </head>

  <body>
  <div class="navbar navbar-default navbar-fixed-top" role="navigation">
    <div class="container">
      <div class="navbar-header">
        <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
          <span class="sr-only">Toggle navigation</span>
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
        </button>
	    <span class="navbar-brand">Gion</span>
      </div>
      <div class="navbar-collapse collapse">
        <ul class="nav navbar-nav">
          <li [% IF r.req.path == "/" %]class="active" [% END %]><a href="/"><span class="glyphicon glyphicon-home"></span> Home</a></li>
          <li [% IF r.req.path == "/entry/" %]class="active" [% END %]><a href="/entry/"><span class="glyphicon glyphicon-inbox"></span> Read</a></li>
          <li [% IF r.req.path == "/add/" %]class="active" [% END %]><a href="/add/"><span class="glyphicon glyphicon-plus-sign"></span> Add a Site</a></li>
          <li [% IF r.req.path == "/subscription/" %]class="active" [% END %]><a href="/subscription/"><span class="glyphicon glyphicon-list"></span> Subscription</a></li>
        </ul>
        <ul class="nav navbar-nav navbar-right">
          <li [% IF r.req.path == "/settings/" %]class="active" [% END %]><a href="/settings/"><span class="glyphicon glyphicon-wrench"></span> Settings</a></li>
          <li class="hidden-sm"><a style="cursor:pointer;" id="helpmodal"><i class="glyphicon glyphicon-question-sign"></i> Help</a></li>
          <li><a href="/logout"><span class="glyphicon glyphicon-off"></span> Logout</a></li>
        </ul>
      </div><!--/.navbar-collapse -->
    </div>
  </div>

