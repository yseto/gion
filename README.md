Gion
=================

A RSS Reader for Web Browser ( PC, Tablet, Mobile )

Feature
----------
- Simple User Interface
- Categorization
- Keyboard Shortcut Support (do not run firefox....)
- Redirector Support (eg. www.google.com/url?sa=D&q=xxxx )
- Multi User ( Authentication Support )
- To post Pocket (formerly Read it later)

Requirement
----------
- Perl
- mysql (of course MariaDB ok) or SQLite

On Heroku
----------

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

- for login type admin / password
- please change password on setting page.

please add the [Scheduler Add-on](https://devcenter.heroku.com/articles/scheduler)

Frequency: hourly 

    $ ./wakeup.pl -u http://yourapp.herokuapp.com/

