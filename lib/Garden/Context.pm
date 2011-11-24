## TODO: document this
package Garden::Context;

use Modern::Perl;
use Carp;

#use Huri::Debug show => ['addSource'];

sub new {
  my ($class, $name) = @_;
  my %self = (
    'name'    => $name,  ## The name to use for reporting errors.
    'sources' => [],     ## Contains the data sources {data}, {keys}.
    'known'   => {},     ## A cache of known variables.
    'last'    => {},     ## If addLocal overrides something, save its old
                         ## location here, so we can restore it again.
  );
  return bless \%self, $class;
}

sub name {
  my ($self) = @_;
  return $self->{name};
}

sub addSource {
  my ($self, $data, $keys, $required) = @_;
  ##[addSource]= $data $keys $required
  if (!defined $data || ref $data ne 'HASH') { 
    croak "Attempt to add an invalid source to a context."; 
  }
  ## Okay, if we didn't pass a list of keys, let's make our own.
  if (!defined $keys) {
    my @keys = keys %{$data};
    $keys = \@keys;
  }
  ## Now let's cache the keys.
  my $current_source = scalar @{$self->{sources}};
  for my $key (@{$keys}) {
    if (!exists $self->{known}->{$key}) {
      $self->{known}->{$key} = $current_source;
    }
  }
  ## See if we need to check for required keys.
  if ($required) {
    my $need;
    if (ref $required eq 'ARRAY') {
      $need = $required;
    }
    else {
      $need = $keys;
    }
    for my $key (@{$need}) {
      if (! exists $data->{$key}) {
        croak $self->name . " requires '$key'.";
      }
    }
  }
  ## Finally, build the source and add it to our list of sources.
  my $source = {
    data => $data,
    keys => $keys,
  };
  push @{$self->{sources}}, $source;
}

## Return a copy of the local source (the first source added.)
sub local {
  my ($self) = @_;
  my %local;
  my %source = %{$self->{sources}[0]{data}};
  for my $key (keys %source) {
    $local{$key} = $source{$key};
  }
  return \%local;
}

## Add an element to the local source.
sub addLocal {
  my ($self, $key, $value) = @_;
  $self->{sources}[0]{data}{$key} = $value;
  if (exists $self->{known}{$key}) {
    $self->{last}{$key} = $self->{known}{$key};
  }
  $self->{known}{$key} = 0;
}

## Remove an element from the local source.
sub delLocal {
  my ($self, $key) = @_;
  delete $self->{sources}[0]{data}{$key};
  if (exists $self->{last}->{$key}) {
    $self->{known}{$key} = $self->{last}{$key};
  }
  else {
    delete $self->{known}{$key};
  }
}

## Find a variable.
sub find {
  my ($self, $what) = @_;
  my $isknown = $self->known($what);
  if (defined $isknown) {
    return $self->get($what, $isknown);
  }
  return $what;
}

## Get a specific variable from a specific source.
sub get {
  my ($self, $var, $source) = @_;
  return $self->{sources}[$source]{data}{$var};
}

## Return either if a value is known and which context contains it
## or the full list of known variables.
sub known {
  my ($self, $what) = @_;
  if (defined $what) {
    return $self->{known}->{$what};
  }
  else {
    return %{$self->{known}};
  }
}

## End of class.
1;