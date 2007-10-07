#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;


my $m; use ok $m = "Data::Visitor::Callback";

can_ok($m, "new");

my $counters;
my %callbacks = (
	map {
		my $name = $_;
		$name => sub { $counters->{$name}++; $_[1] }
	} qw(
		visit
		value
		ref_value
		plain_value
		object
		array
		hash
		glob
		scalar
		Moose
		Mammal
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

{
	package Mammal;
	package Moose;
	our @ISA = ("Mammal");
}

counters_are( bless({}, "Moose"), "object", {
	visit => 1,
	object => 1,
	Moose => 1,
	Mammal => 1,
});

counters_are( bless({}, "Mammal"), "object", {
	visit => 1,
	object => 1,
	Mammal => 1,
});

counters_are( \10, "scalar_ref", {
	visit => 2,
	'scalar' => 1,
	value => 1,
	plain_value => 1,
});

our $FOO = 1;
our %FOO = ( "foo" => undef );

counters_are( \*FOO, "glob", {
	visit => 6,
	'scalar' => 1,
	hash => 1,
	value => 3,
	plain_value => 3,
	'glob' => 1,
});

sub counters_are {
	my ( $data, $desc, $expected_counters ) = @_;
	$counters = {};
	$o->visit( $data );
	local $Test::Builder::Level = 2;
	is_deeply( $counters, $expected_counters, $desc );
}
