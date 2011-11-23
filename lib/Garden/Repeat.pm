=head1 NAME

Garden::Repeat - Repeat object for recursion

=head1 DESCRIPTION

When you apply a template to an array or hash, a magic variable with the
same name of the template is automatically inserted into the template.
This is the class that the object is created from.

It's based on the Repeat object from Flower::TAL (a Perl 6 XML template system.)

=head1 USAGE

  TestTemplate (name, messages) {{
    Hello [[name]], how are you?
    You have [[messages.count]] messages waiting for you:
    [[messages:listMessages(*message)]]
  }}
  listMessages (message) {{
    #[[listMessages.number]] - [[message.title]] <[[message.author]]>
  }}

=cut

package Garden::Repeat;

use strict;
use warnings;

#use Huri::Debug show => ['repeat'];

## Nope, we're not documenting new() as it's not a part of the public API.
sub new {
  my ($class, $index, $length) = @_;
  ##[repeat,new]= $class, $index, $length
  my $self = {
    index  => $index,
    length => $length,
  };
  ##[repeat,new]= $self
  return bless $self, $class;
}

=head1 PUBLIC METHODS

=over 1

=item index

Returns the current iteration number (starts from 0)

=cut

sub index {
  return $_[0]->{index};
}

=item length

Returns the number of items in the array.

=cut

sub length {
  return $_[0]->{length};
}

=item count

Alias for 'length'.

=cut

sub count {
  return $_[0]->{length};
}

=item number

Returns the current item number (starts from 1).
This will always be the same as 'index' + 1.

All methods referring to the number below, are referring to
this value.

=cut

sub number {
  my $self = shift;
  return $self->index + 1;
}

=item start

Returns true if this is the first item.

=cut

sub start {
  my $self = shift;
  return ($self->index == 0);
}

=item end

Returns true if this is the last item.

=cut

sub end {
  my $self = shift;
  return ($self->index == $self->length-1);
}

=item odd

Returns true if the number is odd.

=cut

sub odd {
  my $self = shift;
  return ($self->number % 2 != 0);
}

=item even

Returns true if the number is even.

=cut

sub even {
  my $self = shift;
  return ($self->number % 2 == 0);
}

=item every($num)

Returns true every $num times.

=cut

sub every {
  my ($self, $num) = @_;
  return ($self->number % $num == 0);
}

=item skip($num)

Returns false every $num times.

=cut

sub skip {
  my ($self, $num) = @_;
  return ($self->number % $num != 0);
}

=item lt($num)

Returns true if the number is less than $num.

=cut

sub lt {
  my ($self, $num) = @_;
  return ($self->number < $num);
}

=item gt($num)

Returns true if the number is greater than $num.

=cut

sub gt {
  my ($self, $num) = @_;
  return ($self->number > $num);
}

=item eq($num)

Returns true if the number is equal to $num.

=cut

sub eq {
  my ($self, $num) = @_;
  return ($self->number == $num);
}

=item ne($num)

Returns true if the number is not equal to $num.

=cut

sub ne {
  my ($self, $num) = @_;
  return ($self->number != $num);
}

=item gte($num)

Returns true if the number is greater than or equal to $num.

=cut

sub gte {
  my ($self, $num) = @_;
  return ($self->number >= $num);
}

=item lte($num)

Returns true if the number is less than or equal to $num.

=cut

sub lte {
  my ($self, $num) = @_;
  return ($self->number <= $num);
}

=item repeatEvery($num)

Returns true on the first, and every subsequent $num items.

=cut

sub repeatEvery {
  my ($self, $num) = @_;
  return ($self->start || $self->every($num));
}

=back

=cut

## End of class.
1;
