use strict;
use warnings;

use Scalar::Util 'refaddr';

use Test::More tests => 3;

our $original;

BEGIN {
    $original = refaddr \&subtest;
    is $original => refaddr \&Test::More::subtest, "original is T::M, straight up";
}

use Test::Some;

isnt refaddr \&subtest => $original, "subtest replaced locally";
is refaddr \&Test::More::subtest => $original, "but NOT globally";



