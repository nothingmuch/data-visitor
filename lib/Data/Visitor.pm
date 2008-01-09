#!/usr/bin/perl

package Data::Visitor;
use base qw/Class::Accessor/;

use strict;
use warnings;

use Scalar::Util qw/blessed refaddr reftype/;
use overload ();
use Symbol ();

use Tie::ToObject;

__PACKAGE__->mk_accessors(qw(tied_as_objects));

our $VERSION = "0.13";

sub visit {
	my ( $self, $data ) = @_;

	my $seen_hash = local $self->{_seen} = ($self->{_seen} || {}); # delete it after we're done with the whole visit
	if ( ref $data ) { # only references need recursion checks
		if ( exists $seen_hash->{ refaddr($data) } ) {
			return $seen_hash->{ refaddr($data) }; # return whatever it was mapped to
		}
	}

	return $self->visit_no_rec_check( $data );
}

sub _get_mapping {
	my ( $self, $data ) = @_;
	$self->{_seen}{ refaddr($data) };
}

sub _register_mapping {
	my ( $self, $data, $new_data ) = @_;
	return $new_data unless ref $data;
	$self->{_seen}{ refaddr($data) } = $new_data;
}

sub visit_no_rec_check {
	my ( $self, $data ) = @_;

	if ( blessed($data) ) {
		return $self->visit_object($data);
	} elsif ( ref $data ) {
		return $self->visit_ref($data);
	}
	
	return $self->visit_value($data);
}

sub visit_object {
	my ( $self, $object ) = @_;

	return $self->_register_mapping( $object, $self->visit_value($object) );
}

sub visit_ref {
	my ( $self, $data ) = @_;

	my $reftype = reftype $data;

	$reftype = "SCALAR" if $reftype =~ /^(?:REF|LVALUE|VSTRING)$/;

	my $method = lc "visit_$reftype";

	if ( $self->can($method) ) {
		return $self->_register_mapping( $data, $self->$method($data) );
	} else {
		return $self->_register_mapping( $data, $self->visit_value($data) );
	}

}

sub visit_value {
	my ( $self, $value ) = @_;

	return $value;
}

sub visit_hash {
	my ( $self, $hash ) = @_;

	if ( not defined wantarray ) {
		$self->_register_mapping( $hash, $hash );
		$self->visit_hash_entries($hash);
	} else {
		my $new_hash = {};
		$self->_register_mapping( $hash, $new_hash );

		my $tied = tied(%$hash);
		if ( $tied and $self->tied_as_objects and blessed(my $new_tied = $self->visit_tied($tied, $hash)) ) {
			tie %$new_hash, 'Tie::ToObject', $new_tied;
		} else {
			%$new_hash = $self->visit_hash_entries($hash);
		}

		return $self->retain_magic( $hash, $new_hash );
	}
}

sub visit_hash_entries {
	my ( $self, $hash ) = @_;
	no warnings 'void';
	map { $self->visit_hash_entry( $_, $hash->{$_}, $hash ) } keys %$hash;
}

sub visit_hash_entry {
	my ( $self, $key, $value, $hash ) = @_;

	return (
		$self->visit_hash_key($key,$value,$hash),
		$self->visit_hash_value($_[2],$key,$hash) # retain aliasing semantics
	);
}

sub visit_hash_key {
	my ( $self, $key, $value, $hash ) = @_;
	$self->visit($key);
}

sub visit_hash_value {
	my ( $self, $value, $key, $hash ) = @_;
	$self->visit($_[1]); # retain it's aliasing semantics
}

sub visit_array {
	my ( $self, $array ) = @_;

	if ( not defined wantarray ) {
		$self->_register_mapping( $array, $array );
		$self->visit_array_entries($array);
		$self->visit_array_entry( $array->[$_], $_, $array ) for 0 .. $#$array
	} else {
		my $new_array = [];
		$self->_register_mapping( $array, $new_array );

		my $tied = tied(@$array);
		if ( $tied and $self->tied_as_objects and blessed(my $new_tied = $self->visit_tied($tied, $array)) ) {
			tie @$new_array, 'Data::Visitor::TieToObject', $new_tied;
		} else {
			@$new_array = $self->visit_array_entries($array);
		}

		return $self->retain_magic( $array, $new_array );
	}
}

sub visit_array_entries {
	my ( $self, $array ) = @_;
	no warnings 'void';
	map { $self->visit_array_entry( $array->[$_], $_, $array ) } 0 .. $#$array;
}

sub visit_array_entry {
	my ( $self, $value, $index, $array ) = @_;
	$self->visit($_[1]);
}

sub visit_scalar {
	my ( $self, $scalar ) = @_;

	my $new_scalar;
	$self->_register_mapping( $scalar, \$new_scalar );

	my $tied = tied($$scalar);
	if ( $tied and $self->tied_as_objects and blessed(my $new_tied = $self->visit_tied($tied, $scalar)) ) {
		tie $new_scalar, 'Data::Visitor::TieToObject', $new_tied;
	} else {
		$new_scalar = $self->visit( $$scalar );
	}

	return $self->retain_magic( $scalar, \$new_scalar );
}

