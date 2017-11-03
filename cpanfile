requires 'Config::ENV';
requires 'Cookie::Baker::XS';
requires 'Date::Parse';
requires 'DateTime';
requires 'DateTime::Format::ISO8601';
requires 'DateTime::Format::Mail';
requires 'DateTime::Format::W3CDTF';
requires 'DBD::mysql';
requires 'DBIx::Handler';
requires 'DBIx::Handler::Sunny';
requires 'Digest::HMAC_SHA1';
requires 'ExtUtils::MakeMaker', '>= 7.06';
requires 'FormValidator::Lite';
requires 'Furl';
requires 'HTML::Scrubber';
requires 'HTTP::Date';
requires 'HTTP::Parser::XS';
requires 'IO::Socket::SSL';
requires 'JSON::Types';
requires 'JSON::XS';
requires 'List::MoreUtils';
requires 'LWP::Protocol::https';
requires 'OAuth::Lite::Consumer';
requires 'OAuth::Lite::Token';
requires 'Plack';
requires 'Plack::Middleware::Session';
requires 'Proclet';
requires 'Router::Simple';
requires 'Starlet';
requires 'Text::Xslate';
requires 'Time::TZOffset';
requires 'Time::Zone';
requires 'Try::Tiny';
requires 'URI';
requires 'WWW::Form::UrlEncoded::XS';
requires 'XML::Atom';
requires 'XML::LibXML';
requires 'XML::RSS::LibXML';

on 'test' => sub {
    requires 'LWP::Protocol::PSGI';
    requires 'Test::More', '>= 0.96, < 2.0';
    requires 'Test::mysqld';
    requires 'Test::WWW::Mechanize::PSGI';
    requires 'Data::Section::Simple';
};
