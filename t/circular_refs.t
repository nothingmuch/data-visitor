#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;


use ok "Data::Visitor";
use ok "Data::Visitor::Callback";

my $structure = {
	foo => {
		bar => undef,
	},
};

$structure->{foo}{bar} = $structure;

my $o = Data::Visitor->new;

{
	alarm 1;
	$o->visit( $structure );
	alarm 0;
	pass( "circular structures don't cause an endless loop" );
}

is_deeply( $o->visit( $structure ), $structure, "Structure recreated" );


my $orig = {
	one => [ ],
	two => [ ],
};

$orig->{one}[0] = $orig->{two}[0] = bless {}, "yyy";

my $c = Data::Visitor::Callback->new(
	object => sub { bless {}, "zzzzz" },
);

my $copy = $c->visit( $orig );

is( $copy->{one}[0], $copy->{two}[0], "copy of object is a mapped copy" );
