#!/usr/bin/perl -w
# swatch2sec (contributed by Johan Nilsson).
# Convert a swatch configuration file to a simple event correlator conf.
# Far from complete but might save time on long and simple swatch files.
#
# usage: swatch2sec < ~/.swatchrc > newconf.sec
#
use strict;

while ( my $line = <> ) {
    chomp $line;

    # keep comments and whitespace
    if ( $line =~ /(^#|^\s*$)/ ) {
        print "$line\n";
        next;
    }

    # log line
    if ( $line =~ /\s*watchfor\s*\/(.*)\/$/ ) {
        print "type=single
ptype=regexp
pattern=(.*$1.*)
desc=Log line
action=write - \$1\n\n";
        next; # should the pattern ($1) be enough?
    }

    # suppress line
    if ( $line =~ /\s*ignore\s*\/(.*)\/$/ ) {
        print "type=Suppress\nptype=RegExp\npattern=$1\n\n";
        next;
    }

    # echo color not supported by sec, try ccze instead
    if ( $line =~/\s*echo\s*\w/ ){
        next;
    }

    # not implemented
    print "## untranslated line from swatch: $line\n";
}
