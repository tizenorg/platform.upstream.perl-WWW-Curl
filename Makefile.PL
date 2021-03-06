# Makefile.PL for Perl module WWW::Curl
# Check out the README file for more information.

use inc::Module::Install;

name			'WWW-Curl';
abstract		'Perl extension interface for libcurl';
author			'Cris Bailiff <c.bailiff+curl at devsecure.com>';
license			'MPL or MIT/X-derivate';
perl_version		'5.006001';
no_index		directory => 'template';
# This is a hack. If you have libcurl installed, just specify curl.h below
# and comment out this line.
if ($^O ne 'MSWin32') {
	requires_external_bin	'curl-config';
} else {
	print	"Sorry, no automated install is available on Windows,\n".
		"please see the README.Win32 file on instructions for a manual install.\n";
	exit(0);
}

my @includes = qw();
my ($cflags,$lflags, $ldflags) = ('','','');

# This utility helper generates the constants function from curl.h
# It is normally only used by the maintainer, but if you're curl is older
# or missing some constants, you can delete curlopt-constants.c and re-run 'perl Makefile.PL'
# You may need to specify where to find curl.h on your platform
# These are guesses only, in case curl-config is not telling us.

if ($^O ne 'MSWin32') {
	push @includes, qw(
		/usr/include
		/usr/local/curl/include
		/usr/local/include/curl
		../../include
		../curl/include
	);
}
#
# Get curl to tell us where it is, if we can.
#


if ($^O ne 'MSWin32') {
	$cflags = `curl-config --cflags`;
	$lflags = `curl-config --libs`;
}

# can't find link flags, make some guesses
if (!defined($lflags)) {
    $lflags="-lcurl";
    print "Guessing your linker flags as: $lflags\n";
}

my ($flag) = ($cflags =~ m/-I(\S+)/);

if (defined $flag) {
    unshift @includes, $flag;    # first guess
}

# try the path given on the command line, if any
if (defined($ARGV[0])) {
    unshift @includes, $ARGV[0];
};

my $curl_d = "";
my $curl_h;

# otherwise try a list of common locations
foreach my $try (@includes) {
    if (-f $try . "/curl/curl.h") {
        $curl_d = $try;
        $curl_h = $try . "/curl/curl.h";
        last;
    }
}

