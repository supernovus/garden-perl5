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

## Parse an option string.
sub _getopts {
  my ($optstring) = @_;
  my %opts;
  if (defined $optstring && $optstring ne '') {
    my @opts = split(/\s*;+\s*/, $optstring);
    for my $opt (@opts) {
      my ($oname, $oval) = split(/\s*=\s*/, $opt);
      $oval =~ s/^\"//g;
      $oval =~ s/\"$//g;
      $opts{$oname} = $oval;
    }
  }
  return \%opts;
}

## Find an option via smart match.
sub _getopt {
  my ($find, $opts, $default) = @_;
  if (defined $opts && ref $opts eq 'HASH') {
    for my $key (keys %{$opts}) {
      if ($key ~~ $find) {
        return $opts->{$key};
      }
    }
  }
  return $default;
}

## Find an attrib. Supports Hashes and method calls with no parameters.
sub _get_attrib {
  my ($object, $attrib) = @_;
  my $type = ref $object;
  if (! $type) { return $object; } ## Should we fail instead?
  if ($type eq 'HASH') {
    if (exists $type->{$attrib}) {
      return $type->{$attrib};
    }
    elsif (exists $type->{DEFAULT}) {
      return $type->{DEFAULT};
    }
    else {
      croak "No '$attrib' member in Hash.";
    }
  }
  else {
    if ($type->can($attrib)) {
      return $type->$attrib();
    }
    elsif ($type->can('DEFAULT')) {
      return $type->DEFAULT();
    }
    else {
      croak "No '$attrib' method in Object.";
    }
  }
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
  my $apply    = $syntax->{apply};
  my $nested   = '\s* (\w+) \((.*?)\) \s*';
  my $opts     = '(?: \s* ; \s* (.*?) )?';
  my $attrib   = '\. (\w+)';

  ## First, let's find variables (including applications.)
  for my $var (@{$self->signature}) {
    if (! exists $data->{$var}) {
      croak $self->name . " requires '$var' parameter.";
    }
    my $value = $data->{$var};

    ## 1/4, variable attribute with application
    $template =~ s/\Q$start_ex\E \s* $var $attrib \s* \Q$apply\E
      $nested $opts \Q$end_ex\E/
      $self->_apply(_get_attrib($value, $1), $2, $3, $data, 
      _getopts($4))/gmsex;

    ## 2/4, variable with application.
    $template =~ s/\Q$start_ex\E \s* $var \s* \Q$apply\E 
      $nested $opts \Q$end_ex\E/
      $self->_apply($value, $1, $2, $data, _getopts($3))/gmsex;

    ## 3/4, variable attribute.
    $template =~ s/\Q$start_ex\E \s* $var $attrib $opts \Q$end_ex\E/
      $self->_expand(_get_attrib($value, $1), $data, _getopts($2))/gmsex;

    ## 4/4, variable.
    $template =~ s/\Q$start_ex\E $var $opts \Q$end_ex\E/
      $self->_expand($value, $data, _getopts($1))/gmsex;

  }

  ## TODO: Parse dicts here.

  ## Now parse nested template calls.
  ### $1=Name, $2=Signature
  $template =~ s/\Q$start_ex\E $nested \Q$end_ex\E/
    $self->_callTemplate($1, $2, $data)/gmsex;

  
  return $template;
}

sub _expand {
  my ($self, $value, $data, $opts) = @_;
  my $join = _getopt(qr/^sep/, $opts, '');
  my $valtype = ref $value;
  if ($valtype eq 'ARRAY') {
    $value = join($join, @{$value});
  }
  elsif ($valtype eq 'HASH') {
    $value = join($join, keys %{$value});
  }
  return $value;
}

sub _apply {
  my ($self, $value, $template, $params, $data, $opts) = @_;
  my @values;
  my $join = _getopt(qr/^sep/, $opts, '');
  my $valtype = ref $value;
  if ($valtype eq 'ARRAY') {
    for my $val (@{$value}) {
      my @rec = ($val);
      push(@values, $self->_callTemplate($template, $params, $data, \@rec));
    }
  }
  elsif ($valtype eq 'HASH') {
    for my $key (keys %{$value}) {
      my $val = $value->{$key};
      my @rec = ($key, $val);
      push(@values, $self->_callTemplate($template, $params, $data, \@rec));
    }
  }
  return join($join, @values);
}

sub _err_unknown_var {
  my ($self, $var) = @_;
  croak $self->name . "attempted to pass unknown variable '$var'.";
}

## Call a template (internal method.)
sub _callTemplate {
  my ($self, $name, $sigtext, $data, $recurse) = @_;
  my @signature = split(/\s*[;,]+\s*/, $sigtext);
  my %call; ## populate with the call parameters.
  my $rec=0; ## For recursion, what entry are we on?
  for my $sig (@signature) {
    if (! defined $sig || $sig eq '') { next; }
    if ($sig =~ /=/) {
      my ($tvar, $svar) = split(/\s*=\s*/, $sig);
      my $value;
      if ($svar =~ /(\w+)\((.*?)\)/) {
        $value = $self->_callTemplate($1, $2, $data, $recurse);
      }
      else {
        if (exists $data->{$svar}) {
          $value = $data->{$svar};
        }
        else {
          $self->_err_unknown_var($svar);
        }
      }
      $call{$tvar} = $value;
    }
    else {
      if ($sig =~ /^\*/) {
        $sig =~ s/^\*//; ## Strip the leading *.
        $call{$sig} = $recurse->[$rec++];
      }
      elsif (exists $data->{$sig}) {
        $call{$sig} = $data->{$sig};
      }
      else {
        $self->_err_unknown_var($sig);
      }
    }
  }
  my $template = $self->namespace->get($name);
  return $template->render(\%call);
}

## End of class
1;