sub visit_code {
	my ( $self, $code ) = @_;
	$self->visit_value($code);
}

sub visit_glob {
	my ( $self, $glob ) = @_;

	my $new_glob = Symbol::gensym();

	$self->_register_mapping( $glob, $new_glob );

	my $tied = tied(*$glob);
	if ( $tied and $self->tied_as_objects and blessed(my $new_tied = $self->visit_tied($tied, $glob)) ) {
		tie *$new_glob, 'Data::Visitor::TieToObject', $new_tied;
	} else {
		no warnings 'misc'; # Undefined value assigned to typeglob
		*$new_glob = $self->visit( *$glob{$_} || next ) for qw/SCALAR ARRAY HASH/;
	}

	return $self->retain_magic( $glob, $new_glob );
}

sub retain_magic {
	my ( $self, $proto, $new ) = @_;

	if ( blessed($proto) and !blessed($new) ) {
		bless $new, ref $proto;
	}

	# FIXME real magic, too

	return $new;
}

sub visit_tied {
	my ( $self, $tied, $var ) = @_;
	$self->visit($tied); # as an object eventually
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Data::Visitor - Visitor style traversal of Perl data structures

=head1 SYNOPSIS

	# NOTE
	# You probably want to use Data::Visitor::Callback for trivial things

	package FooCounter;
	use base qw/Data::Visitor/;

	BEGIN { __PACKAGE__->mk_accessors( "number_of_foos" ) };

	sub visit_value {
		my ( $self, $data ) = @_;

		if ( defined $data and $data eq "foo" ) {
			$self->number_of_foos( ($self->number_of_foos || 0) + 1 );
		}

		return $data;
	}

	my $counter = FooCounter->new;

	$counter->visit( {
		this => "that",
		some_foos => [ qw/foo foo bar foo/ ],
		the_other => "foo",
	});

	$counter->number_of_foos; # this is now 4

=head1 DESCRIPTION

This module is a simple visitor implementation for Perl values.

It has a main dispatcher method, C<visit>, which takes a single perl value and
then calls the methods appropriate for that value.

=head1 METHODS

=over 4

=item visit $data

This method takes any Perl value as it's only argument, and dispatches to the
various other visiting methods, based on the data's type.

=item visit_object $object

If the value is a blessed object, C<visit> calls this method. The base
implementation will just forward to C<visit_value>.

=item visit_ref $value

Generic recursive visitor. All non blessed values are given to this.

C<visit_object> can delegate to this method in order to visit the object
anyway.

This will check if the visitor can handle C<visit_$reftype> (lowercase), and if
not delegate to C<visit_value> instead.

=item visit_array $array_ref

=item visit_hash $hash_ref

=item visit_glob $glob_ref

=item visit_scalar $scalar_ref

These methods are called for the corresponding container type.

=item visit_value $value

If the value is anything else, this method is called. The base implementation
will return $value.

=item visit_hash_entry $key, $value, $hash

Delegates to C<visit_hash_key> and C<visit_hash_value>. The value is passed as
C<$_[2]> so that it is aliased.

=item visit_hash_key $key, $value, $hash

Calls C<visit> on the key and returns it.

=item visit_hash_value $value, $key, $hash

The value will be aliased (passed as C<$_[1]>).

=item visit_array_entry $value, $index, $array

Delegates to C<visit> on value. The value is passed as C<$_[1]> to retain
aliasing.

=item visit_tied $object, $var

When C<tied_as_objects> is enabled and a tied variable (hash, array, glob or
scalar) is encountered this method will be called on the tied object. If a
valid mapped value is returned, the newly constructed result container will be
tied to the return value and no iteration of the contents of the data will be
made (since all storage is delegated to the tied object).

If a non blessed value is returned from C<visit_tied> then the structure will
be iterated normally, and the result container will not be tied at all.

This is because tying to the same class and performing the tie operations will
not yield the same results in many cases.

=back

=head1 RETURN VALUE

This object can be used as an C<fmap> of sorts - providing an ad-hoc functor
interface for Perl data structures.

In void context this functionality is ignored, but in any other context the
default methods will all try to return a value of similar structure, with it's
children also fmapped.

=head1 SUBCLASSING

Create instance data using the L<Class::Accessor> interface. L<Data::Visitor>
inherits L<Class::Accessor> to get a sane C<new>.

Then override the callback methods in any way you like. To retain visitor
behavior, make sure to retain the functionality of C<visit_array> and
C<visit_hash>.

=head1 TODO

=over 4

=item *

Add support for "natural" visiting of trees.

=item *

Expand C<retain_magic> to support tying at the very least, or even more with
L<Variable::Magic> if possible.

=back

=head1 SEE ALSO

L<Data::Rmap>, L<Tree::Simple::VisitorFactory>, L<Data::Traverse>

L<http://en.wikipedia.org/wiki/Visitor_pattern>,
L<http://www.ninebynine.org/Software/Learning-Haskell-Notes.html#functors>,
L<http://en.wikipedia.org/wiki/Functor>

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 COPYRIGHT & LICENSE

	Copyright (c) 2006-2008 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut


