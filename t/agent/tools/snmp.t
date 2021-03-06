#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Deep;

use FusionInventory::Agent::Tools::Hardware;

plan tests => 5;

my $oid = '0.1.2.3.4.5.6.7.8.9';
is(getElement($oid, 0),        0, 'getElement with index 0');
is(getElement($oid, -1),       9, 'getElement with index -1');
is(getElement($oid, -2),       8, 'getElement with index -2');
cmp_deeply(
    [ getElements($oid, 0, 3) ],
    [ qw/0 1 2 3/ ],
    'getElements with index 0 to 3'
);
cmp_deeply(
    [ getElements($oid, -4, -1) ],
    [ qw/6 7 8 9/ ],
    'getElements with index -4 to -1'
);
