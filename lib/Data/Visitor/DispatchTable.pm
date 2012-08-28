#!/usr/bin/perl

package Data::Visitor::DispatchTable;
BEGIN {
  $Data::Visitor::DispatchTable::AUTHORITY = 'cpan:NUFFIN';
}
{
  $Data::Visitor::DispatchTable::VERSION = '0.27';
}
use Moose;

use MooseX::Types::Moose qw(ArrayRef HashRef Str CodeRef);
use Moose::Util::TypeConstraints qw(duck_type);
use UNIVERSAL::can;

use Carp qw(croak);

use namespace::autoclean;

no warnings 'recursion';

has [qw(entries isa_entries does_entries)] => (
	isa => HashRef[CodeRef|Str],
	is	=> "ro",
	lazy_build => 1,
);

sub _build_entries { +{} }
sub _build_isa_entries { +{} }
sub _build_does_entries { +{} }
# sub all_does

has [qw(all_entries all_isa_entries all_does_entries)] => (
	isa => HashRef,
	is	=> "ro",
	lazy_build => 1,
);

has all_isa_entry_classes => (
	isa => ArrayRef[Str],
	is	=> "ro",
	lazy_build => 1,
);

has includes => (
	isa => ArrayRef[duck_type([qw(resolve)])],
	is	=> "ro",
	lazy_build => 1,
);

sub _build_includes { [] }

sub resolve {
	my ( $self, $class ) = @_;

    # check for direct match
	if ( my $entry = $self->all_entries->{$class} || $self->all_isa_entries->{$class} ) {
		return $entry;
	} else {
        # check for role consumption
	    foreach my $role (keys %{ $self->all_does_entries }) {
            if ($class->can('can') && $class->can('does') && $class->does($role)) {
                return $self->all_does_entries->{$role};
            }
        }
        # check for superclass
		foreach my $superclass ( @{ $self->all_isa_entry_classes } ) {
			if ( $class->isa($superclass) ) {
				return $self->all_isa_entries->{$superclass};
			}
		}
	}

	return;
}

sub BUILD {
	my $self = shift;

	# verify that there are no conflicting internal definitions
	my $reg = $self->entries;
	foreach my $key ( keys %{ $self->isa_entries } ) {
		if ( exists $reg->{$key} ) {
			croak "isa entry $key already present in plain entries";
		}
	}

	# Verify that there are no conflicts between the includesd type maps
	my %seen;
	foreach my $map ( @{ $self->includes } ) {
		foreach my $key ( keys %{ $map->all_entries } ) {
			if ( $seen{$key} ) {
				croak "entry $key found in $map conflicts with $seen{$key}";
			}

			$seen{$key} = $map;
		}

		foreach my $key ( keys %{ $map->all_isa_entries } ) {
			if ( $seen{$key} ) {
				croak "isa entry $key found in $map conflicts with $seen{$key}";
			}

			$seen{$key} = $map;
		}
	}
}

sub _build_all_entries {
	my $self = shift;

	return {
		map { %$_ } (
			( map { $_->all_entries } @{ $self->includes } ),
			$self->entries,
		),
	};
}

sub _build_all_does_entries {
	my $self = shift;

	return {
		map { %$_ } (
			( map { $_->all_isa_entries } @{ $self->includes } ),
			$self->does_entries,
		),
	};
}

sub _build_all_isa_entries {
	my $self = shift;

	return {
		map { %$_ } (
			( map { $_->all_isa_entries } @{ $self->includes } ),
			$self->isa_entries,
		),
	};
}

sub _build_all_isa_entry_classes {
	my $self = shift;

	return [
		sort { !$a->isa($b) <=> !$b->isa($a) } # least derived first
		keys %{ $self->all_isa_entries }
	];
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

Data::Visitor::DispatchTable

=head1 VERSION

version 0.27

=head1 SYNOPSIS

	use Data::Visitor;

	Data::Visitor->new(
		dispatch_table => Data::Visitor::DispatchTable->new(
			entries => {
				Foo => sub { warn "I'm visiting $_[1] and its reftype is 'Foo'" },
			},
			isa_entries => {
				Bar => visit_ref, # all objects that isa Bar will have their data violated
			},
			includes => [
				# you can delegate to other dispatch tables too
				$foo,
				$bar,
			],
		),
	);

=head1 DESCRIPTION

This code is ripped out of L<KiokuDB::TypeMap>.

The mapping is by class, and entries can be keyed normally (using
C<ref $object> equality) or by filtering on C<< $object->isa($class) >>
(C<isa_entries>).

Entries are anything that can be used as a method, i.e. strings used as method
names on the visitor, or code references.

=head1 NAME

Data::Visitor::DispatchTable - cleaner dispatch table support than Data::Visitor::Callback.

=head1 ATTRIBUTES

=over 4

=item entries

A hash of normal entries.

=item isa_entries

A hash of C<< $object->isa >> based entries.

=item includes

A list of parent typemaps to inherit entries from.

=back

=head1 METHODS

=over 4

=item resolve $class

Given a class returns the dispatch table entry for that class.

=item all_entries

Returns the merged C<entries> from this typemap and all the included tables.

=item all_isa_entries

Returns the merged C<isa_entries> from this typemap and all the included
tables.

=item all_isa_entry_classes

An array reference of all the classes in C<all_isa_entries>, sorted from least
derived to most derived.

=back

=head1 AUTHORS

=over 4

=item *

Yuval Kogman <nothingmuch@woobling.org>

=item *

Marcel Grünauer <marcel@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Yuval Kogman.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
