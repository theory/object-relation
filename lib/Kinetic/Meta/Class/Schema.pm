package Kinetic::Meta::Class::Schema;

use strict;
use base 'Kinetic::Meta::Class';

sub build {
    my $self = shift;
    $self->SUPER::build(@_);
    my $key = $self->key;
    $self->{table} = "_$key";

    my (@cols, %parent_attrs);
    my ($root, @parents) = grep { !$_->abstract }
      reverse $self->SUPER::parents;

    if ($root) {
        # There are concrete parent classes from which we need to inherit.
        my $table = $root->key;
        $self->{parent} = $root;
        $parent_attrs{$table} = [$root->attributes];

        for my $impl (@parents, $self) {
            my $impl_key = $impl->key;
            $self->{parent} = $impl unless $impl_key eq $key;
            $table .= "_$impl_key";
            @cols = grep { $_->class->key eq $impl_key } $impl->attributes;
            $parent_attrs{$impl_key} = [@cols];
        }

        $self->{table} = $table;
        unshift @parents, $root;
    } else {
        # It has no parent class, so its column attributes are all of its
        # attributes.
        @cols = $self->attributes;
    }

    $self->{cols} = \@cols;
    $self->{parent_attrs} = \%parent_attrs;
    $self->{parents} = \@parents;
    return $self;
}

sub parent { shift->{parent} }
sub parents { @{shift->{parents}} }
sub table { shift->{table} }
sub table_attributes { @{shift->{cols}} }
sub view { shift->key }
sub parent_attributes {
    my ($self, $class) = @_;
    my $key = $class->key;
    return unless $self->{parent_attrs}{$key};
    return @{$self->{parent_attrs}{$key}};
}


1;
