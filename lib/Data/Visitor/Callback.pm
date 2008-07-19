#!/usr/bin/perl

package Data::Visitor::Callback;
use base qw/Data::Visitor/;

use strict;
use warnings;

use Carp qw(carp);
use Scalar::Util qw/blessed refaddr reftype/;

__PACKAGE__->mk_accessors( qw/callbacks class_callbacks ignore_return_values/ );

use constant DEBUG => Data::Visitor::DEBUG();
use constant FIVE_EIGHT => ( $] >= 5.008 );

sub new {
	my ( $class, %callbacks ) = @_;

	my $ignore_ret = 0;
	if	( exists $callbacks{ignore_return_values} ) {
		$ignore_ret = delete $callbacks{ignore_return_values};
	}

	my $tied_as_objects = 0;
	if ( exists $callbacks{tied_as_objects} ) {
		$tied_as_objects = delete $callbacks{tied_as_objects};
	}

	my @class_callbacks = do {
		no strict 'refs';
		grep {
			# this check can be half assed because an ->isa check will be
			# performed later. Anything that cold plausibly be a class name
			# should be included in the list, even if the class doesn't
			# actually exist.

			m{ :: | ^[A-Z] }x # if it looks kinda lack a class name
				or
			scalar keys %{"${_}::"} # or it really is a class
		} keys %callbacks;
	};

	# sort from least derived to most derived
	@class_callbacks = sort { !$a->isa($b) <=> !$b->isa($a) } @class_callbacks;

	$class->SUPER::new({
		tied_as_objects => $tied_as_objects,
		ignore_return_values => $ignore_ret,
		callbacks => \%callbacks,
		class_callbacks => \@class_callbacks,
	});
}

