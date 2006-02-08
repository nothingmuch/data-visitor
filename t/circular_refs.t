#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;


my $m; use ok $m = "Data::Visitor";

my $structure = {
	foo => {
		bar => undef,
	},
};

$structure->{foo}{bar} = $structure;

my $o = $m->new;

{
	alarm 1;
	$o->visit( $structure );
	alarm 0;
	pass( "circular structures don't cause an endless loop" );
}

is_deeply( $o->visit( $structure ), $structure, "Structure recreated" );

