package TestMethods;

sub new {
  return bless {}, shift;
}

sub upper {
  my ($self, $text) = @_;
  return uc($text);
}

sub DEFAULT {
  my ($self, $method, @params) = @_;
  return "What is $method? With ".join(', ', @params);
}

1;