if (!defined($curl_h)) {
    die "Cannot find curl.h - cannot build constants files  - see Makefile.PL";
} else {
    $curl_d = "-I" . $curl_d;
    print "Found curl.h in $curl_h\n";
    open(CURL_H, "<" . $curl_h) or die "Can't open curl.h\n";
    my %cinit_types;
    my %cinit_codes;
    my @curlinfo;
    my @curlshopt;
    my @curllockopt;
    while (<CURL_H>) {
        if ($_ =~ m/CINIT\(/ and $_ !~ m/#/) {
            my ($option, $type, $code) =
                m/.*CINIT\((\w*)\s*,\s*(\w+)\s*,\s*(\d+).*/;
            $cinit_types{$option} = $option;
            $cinit_codes{$option} = $code;
	} elsif ($_ =~ m/^#define CURLOPT_\w+ CURLOPT_\w+/) {
            my ($option, $value) =
                m/^#define CURLOPT_(\w+) CURLOPT_(\w+)/;
            $cinit_types{$option} = $value;
        } elsif ($_ =~ m/^\s*(CURLINFO_\w+)/) {
            push @curlinfo, $1;
        } elsif ($_ =~ m/^\s*(CURLSHOPT_\w+)/) {
            push @curlshopt, $1;
        } elsif ($_ =~ m/^\s*(CURL_LOCK_DATA_\w+)/) {
            push @curllockopt, $1;
        }

    }
    close(CURL_H);

    # some things are ifdefed out...
    foreach my $ifdef0 (qw(FLAGS PROGRESSMODE MOREDOCS)) {
        delete $cinit_types{$ifdef0};
        delete $cinit_codes{$ifdef0};
    }

    print "Building curlopt-constants.c for your libcurl version\n";

    open(CURL_XS, ">curlopt-constants.c")
        or die "Can't write curlopt-constants.c\n";

    # boilerplate xs constant function here
    print CURL_XS <<HERE
static int
constant(char *name, int arg)
{
    errno = 0;
    if (strncmp(name, "CURLINFO_", 9) == 0) {
        name += 9;
    switch (*name) {
HERE
        ;
    foreach my $next_initial ('A' .. 'Z') {
        print CURL_XS "        case '$next_initial':\n";
        my $count = 0;
        foreach my $curlinfo_name (sort @curlinfo) {
            my $initial = substr($curlinfo_name, 9, 1);
            my $option = substr($curlinfo_name, 9);
            if ($next_initial eq $initial) {

                print CURL_XS
"            if (strEQ(name, \"$option\")) return CURLINFO_$option;\n";

                $count++;
            }
        }
        if ($count or $next_initial eq 'Z') {
            print CURL_XS "            break;\n";
        }
    }

    print CURL_XS "    };\n";
    print CURL_XS "    }\n";

	# CURLOPT_
	print CURL_XS <<HERE2

    if (strncmp(name, "CURLOPT_", 8) == 0) {
        name += 8;
        switch (*name) {
HERE2
        ;

    foreach my $next_initial ('A' .. 'Z') {
        print CURL_XS "        case '$next_initial':\n";
        my $count = 0;
        foreach my $option (sort keys %cinit_types) {
            my $initial = substr($option, 0, 1);
            if ($next_initial eq $initial) {

                print CURL_XS
"            if (strEQ(name, \"$option\")) return CURLOPT_$cinit_types{$option};\n";

                $count++;
            }
        }
        if ($count or $next_initial eq 'Z') {
            print CURL_XS "            break;\n";
        }
    }

    print CURL_XS "    };\n";
    print CURL_XS "    }\n";

	# CURLSHOPT_
	print CURL_XS <<HERE2

    if (strncmp(name, "CURLSHOPT_", 10) == 0) {
        name += 10;
        switch (*name) {
HERE2
        ;

    foreach my $next_initial ('A' .. 'Z') {
        print CURL_XS "        case '$next_initial':\n";
        my $count = 0;
        foreach my $option (sort @curlshopt) {
            my $initial = substr($option, 10, 1);
            if ($next_initial eq $initial) {
				my $optsuff = substr($option, 10);
                print CURL_XS
"            if (strEQ(name, \"$optsuff\")) return $option;\n";
				
                $count++;
            }
        }
        if ($count or $next_initial eq 'Z') {
            print CURL_XS "            break;\n";
        }
    }

    print CURL_XS "    };\n";
    print CURL_XS "    }\n";

	# CURL_LOCK_DATA_
	print CURL_XS <<HERE2
    if (strncmp(name, "CURL_LOCK_DATA_", 15) == 0) {
        name += 15;
        switch (*name) {
HERE2
        ;

    foreach my $next_initial ('A' .. 'Z') {
        print CURL_XS "        case '$next_initial':\n";
        my $count = 0;
        foreach my $option (sort @curllockopt) {
            my $initial = substr($option, 15, 1);
            if ($next_initial eq $initial) {
				my $optsuff = substr($option, 15);
                print CURL_XS
"            if (strEQ(name, \"$optsuff\")) return $option;\n";
				
                $count++;
            }
        }
        if ($count or $next_initial eq 'Z') {
            print CURL_XS "            break;\n";
        }
    }

    print CURL_XS "    };\n";
    print CURL_XS "    }\n";

    print CURL_XS <<HERE

    errno = EINVAL;
    return 0;
}
HERE
        ;

    close(CURL_XS);

    print "Building Easy.pm constants for your libcurl version\n";

    open(EASY_PM,    ">lib/WWW/Curl/Easy.pm")    or die "Can't create lib/WWW/Curl/Easy.pm\n";
    open(EASY_PM_IN, "template/Easy.pm.tmpl") or die "Can't read template/Easy.pm.tmpl\n";
    while (my $line = <EASY_PM_IN>) {
        if ($line !~ m/^\@CURLOPT_INCLUDE\@/) {
			print EASY_PM $line;
        } else {
            foreach my $option (sort keys %cinit_types) {
                next unless $option; # an empty CURLOPT_
                print EASY_PM "CURLOPT_$option\n";
            }
            foreach my $option (sort @curlinfo) {
                print EASY_PM $option . "\n";
            }
        }
    }
    close(EASY_PM);
    close(EASY_PM_IN);

	print "Building Share.pm constants for your libcurl version\n";

    open(SHARE_PM,   ">lib/WWW/Curl/Share.pm")    or die "Can't create lib/WWW/Curl/Share.pm\n";
    open(SHARE_PM_IN, "template/Share.pm.tmpl") or die "Can't read template/Share.pm.tmpl\n";
    while (my $line = <SHARE_PM_IN>) {
        if ($line !~ m/^(.*?)\@CURLSHOPT_INCLUDE\@/) {
            print SHARE_PM $line;
        } else {
            foreach my $option (sort @curlshopt) {
                print SHARE_PM $1 . $option . "\n";
            }
            foreach my $option (sort @curllockopt) {
                print SHARE_PM $1 . $option . "\n";
            }
        }
    }
    close(SHARE_PM);
    close(SHARE_PM_IN);
}

# Let Module::Install generate META.yml and other necessary files.
WriteMakefile(
    'NAME'         => 'WWW::Curl',
    'VERSION_FROM' => 'lib/WWW/Curl.pm',      # finds $VERSION
    'LIBS'         => "$ldflags $lflags",        # e.g., '-lm'
    'INC'          => $curl_d,        # e.g., '-I/usr/include/other'
    'clean' => { FILES => "curlopt-constants.c head.out body.out" }
);

