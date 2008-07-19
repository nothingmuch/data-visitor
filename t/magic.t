#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'Data::Visitor::Callback';

use Tie::RefHash;

my $h = {
	foo => {},
};

tie %{ $h->{foo} }, "Tie::RefHash";

$h->{bar}{gorch} = $h->{foo};

$h->{foo}{[1, 2, 3]} = "blart";

my $v = Data::Visitor::Callback->new( tied_as_objects => 1, object => "visit_ref" ); # deep clone the refhash tied

my $copy = $v->visit($h);

isnt( $copy, $h, "it's a copy" );
isnt( $copy->{foo}, $h->{foo}, "the tied hash is a copy, too" );
is( $copy->{foo}, $copy->{bar}{gorch}, "identity preserved" );
ok( tied %{ $copy->{foo} }, "the subhash is tied" );
isa_ok( tied(%{ $copy->{foo} }), 'Tie::RefHash', 'tied to correct class' );
isnt( tied(%{ $copy->{foo} }), tied(%{ $h->{foo} }), "tied is different" );
ok( ref( ( keys %{ $copy->{foo} } )[0] ), "the key is a ref" );
is_deeply([ keys %{ $copy->{foo} } ], [ keys %{ $h->{foo} } ], "keys eq deeply" );

