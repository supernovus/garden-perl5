package Garden::Repeat;
#
# Represents the Repeat object (^repeat) used when applying templates.
# This is based on the Repeat object from Flower (Perl 6.)
#

use strict;
use warnings;

#use Huri::Debug show => ['repeat'];

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

sub index {
  return $_[0]->{index};
}

sub length {
  return $_[0]->{length};
}

sub count {
  return $_[0]->{length};
}

sub number {
  my $self = shift;
  return $self->index + 1;
}

sub start {
  my $self = shift;
  return ($self->index == 0);
}

sub end {
  my $self = shift;
  return ($self->index == $self->length-1);
}

sub odd {
  my $self = shift;
  return ($self->number % 2 != 0);
}

sub even {
  my $self = shift;
  return ($self->number % 2 == 0);
}

sub every {
  my ($self, $num) = @_;
  return ($self->number % $num == 0);
}

sub skip {
  my ($self, $num) = @_;
  return ($self->number % $num != 0);
}

sub lt {
  my ($self, $num) = @_;
  return ($self->number < $num);
}

sub gt {
  my ($self, $num) = @_;
  return ($self->number > $num);
}

sub eq {
  my ($self, $num) = @_;
  return ($self->number == $num);
}

sub ne {
  my ($self, $num) = @_;
  return ($self->number != $num);
}

sub gte {
  my ($self, $num) = @_;
  return ($self->number >= $num);
}

sub lte {
  my ($self, $num) = @_;
  return ($self->number <= $num);
}

sub repeat_every {
  my ($self, $num) = @_;
  return ($self->start || $self->every($num));
}

sub repeat_skip {
  my ($self, $num) = @_;
  return ($self->start || $self->skip($num));
}

## End of class.
1;
