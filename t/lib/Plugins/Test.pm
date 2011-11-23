package Plugins::Test;

sub new {
  my ($class, %self) = @_;
  return bless \%self, $class;
}

sub hello {
  my ($self, $name) = @_;
  return "Hello $name";
}

1;