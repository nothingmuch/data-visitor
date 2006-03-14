#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

use Data::Visitor::Callback;

sub newcb { Data::Visitor::Callback->new( @_ ) }
ok( !newcb()->ignore_return_values, "ignore_return_values defaults to false" );
is( newcb( ignore_return_values => 1 )->ignore_return_values, 1, "but can be set as initial param" );
