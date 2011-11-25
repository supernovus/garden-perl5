=head1 NAME

Garden::Template - A Template

=head1 DESCRIPTION

The object representing a template itself.

=head1 USAGE

You don't construct this object manually, instead, you use the get()
method in the Garden class. It will return a Template object that you
can use.

  my $template = $garden->get('myTemplate');
  $template->render(name=>"world");

=cut

package Garden::Template;

use Modern::Perl;
use Carp;

use Garden::Repeat;
use Garden::Context;
use Garden::Grammar;

#use Huri::Debug show => ['methods'];

sub new {
  my ($class, %opts) = @_;
  my %self = ( 'template' => '', 'context' => 0 ); ## populate this.
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

=head1 PUBLIC METHODS

=over 1

=item name

Returns the template name.

=cut

sub name {
  return $_[0]->{name};
}

=item namespace

Returns the Namespace object. This is not typically recommended
for application use, and is more for internal use. In the future I may
fully document the Namespace object, in which case extending its functionality
will be possible in your application. At this time, that's not recommended.

=cut

sub namespace {
  return $_[0]->{namespace};
}

sub set_template {
  my ($self, $text) = @_;
  $self->{template} = $text;
}

=item signature

Returns the signature for this template.

=cut

sub signature {
  return $_[0]->{signature};
}

## Find an option via smart match.
sub getopt {
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
sub get_attrib {
  ##[methods] In get attrib
  my ($self, $object, $attrib, $context) = @_;
  my $type = ref $object;
  if (! $type) { return $object; } ## Should we fail instead?
  my $lookup;
  my $method;
  if ($attrib->{Method}) {
    $method = $attrib->{Method};
  }
  if ($attrib->{var}) {
    $attrib = $self->get_var($attrib->{var}{Variable}, $context);
  }
  else {
    $attrib = $attrib->{name};
  }
  if ($type eq 'HASH') {
    if (exists $object->{$attrib}) {
      return $object->{$attrib};
    }
    elsif ($attrib eq 'count') {
      return scalar keys %{$object};
    }
    elsif (exists $object->{DEFAULT}) {
      return $object->{DEFAULT};
    }
    else {
      return '';
    }
  }
  elsif ($type eq 'ARRAY') {
    given ($attrib) {
      when ('count') {
        return scalar @{$object};
      }
      when ('first') {
        return $object->[0];
      }
      when ('last') {
        my $last = scalar @{$object} - 1;
        return $object->[$last];
      }
      default {
        return '';
      }
    }
  }
  elsif ($type eq 'CODE') {
   return $object->($attrib);
  }
  else {
    my @params;
    if ($method) {
      my @signature = @{$method->{Params}};
      ##[methods]= @signature
      for my $sig (@signature) {
        ##[methods]= $sig
        if ($sig->{NamedParam}) {
          my $sname = $sig->{NamedParam}{name};
          my $sval = $self->get_param($sig->{NamedParam}{Param});
          push(@params, $sname, $sval);
        }
        elsif ($sig->{Param}) {
          my $value = $self->get_param($sig->{Param});
          push(@params, $value);
        }
      }
    }
    if ($object->can($attrib)) {
      ##[methods]= @params
      return $object->$attrib(@params);
    }
    elsif ($object->can('DEFAULT')) {
      return $object->DEFAULT($attrib, @params);
    }
    else {
      return '';
    }
  }
}

## Parse attributes.
sub get_attribs {
  my ($self, $object, $attribs, $context) = @_;
  if (!$attribs) {
    return $object;
  }
  for my $attr (@{$attribs}) {
    $object = $self->get_attrib($object, $attr, $context);
  }
  return $object;
}

## Get a variable
sub get_var {
  my ($self, $variable, $context) = @_;
  my $varname = $variable->{var};
  my $value = $context->find($varname);
  my $attribs = $variable->{Attrib};
  if ($attribs) {
    $value = $self->get_attribs($value, $attribs, $context);
  }
  return $value;
}

## Get a parameter (can be either a variable or a template.)
sub get_param {
  my ($self, $param) = @_;
  if ($param->{Variable}) {
    return $self->get_var($param->{Variable});
  }
  elsif ($param->{Template}) {
    return $self->template($param->{Template});
  }
}

=item render(...)

Render the template using the specified data.
The data can be specified as a hash reference:

  $template->render($hashref);

or you can pass named parameters:

  $template->render(name=>"Bob", roles=>['user','admin']);

It's up to you. You cannot mix and match the two styles, you can only
use one or the other.

=cut

## We're not putting the $local hashref into the public API as it's
## used internally, and not meant for public consumption.
sub render {
  my $self = shift;
  my $data;
  my $local;
  if (ref $_[0] eq 'HASH') {
    $data = shift;
    if (ref $_[0] eq 'HASH') {
      $local = shift;
    }
    else {
      $local = {};
    }
  }
  else {
    my %hash = @_;
    $data = \%hash;
    $local = {};
  }

  my $context = Garden::Context->new($self->name);
  $context->addSource($local);
  $context->addSource($data, $self->signature, 1);
  $context->addSource($self->namespace->dicts);
  $context->addSource($self->namespace->plugins);
  $self->{context} = $context;

  my $template = $self->{template};
  ##[temp,render]= $template
  my ($start_comment, $end_comment) = $self->namespace->get_syntax('comment');
  my $note = $self->namespace->get_syntax('note');
  $template =~ s/\Q$start_comment\E (.*?) \Q$end_comment\E//xgsm;
  $template =~ s/\Q$note\E(.*?)\n//xgsm;

  my $syntax = $self->namespace->get_syntax();

  my $alias       = Garden::Grammar::alias($syntax);
#  my $conditional = Garden::Grammar::conditional($syntax);
#  my $application = Garden::Grammar::application($syntax);
#  my $variable    = Garden::Grammar::variable($syntax);
#  my $template    = Garden::Grammar::template($syntax);

  $template =~ s|$alias|$self->set_alias($/{Alias})|gmsex;
#  $template =~ s|$conditional|$self->conditional($/{Conditional})|gmsex;
#  $template =~ s|$application|$self->apply($/{Application})|gmsex;
#  $template =~ s|$variable|$self->expand($/{VariableCall})|gmsex;
#  $template =~ s|$template|$self->template($/{TemplateCall}{Template})|gmsex;

  return $template;
}

sub set_alias {
  my ($self, $match) = @_;
  say "We're in set_alias";
  my $alias = $match->{alias};
  say "And alias is: $alias";
  my $var = $match->{Variable};
  my $varname = $var->{var};
  say "And we're mapping it to: $varname";
  my $attribs = $var->{Attrib};
  if ($attribs) {
    say "We have attribs";
    for my $attr (@{$attribs}) {
      if ($attr->{name}) {
        say " - " . $attr->{name};
      }
      elsif ($attr->{var}) {
        say " * ". $attr->{var}{Variable}{var};
      }
      if ($attr->{Method}) {
        say "   ^ a method";
      }
    }
  }
=comment
  my $value = $self->get_var($var, $context);
  $context->addLocal($alias, $value);
=cut
  return ''; ## Aliases don't return anything themselves.
}

1;
=fuck
sub _get_tempdef {
  my ($c, $actions, $nested) = @_;
  my $tempstring = $actions->[$c];
  if ($tempstring =~ /^ $nested $/msx) {
    return ($1, $2);
  }
  else {
    croak "Invalid template call: '$tempstring', cannot continue.";
  }
}

sub conditional {
  my ($self, $match, $context) = @_;
  my @conditions = split(/\Q$sep\E/, $conditions);
  my @actions    = split(/\Q$sep\E/, $actions);
  my $regex = $self->regex;
  my $nested  = $regex->{nested};
  my $attribs = $regex->{attribs};
  my $c = 0;  ## Current condition.
  my $negate;
  for my $cond (@conditions) {
    my $true = 1;
    my ($varname, $attrs);
    if ($cond =~ /^ (\Q$negate\E)? (\w+) $attribs $/msx) {
      $varname = $2;
      $attrs   = $3;
      if ($1) { $true = 0; }
    }
    else {
      croak "Invalid condition: '$cond', cannot continue.";
    }
    my $value = $context->find($varname);
    if (!defined $value || $value eq $varname) { 
      ## Couldn't find anything, skip it.
      $c++;
      next;
    }
    if ($attrs) {
      $value = $self->get_attribs($value, $attrs, $context);
    }
    if (($true && $value)||(!$true && !$value)) {
      my ($tempname, $tempsig) = _get_tempdef($c, \@actions, $nested);
      return $self->_callTemplate($tempname, $tempsig, $context);
    }
    $c++;
  }
  my $acount = scalar @actions;
  if ($c < $acount) {
    my ($tempname, $tempsig) = _get_tempdef($c, \@actions, $nested);
    return $self->_callTemplate($tempname, $tempsig, $context);
  }
  else {
    return ''; ## Death to failed conditionals.
  }
}

sub expand {
  my ($self, $match) = @_;
  my $join = getopt(qr/^sep/, $opts, '');
  my $valtype = ref $value;
  if ($valtype eq 'ARRAY') {
    $value = join($join, @{$value});
  }
  elsif ($valtype eq 'HASH') {
    $value = join($join, sort keys %{$value});
  }
  return $value;
}

sub apply {
  my ($self, $match) = @_;
  my @values;
  my $join = getopt(qr/^sep/, $opts, '');
  my $valtype = ref $value;
  if ($valtype eq 'ARRAY') {
    my $count = scalar @{$value};
    my $cur   = 0;
    for my $val (@{$value}) {
      ##[temp,apply]= $count, $cur
      my $repeat = Garden::Repeat->new($cur++, $count);
      $context->addLocal($template, $repeat);
      my @rec = ($val);
      push(@values, $self->callTemplate($template, $params, 
        $context, \@rec));
    }
  }
  elsif ($valtype eq 'HASH') {
    my @keys = sort keys %{$value};
    my $count = scalar @keys;
    my $cur   = 0;
    for my $key (@keys) {
      my $repeat = Garden::Repeat->new($cur++, $count);
      $context->addLocal($template, $repeat);
      my $val = $value->{$key};
      my @rec = ($key, $val);
      push(@values, $self->callTemplate($template, $params,
        $context, \@rec));
    }
  }
  $context->delLocal($template);
  return join($join, @values);
}

sub invalid_var {
  my ($self, $var) = @_;
  croak $self->name . " referenced invalid variable '$var'.";
}

## Call a template (internal method.)
sub callTemplate {
  my ($self, $name, $sigtext, $recurse) = @_;
  ##[callTemp]= $data, $local

  my $regex = $self->regex;
  my $nested  = $regex->{nested};
  my $attribs = $regex->{attribs};

  my $positional;

  my @signature = split(/\s*[;,]+\s*/, $sigtext);
  my %call; ## populate with the call parameters.
  my $rec=0; ## For recursion, what entry are we on?
  for my $sig (@signature) {
    if (! defined $sig || $sig eq '') { next; }
    if ($sig =~ /=/) {
      my ($tvar, $svar) = split(/\s*=\s*/, $sig);
      my $value;
      if ($svar =~ /^ $nested $/msx) {
        $value = $self->_callTemplate($1, $2, $context, $recurse);
      }
      elsif ($svar =~ /^ (\w+) $attribs $/msx) {
        $value = $context->find($1); ## Find the main one.
        if (defined $2) {
          $value = $self->get_attribs($value, $2, $context);
        }
      }
      else {
        $self->invalid_var($svar);
      }
      $call{$tvar} = $value;
    }
    else {
      if ($sig =~ /^\Q$positional\E/) {
        $sig =~ s/^\Q$positional\E//; ## Strip the leading *.
        $call{$sig} = $recurse->[$rec++];
      }
      elsif ($sig =~ /^ (\w+) $attribs $/msx) {
        ##[callwtf]= $data $sig
        my $value = $context->find($1);
        if (defined $2) {
          $value = $self->get_attribs($value, $2, $context);
        }
        $call{$sig} = $value;
      }
      else {
        $self->invalid_var($sig);
      }
    }
  }
  if ($name =~ /^ \( (\w+) $attribs \) /x) {
    $name = $context->find($1);
    if ($2) {
      $name = $self->get_attribs($name, $2, $context);
    }
  }
  my $template = $self->namespace->get($name);
  return $template->render(\%call, $context->local);
}

=back

=cut

## End of class
1;