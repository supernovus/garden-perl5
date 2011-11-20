## Represents a single template, regardless of file/namespace, etc.

package Garden::Template;

use Modern::Perl;
use Carp;

use Garden::Repeat;

#use Huri::Debug show => ['render'];

sub new {
  my ($class, %opts) = @_;
  my %self = ( 'template' => '' ); ## populate this.
  for my $need ('name', 'namespace', 'signature') {
    if (exists $opts{$need}) {
      $self{$need} = $opts{$need};
    }
    else {
      croak "Required parameter '$need' was not specified.";
    }
  }
  return bless \%self, $class;
}

sub name {
  return $_[0]->{name};
}

sub namespace {
  return $_[0]->{namespace};
}

sub set_template {
  my ($self, $text) = @_;
  $self->{template} = $text;
}

sub signature {
  return $_[0]->{signature};
}

## Render the template using the given data.
## Can take either a Hash reference, or named arguments.
## It can't mix them, sorry, use one or the other.
sub render {
  my $self = shift;
  my $data;
  if (ref $_[0] eq 'HASH') {
    $data = shift;
  }
  else {
    my %hash = @_;
    $data = \%hash;
  }
  my $syntax = $self->namespace->get_syntax;
  my $start_comment = $syntax->{comment}[0];
  my $end_comment   = $syntax->{comment}[1];
  my $note          = $syntax->{note};
  my $template = $self->{template};
  ##[temp,render]= $template
  $template =~ s/\Q$start_comment\E (.*?) \Q$end_comment\E//xgsm;
  $template =~ s/\Q$note\E(.*?)$//xg;
  my $start_ex = $syntax->{delimiters}[0];
  my $end_ex   = $syntax->{delimiters}[1];
  ## First, let's find plain simple variables.
  ## TODO: support options including 'sep='.
  for my $var (@{$self->signature}) {
    if (! exists $data->{$var}) {
      croak $self->name . " requires '$var' parameter.";
    }
    my $value = $data->{$var};
    my $valtype = ref $value;
    if ($valtype eq 'ARRAY') {
      $value = join(' ', @{$value}); ## <-- TODO: default should be ''.
    }
    elsif ($valtype eq 'HASH') {
      $value = join(' ', keys %{$value}); ## <-- TODO: better default?
    }
    $template =~ s/\Q$start_ex\E $var \Q$end_ex\E/$value/xgsm;
  }
  ## TODO: implement the rest of the parser.
  return $template;
}

## End of class
1;