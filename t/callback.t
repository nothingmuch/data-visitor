#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';


my $m; use ok $m = "Data::Visitor::Callback";

can_ok($m, "new");

my $counters;
my %callbacks = (
	map {
		my $name = $_;
		$name => sub { $counters->{$name}++; $_[1] }
	} qw(
		value
		ref_value
		plain_value
		object
		array
		hash
		visit
	),
);

isa_ok(my $o = $m->new( %callbacks ), $m);

counters_are( "foo", "string", {
	visit => 1,
	value => 1,
	plain_value => 1,
});

counters_are( undef, "undef", {
	visit => 1,
	value => 1,
	plain_value => 1,
});

counters_are( [], "array", {
	visit => 1,
	array => 1,
});

counters_are( {}, "hash", {
	visit => 1,
	hash => 1,
});

counters_are( [ "foo" ], "deep array", {
	visit => 2,
	array => 1,
	value => 1,
	plain_value => 1,
});

counters_are( bless({}, "Moose"), "objecct", {
	visit => 1,
	object => 1,
});

sub counters_are {
	my ( $data, $desc, $expected_counters ) = @_;
	$counters = {};
	$o->visit( $data );
	local $Test::Builder::Level = 2;
	is_deeply( $counters, $expected_counters, $desc );
}
