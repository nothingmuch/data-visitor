#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;


my $m; use ok $m = "Data::Visitor::Callback";

my $structure = {
	foo => "bar",
	gorch => [ "baz", 1 ],
};

my $o = $m->new(
	ignore_return_values => 0,
	plain_value => sub { s/b/m/g; "laaa" },
	array => sub { $_ = 42; undef},
);

$o->visit( $structure );

$_ = "original";

is_deeply( $structure, {
	foo => "mar",
	gorch => 42,
}, "values were modified" );

is( $_, "original", '$_ unchanged in outer scope');
