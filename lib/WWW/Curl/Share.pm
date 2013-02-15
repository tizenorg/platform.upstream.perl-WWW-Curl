package WWW::Curl::Share;

use strict;
use warnings;
use Carp;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);

use WWW::Curl;
require Exporter;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);

@EXPORT = qw(
CURLSHOPT_LAST
CURLSHOPT_LOCKFUNC
CURLSHOPT_NONE
CURLSHOPT_SHARE
CURLSHOPT_UNLOCKFUNC
CURLSHOPT_UNSHARE
CURLSHOPT_USERDATA
CURL_LOCK_DATA_CONNECT
CURL_LOCK_DATA_COOKIE
CURL_LOCK_DATA_DNS
CURL_LOCK_DATA_LAST
CURL_LOCK_DATA_NONE
CURL_LOCK_DATA_SHARE
CURL_LOCK_DATA_SSL_SESSION
);

sub AUTOLOAD {

    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    ( my $constname = $AUTOLOAD ) =~ s/.*:://;
    return constant( $constname, 0 );
}

1;
__END__


Copyright (C) 2008, Anton Fedorov (datacompboy <at> mail.ru)

You may opt to use, copy, modify, merge, publish, distribute and/or sell
copies of the Software, and permit persons to whom the Software is furnished
to do so, under the terms of the MPL or the MIT/X-derivate licenses. You may
pick one of these licenses.
