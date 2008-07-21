#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use Scalar::Util qw(isweak weaken);

use ok 'Data::Visitor';

my $ref = { };
$ref->{foo} = $ref;
weaken($ref->{foo});

ok( isweak($ref->{foo}), "foo is weak" );

my $v = Data::Visitor->new;

my $copy = $v->visit($ref);

is_deeply( $copy, $ref, "copy is equal" );

ok( isweak($copy->{foo}), 'copy is weak' );

