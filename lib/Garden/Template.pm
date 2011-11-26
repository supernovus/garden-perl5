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

#use Huri::Debug show => ['template'];

## Find an option in an Opts match object
## via a regular expression search. Oo, ahh.
sub getopt {
  my ($find, $opts, $default) = @_;
  if ( 
    defined $opts 
    && ref $opts eq 'HASH'
    && defined $opts->{Opt}
    && ref $opts->{Opt} eq 'ARRAY'
  ) {
    my @opts = @{$opts->{Opt}};
    for my $opt (@opts) {
      if ($opt->{name} ~~ $find) {
        return $opt->{value};
      }
    }
  }
  return $default;
}

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
  my ($self) = @_;
  return $self->{name};
}

=item namespace

Returns the Namespace object. This is not typically recommended
for application use, and is more for internal use. In the future I may
fully document the Namespace object, in which case extending its functionality
will be possible in your application. At this time, that's not recommended.

=cut

sub namespace {
  my ($self) = @_;
  return $self->{namespace};
}

=item signature

Returns the signature for this template.

=cut

sub signature {
  my ($self) = @_;
  return $self->{signature};
}

sub context {
  my ($self) = @_;
  return $self->{context};
}

sub set_template {
  my ($self, $text) = @_;
  $self->{template} = $text;
}

## Find an attrib. Supports Hashes and method calls with no parameters.
sub get_attrib {
  ##[methods] In get attrib
  my ($self, $object, $attrib) = @_;
  my $type = ref $object;
  if (! $type) { return $object; } ## Should we fail instead?
  my $lookup;
  my $method;
  if ($attrib->{Method}) {
    $method = $attrib->{Method};
  }
  if ($attrib->{var}) {
    $attrib = $self->get_var($attrib->{var}{Variable});
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
          my $sval = $self->get_var($sig->{NamedParam}{Variable});
          push(@params, $sname, $sval);
        }
        else {
          my $value = $self->get_param($sig);
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
  my ($self, $object, $attribs) = @_;
  if (!$attribs) {
    return $object;
  }
  for my $attr (@{$attribs}) {
    $object = $self->get_attrib($object, $attr);
  }
  return $object;
}

## Get a variable
sub get_var {
  my ($self, $variable) = @_;
  my $varname = $variable->{var};
  my $value = $self->context->find($varname);
  my $attribs = $variable->{Attrib};
  if ($attribs) {
    $value = $self->get_attribs($value, $attribs);
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
    return $self->get_template($param->{Template});
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

  $template = Garden::Grammar::parse($syntax, $template, $self);

  return $template;
}

sub parseAlias {
  my ($self, $match) = @_;
  my $alias = $match->{alias};
  ##[parseAlias]= $match
  my $value = $self->get_param($match);
  $self->context->addLocal($alias, $value);
  return ''; ## Aliases don't return anything themselves.
}

sub parseVariableCall {
  my ($self, $match) = @_;
  my $join = getopt(qr/^sep/, $match->{Opts}, '');
  my $value = $self->get_var($match->{Variable});
  my $valtype = ref $value;
  if ($valtype eq 'ARRAY') {
    $value = join($join, @{$value});
  }
  elsif ($valtype eq 'HASH') {
    $value = join($join, sort keys %{$value});
  }
  return $value;
}

sub parseTemplateCall {
  my ($self, $match) = @_;
  return $self->get_template($match->{Template});
}

sub get_template {
  my ($self, $template, $recurse) = @_;

  ##[callTemp]= $template

  my $params; 
  if (ref $template->{Method} eq 'HASH' && $template->{Method}{Params}) {
    $params = $template->{Method}{Params};
  }
  my $name;
  if ($template->{var}) {
    $name = $self->get_var($template->{var}{Variable});
  }
  else {
    $name = $template->{name};
  }

  my %call; ## populate with the call parameters.
  my $rec=0; ## For recursion, what entry are we on?

  if ($params) {
    for my $param (@{$params}) {
      ##[template]= $param
      if ($param->{NamedParam}) {
        my $name = $param->{NamedParam}{name};
        my $val  = $self->get_var($param->{NamedParam}{Variable});
        $call{$name} = $val;
      }
      elsif ($param->{Positional}) {
        if (!$recurse) { 
          croak "Attempt to use a positional variable in an invalid location.";
        }
        my $name = $param->{Positional}{var};
        $call{$name} = $recurse->[$rec++];
      }
      elsif ($param->{Variable}) {
        my $name = $param->{Variable}{var};
        my $val  = $self->get_var($param->{Variable});
        $call{$name} = $val;
      }
      else {
        $self->invalid_var($param->{""});
      }
    }
  }
  my $nested = $self->namespace->get($name);
  return $nested->render(\%call, $self->context->local);
}

sub invalid_var {
  my ($self, $var) = @_;
  croak $self->name . " referenced invalid variable '$var'.";
}

1; ## Temporary, until the following stuff is fixed.

=broken

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

=back

=cut

## End of class
1;