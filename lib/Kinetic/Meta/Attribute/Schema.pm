package Kinetic::Meta::Attribute::Schema;

use strict;
use base 'Kinetic::Meta::Attribute';

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 on_delete

  my $on_delete = $attr->on_delete;

During date store schema generation, returns a string describing what to do
with an object that links to another object when that other object is
deleted. This is only relevant when the attribute object represents that
relationship. The possible values for this attributes are:

=over

=item CASCADE

=item RESTRICT

=item SET NULL

=item SET DEFAULT

=item NO ACTION

=back

The default is "CASCADE".

=cut

sub on_delete { shift->{on_delete} }

sub references { shift->{references} }

sub column {
    my $self = shift;
    return $self->name unless $self->references;
    return $self->name . '_id';
}

##############################################################################

=head3 index


fkx_key_name
fkux_key_name

If the attribute is indexed.

If the attribute is unique.

If the attribute is an object.

=cut

sub index {
    my ($self, $class) = @_;
    return unless $self->indexed || $self->references;
    my $key = $class ? $class->key : $self->class->key;
    my $name = $self->column;
    return "idx_$key\_$name";
}

sub build {
    my $self = shift;
    $self->SUPER::build(@_);
    if ($self->{references} = Kinetic::Meta->for_key($self->type)) {
        $self->{on_delete} ||= 'CASCADE';
    } else {
        delete $self->{on_delete};
    }
    return $self;
}

1;