sub visit {
	my ( $self, $data ) = @_;

	my $replaced_hash = local $self->{_replaced} = ($self->{_replaced} || {}); # delete it after we're done with the whole visit

	local *_ = \$_[1]; # alias $_

	if ( ref $data and exists $replaced_hash->{ refaddr($data) } ) {
		if ( FIVE_EIGHT ) {
			$self->trace( mapping => replace => $data, with => $replaced_hash->{ refaddr($data) } ) if DEBUG;
			return $_[1] = $replaced_hash->{ refaddr($data) };
		} else {
			carp(q{Assignment of replacement value for already seen reference } . overload::StrVal($data) . q{ to container doesn't work on Perls older than 5.8, structure shape may have lost integrity.});
		}
	}

	my $ret = $self->SUPER::visit( $self->callback( visit => $data ) );

	$replaced_hash->{ refaddr($data) } = $_ if ref $data and ( not ref $_ or refaddr($data) ne refaddr($_) );

	return $ret;
}

sub visit_seen {
	my ( $self, $data, $result ) = @_;

	my $mapped = $self->callback( seen => $data, $result );

	no warnings 'uninitialized';
	if ( refaddr($mapped) == refaddr($data) ) {
		return $result;
	} else {
		return $mapped;
	}
}

sub visit_value {
	my ( $self, $data ) = @_;

	$data = $self->callback_and_reg( value => $data );
	$self->callback_and_reg( ( ref($data) ? "ref_value" : "plain_value" ) => $data );
}

sub visit_object {
	my ( $self, $data ) = @_;

	$self->trace( flow => visit_object => $data ) if DEBUG;

	$data = $self->callback_and_reg( object => $data );

	my $class_cb = 0;

	foreach my $class ( @{ $self->class_callbacks } ) {
		last unless blessed($data);
		next unless $data->isa($class);
		$self->trace( flow => class_callback => $class, on => $data ) if DEBUG;

		$class_cb++;
		$data = $self->callback_and_reg( $class => $data );
	}

	$data = $self->callback_and_reg( object_no_class => $data ) unless $class_cb;

	$data = $self->callback_and_reg( object_final => $data )
		if blessed($data);

	$data;
}

sub subname { $_[1] }

BEGIN {
	eval {
		require Sub::Name;
		no warnings 'redefine';
		*subname = \&Sub::Name::subname;
	};

	foreach my $reftype ( qw/array hash glob scalar code/ ) {
		my $name = "visit_$reftype";
		no strict 'refs';
		*$name = subname(__PACKAGE__ . "::$name", eval '
			sub {
				my ( $self, $data ) = @_;
				my $new_data = $self->callback_and_reg( '.$reftype.' => $data );
				if ( "'.uc($reftype).'" eq (reftype($new_data)||"") ) {
					my $visited = $self->SUPER::visit_'.$reftype.'( $new_data );

					no warnings "uninitialized";
					if ( refaddr($visited) != refaddr($data) ) {
						return $self->_register_mapping( $data, $visited );
					} else {
						return $visited;
					}
				} else {
					return $self->_register_mapping( $data, $self->visit( $new_data ) );
				}
			}
		' || die $@);
	}
}

sub callback {
	my ( $self, $name, $data, @args ) = @_;

	if ( my $code = $self->callbacks->{$name} ) {
		$self->trace( flow => callback => $name, on => $data ) if DEBUG;
		my $ret = $self->$code( $data, @args );
		return $self->ignore_return_values ? $data : $ret ;
	} else {
		return $data;
	}
}

sub callback_and_reg {
	my ( $self, $name, $data, @args ) = @_;

	my $new_data = $self->callback( $name, $data, @args );

	unless ( $self->ignore_return_values ) {
		no warnings 'uninitialized';
		if ( refaddr($data) != refaddr($new_data) ) {
			return $self->_register_mapping( $data, $new_data );
		}
	}

	return $data;
}

sub visit_tied {
	my ( $self, $tied, @args ) = @_;
	$self->SUPER::visit_tied( $self->callback_and_reg( tied => $tied, @args ), @args );
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Data::Visitor::Callback - A Data::Visitor with callbacks.

=head1 SYNOPSIS

	use Data::Visitor::Callback;

	my $v = Data::Visitor::Callback->new(
		value => sub { ... },
		array => sub { ... },
	);

	$v->visit( $some_perl_value );

=head1 DESCRIPTION

This is a L<Data::Visitor> subclass that lets you invoke callbacks instead of
needing to subclass yourself.

=head1 METHODS

=over 4

=item new %opts, %callbacks

Construct a new visitor.

The options supported are:

=over 4

=item ignore_return_values

When this is true (off by default) the return values from the callbacks are
ignored, thus disabling the fmapping behavior as documented in
L<Data::Visitor>.

This is useful when you want to modify $_ directly

=item tied_as_objects

Whether ot not to visit the L<perlfunc/tied> of a tied structure instead of
pretending the structure is just a normal one.

See L<Data::Visitor/visit_tied>.

=back

=back

=head1 CALLBACKS

Use these keys for the corresponding callbacks.

The callback is in the form:

	sub {
		my ( $visitor, $data ) = @_;

		# or you can use $_, it's aliased

		return $data; # or modified data
	}

Within the callback $_ is aliased to the data, and this is also passed in the
parameter list.

Any method can also be used as a callback:

	object => "visit_ref", # visit objects anyway

=over 4

=item visit

Called for all values

=item value

Called for non objects, non container (hash, array, glob or scalar ref) values.

=item ref_value

Called after C<value>, for references to regexes, globs and code.

=item plain_value

Called after C<value> for non references.

=item object

Called for blessed objects.

Since L<Data::Visitor/visit_object> will not recurse downwards unless you
delegate to C<visit_ref>, you can specify C<visit_ref> as the callback for
C<object> in order to enter objects.

It is reccomended that you specify the classes (or base classes) you want
though, instead of just visiting any object forcefully.

=item Some::Class

You can use any class name as a callback. This is colled only after the
C<object> callback.

If the object C<isa> the class then the callback will fire.

These callbacks are called from least derived to most derived by comparing the
classes' C<isa> at construction time.

=item object_no_class

Called for every object that did not have a class callback.

=item object_final

The last callback called for objects, useful if you want to post process the
output of any class callbacks.

=item array

Called for array references.

=item hash

Called for hash references.

=item glob

Called for glob references.

=item scalar

Called for scalar references.

=item tied

Called on the return value of C<tied> for all tied containers. Also passes in
the variable as the second argument.

=back

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 COPYRIGHT & LICENSE

	Copyright (c) 2006 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut


