package WWW::Curl;

use strict;
use warnings;
use vars qw(@ISA $VERSION);
use DynaLoader;

BEGIN {
    $VERSION = '4.05';
    @ISA     = qw(DynaLoader);
    __PACKAGE__->bootstrap;
}

1;

__END__

=head1 NAME

WWW::Curl - Perl extension interface for libcurl

=head1 SYNOPSIS

    use WWW::Curl;
    print $WWW::Curl::VERSION;


=head1 DESCRIPTION

WWW::Curl is a Perl extension interface for libcurl.

=head1 DOCUMENTATION

This module provides a Perl interface to libcurl. It is not intended to be a standalone module
and because of this, the main libcurl documentation should be consulted for API details at
L<http://curl.haxx.se>. The documentation you're reading right now only contains the Perl specific
details, some sample code and the differences between the C API and the Perl one.

=head1 WWW::Curl::Easy

The name might be confusing, it originates from libcurl. This is not an ::Easy module
in the sense normally used on CPAN.

Here is a small snippet of making a request with WWW::Curl::Easy.

	use strict;
	use warnings;
	use WWW::Curl::Easy;

	# Setting the options
	my $curl = new WWW::Curl::Easy;
	
	$curl->setopt(CURLOPT_HEADER,1);
	$curl->setopt(CURLOPT_URL, 'http://example.com');
	my $response_body;

	# NOTE - do not use a typeglob here. A reference to a typeglob is okay though.
	open (my $fileb, ">", \$response_body);
	$curl->setopt(CURLOPT_WRITEDATA,$fileb);

	# Starts the actual request
	my $retcode = $curl->perform;

	# Looking at the results...
	if ($retcode == 0) {
		print("Transfer went ok\n");
		my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
		# judge result and next action based on $response_code
		print("Received response: $response_body\n");
	} else {
		print("An error happened: ".$curl->strerror($retcode)." ($retcode)\n");
	}


=head1 WWW::Curl::Multi

	use strict;
	use warnings;
	use WWW::Curl::Easy;
	use WWW::Curl::Multi;

	my %easy;
	my $curl = WWW::Curl::Easy->new;
	my $curl_id = '13'; # This should be a handle unique id.
	$easy{$curl_id} = $curl;
	my $active_handles = 0;

	$curl->setopt(CURLOPT_PRIVATE,$curl_id);
	# do the usual configuration on the handle
	...

	my $curlm = WWW::Curl::Multi->new;
	
	# Add some easy handles
	$curlm->add_handle($curl);
	$active_handles++;

	while ($active_handles) {
		my $active_transfers = $curlm->perform;
		if ($active_transfers != $active_handles) {
			while (my ($id,$return_value) = $curlm->info_read) {
				if ($id) {
					$active_handles--;
					my $actual_easy_handle = $easy{$id};
					# do the usual result/error checking routine here
					...
					# letting the curl handle get garbage collected, or we leak memory.
					delete $easy{$id};
				}
			}
		}
	}

This interface is different than what the C API does. $curlm->perform is non-blocking and performs
requests in parallel. The method does a little work and then returns control, therefor it has to be called
periodically to get the job done. It's return value is the number of unfinished requests.

When the number of unfinished requests changes compared to the number of active handles, $curlm->info_read
should be checked for finished requests. It returns one handle and it's return value at a time, or an empty list
if there are no more finished requests. $curlm->info_read calls remove_handle on the given easy handle automatically,
internally. The easy handle will still remain available until it goes out of scope, this action just detaches it from
multi.

Please make sure that the easy handle does not get garbage collected until after the multi handle finishes processing it,
or bad things happen.

The multi handle does not need to be cleaned up, when it goes out of scope it calls the required cleanup methods
automatically.

It is possible to use $curlm->add_handle to add further requests to be processed after $curlm->perform has been called.
WWW::Curl::Multi doesn't care about the order. It is possible to process all requests for a multi handle and then add
a new batch of easy handles for processing.

=head1 WWW::Curl::Share

	use WWW::CURL::Share;
	my $curlsh = new WWW::Curl::Share;
	$curlsh->setopt(CURLSHOPT_SHARE, CURL_LOCK_DATA_COOKIE);
	$curlsh->setopt(CURLSHOPT_SHARE, CURL_LOCK_DATA_DNS);
	$curl->setopt(CURLOPT_SHARE, $curlsh);
	$curlsh->setopt(CURLSHOPT_UNSHARE, CURL_LOCK_DATA_COOKIE);
	$curlsh->setopt(CURLSHOPT_UNSHARE, CURL_LOCK_DATA_DNS);

WWW::Curl::Share is an extension to WWW::Curl::Easy which makes it possible
to use a single cookies/dns cache for several Easy handles.

It's usable methods are:
	
	$curlsh = new WWW::Curl::Share
		This method constructs a new WWW::Curl::Share object.

	$curlsh->setopt(CURLSHOPT_SHARE, $value );
		Enables share for:
			CURL_LOCK_DATA_COOKIE	use single cookies database
			CURL_LOCK_DATA_DNS	use single DNS cache
	$curlsh->setopt(CURLSHOPT_UNSHARE, $value );
		Disable share for given $value (see CURLSHOPT_SHARE)

	$curlsh->strerror( ErrNo )
		This method returns a string describing the CURLSHcode error 
		code passed in the argument errornum.

This is how you enable sharing for a specific WWW::Curl::Easy handle:

	$curl->setopt(CURLOPT_SHARE, $curlsh)
		Attach share object to WWW::Curl::Easy instance


=head1 COMPATIBILITY

=over

=item curl_easy_setopt

Most of the options should work, however some might not. Please send reports, tests and patches to fix
those. 

=item curl_easy_escape

Not implemented. Since equivalent Perl code is easily produced, this method will only made
available for interface completeness, if ever.

=item curl_easy_init

Used only internally. The standard Perl way of initializing an object should be used,
 C<< my $curl = WWW::Curl::Easy->new; >>.

=item curl_easy_cleanup

Used only internally. Curl object cleanup happens when the handle goes out of scope.

=item curl_easy_duphandle

Should be working for most cases, however do not change the value of options which accept
a list/arrayref value on a duped handle, otherwise memory leaks or crashes will happen.
This behaviour will be fixed in the future.

=item curl_easy_pause

Not implemented.

=item curl_easy_reset

Not implemented.

=item curl_easy_unescape

Not implemented. Trivial Perl replacements are available.

=item curl_escape

Not implemented and won't be as this method is considered deprecated.

=item curl_formadd

Not yet implemented.

=item curl_formfree

When WWW::Curl::Form support is added, this function will be used internally,
but won't be accessible from the public API.

=item curl_free

Used internally. Not exposed through the public API, as this call has no relevance
to Perl code.

=item curl_getdate

Not implemented. This function is easily replaced by Perl code and as such, most likely
it won't be implemented.

=item curl_global_cleanup

Only used internally, not exposed through the public API.

=item curl_global_init

Only used internally, not exposed through the public API.

=item curl_global_init_mem

Not implemented.

=item curl_slist_append

Only used internally, not exposed through the public API.

=item curl_slist_free_all

Only used internally, not exposed through the public API.

=item curl_unescape

Not implemented and won't be, as this method is considered deprecated.

=item curl_version_info

Not yet implemented.

=item curl_multi_*

Most methods are either not exposed through the WWW::Curl::Multi API or they behave differently
than it's C counterpart. Please see the section about WWW::Curl::Multi above.

=back

=head1 USAGE CASES

The standard Perl WWW module, LWP should be used in most cases to work with
the HTTP or FTP protocol from Perl. However, there are some cases where LWP doesn't
perform well. One is speed and the other is paralellism. WWW::Curl is much faster,
uses much less CPU cycles and it's capable of non-blocking parallel requests.

In some cases, for example when building a web crawler, cpu usage and parallel downloads are
important considerations. It can be desirable to use WWW::Curl to do the heavy-lifting of
a large number of downloads and wrap the resulting data into a Perl-friendly structure by
HTTP::Response.

=head1 CHANGES

Version 4.01 adds several bugfixes. See Changes file.

Version 4.00 added new documentation, the build system changed to Module::Install,
the test suite was rewritten to use Test::More, a new calling syntax for WWW::Curl::Multi
was added, memory leak and other bugfixes added, Perl 5.6 and libcurl 7.10.8 as minimum
requirements for this module were set.

Version 3.12 is a bugfix for a missing Share.pm.in file in the release.

Version 3.11 added WWW::Curl::Share.

Version 3.10 adds the WWW::Curl::Share interface by Anton Federov
and large file options after a contribution from Mark Hindley.

Version 3.02 adds some backwards compatibility for scripts still using
'WWW::Curl::easy' names.

Version 3.01 added some support for pre-multi versions of libcurl.

Version 3.00 adds WWW::Curl::Multi interface, and a new module names
following perl conventions (WWW::Curl::Easy rather than WWW::Curl::easy),
by Sebastian Riedel <sri at cpan.org>.

Version 2.00 of WWW::Curl::easy is a renaming of the previous version
(named Curl::easy), to follow CPAN naming guidelines, by Cris Bailiff.

Versions 1.30, a (hopefully) threadable, object-oriented,
multiple-callback compatible version of Curl::easy was substantially
reworked from the previous Curl::easy release (1.21) by Cris Bailiff.

=head1 AUTHORS

Currently maintained by Cris Bailiff <c.bailiff+curl at devsecure.com>

Original Author Georg Horn <horn@koblenz-net.de>, with additional callback,
pod and test work by Cris Bailiff <c.bailiff+curl@devsecure.com> and
Forrest Cahoon <forrest.cahoon@merrillcorp.com>. Sebastian Riedel added ::Multi
and Anton Fedorov (datacompboy <at> mail.ru) added ::Share. Balint Szilakszi
repackaged the module into a more modern form.

=head1 COPYRIGHT

Copyright (C) 2000-2005,2008 Daniel Stenberg, Cris Bailiff,
Sebastian Riedel, Balint Szilakszi et al.

You may opt to use, copy, modify, merge, publish, distribute and/or sell
copies of the Software, and permit persons to whom the Software is furnished
to do so, under the terms of the MPL or the MIT/X-derivate licenses. You may
pick one of these licenses.

=head1 SEE ALSO

http://curl.haxx.se
