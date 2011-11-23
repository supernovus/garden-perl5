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

#use Huri::Debug show => ['methods'];

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

## Shared regexes.
sub regex {
  my $self = shift;
  my $nested  = '\s* ( \(? \w+ \)? ) \((.*?)\) \s*';
  my $opts    = '(?: \s* ; \s* (.*?) )?';
  my $attribs = '(?: ((?: \. \(? \w+ \)? (?:\(.*?\))? )+))?'; 
  return {
    nested   => $nested,
    opts     => $opts,
    attribs  => $attribs,
  };
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

## Find a var, if we can't find it, return the name.
sub _search {
  my ($search, $find) = @_;
  for my $source (@{$search}) {
    ##[search]= $source $find
    if (exists $source->{$find}) {
      return $source->{$find};
    }
  }
  return $find;
}

## Find an attrib. Supports Hashes and method calls with no parameters.
sub _get_attrib {
  ##[methods] In get attrib
  my ($self, $object, $attrib, $search) = @_;
  my $type = ref $object;
  if (! $type) { return $object; } ## Should we fail instead?
  my $methodcall;
  my $method = '(?:\((.*?)\))';
  my $attribs = $self->regex->{attribs};
  if ($attrib =~ /^ \( (\w+) \) $method? /x) {
    $attrib = _search($search, $1);
    $methodcall = $2;
  }
  elsif ($attrib =~ /^ (\w+) $method /x) {
    $attrib = $1;
    $methodcall = $2;
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
    if ($methodcall) {
      my @signature = split(/\s*[;,]+\s*/, $methodcall);
      ##[methods]= @signature
      for my $sig (@signature) {
        ##[methods]= $sig
        my $value;
        if ($sig =~ /=/) {
          ## We currently only support basic attribs in here.
          ## Do we really need more than that? Just use an
          ## alias if you really want it.
          my ($sname, $sval) = split(/\s*=\s*/, $sig);
          if ($sval =~ /^ (\w+) $attribs /x) {
            $value = _search($search, $1);
            if ($2) {
              $value = $self->_get_attribs($value, $2, $search);
            }
          }
          else {
            $self->_err_invalid_var($sval);
          }
          push(@params, $sname, $value);
        }
        elsif ($sig =~ /^ (\w+) $attribs /x) {
          ##[methods]= $1
          $value = _search($search, $1);
          if ($2) {
            $value = $self->_get_attribs($value, $2, $search);
          }
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
sub _get_attribs {
  my ($self, $object, $attrstring, $search) = @_;
  if (!defined $attrstring || $attrstring eq '') {
    return $object;
  }
  $attrstring =~ s/^\.//g; ## Strip leading dot.
  my @attrs = split(/\./, $attrstring);
  for my $attr (@attrs) {
    $object = $self->_get_attrib($object, $attr, $search);
  }
  return $object;
}

## Get the params from a search def
sub _get_search {
  my $search = shift;
  my $source = $search->{data};
  my $test   = 0;
  my $find;
  if (exists $search->{find}) {
    $find = $search->{find};
  }
  else {
    my @keys = keys %{$source};
    $find = \@keys;
  }
  if (exists $search->{test}) {
    $test = $search->{test};
  }
  return ($source, $test, $find);
}

## See if a source has the appropriate params
sub _source_has {
  my ($self, $source, $var, $test) = @_;
  if ($test && ! exists $source->{$var}) {
    croak $self->name . " requires '$var' parameter.";
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
  }
  else {
    my %hash = @_;
    $data = \%hash;
    $local = {};
  }
  my ($start_comment, $end_comment) = $self->namespace->get_syntax('comment');
  my ($start_ex, $end_ex) = $self->namespace->get_syntax('delimiters');
  my ($cond, $csep) = $self->namespace->get_syntax('condition');
  my ($alias, $asep) = $self->namespace->get_syntax('alias');
  my $note   = $self->namespace->get_syntax('note');
  my $apply  = $self->namespace->get_syntax('apply');

  my $template = $self->{template};
  ##[temp,render]= $template
  $template =~ s/\Q$start_comment\E (.*?) \Q$end_comment\E//xgsm;
  $template =~ s/\Q$note\E(.*?)$//xg;
  my $regex    = $self->regex;
  my $nested   = $regex->{nested};
  my $opts     = $regex->{opts};
  my $attribs  = $regex->{attribs};

  ## TODO: Change how plugins work, and add them to the search.
  my @search = (
    { ## 0 - Local settings (repeat object, etc.)
      data => $local,
    },
    { ## 1 - Passed in data
      find => $self->signature,
      data => $data,
      test => 1,
    },
    { ## 2 - Namespace dictionaries
      data => $self->namespace->dicts,
    },
    { ## 3 - Plugins
      data => $self->namespace->plugins,
    },
  );

  my $fsearch = [
    $local,
    $data,
    $search[2]->{data},
    $search[3]->{data},
  ];

  my $searches = \@search;

  ## Look for aliases. Aliases should be on their own line.
  $template =~ s/\Q$start_ex\E \s* \Q$alias\E (\w+) \s* \Q$asep\E \s* (\w+) $attribs 
    \Q$end_ex\E \s*?\n? /$self->_set_alias($1, $2, $3, $fsearch, $local)/gmsex;

  ## Let's look for conditional blocks. 
  $template =~ s/\Q$start_ex\E \s* \Q$cond\E (.*?) \Q$apply\E (.*?) 
    \Q$end_ex\E/$self->_parse_condition($csep, $1, $2, $searches)/gmsex;

  for my $search (@search) {
    my ($source, $test, $find) = _get_search($search);
    for my $var (@{$find}) {
      $self->_source_has($source, $var, $test);
      my $value = $source->{$var};

      ## application
      $template =~ s/\Q$start_ex\E \s* $var $attribs \s* \Q$apply\E
        $nested $opts \Q$end_ex\E/
        $self->_apply($self->_get_attribs($value, $1, $fsearch), $2, $3, $data, 
        _getopts($4), $local)/gmsex;
  
      ## variable
      $template =~ s/\Q$start_ex\E \s* $var $attribs $opts \Q$end_ex\E/
        $self->_expand($self->_get_attribs($value, $1, $fsearch), $data, 
        _getopts($2), $local)/gmsex;
  
    }
  }

  ## Now parse nested template calls.
  ### $1=Name, $2=Signature
  $template =~ s/\Q$start_ex\E $nested \Q$end_ex\E/
    $self->_callTemplate($1, $2, $data, $local)/gmsex;
  
  return $template;
}

sub _set_alias {
  my ($self, $alias, $var, $attribs, $search, $local) = @_;
  my $value = _search($search, $var);
  if ($attribs) {
    $value = $self->_get_attribs($value, $attribs, $search);
  }
  $local->{$alias} = $value;
  return ''; ## Aliases don't return anything themselves.
}

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

sub _parse_condition {
  my ($self, $sep, $conditions, $actions, $searches) = @_;
  my @conditions = split(/\Q$sep\E/, $conditions);
  my @actions    = split(/\Q$sep\E/, $actions);
  my $negate = $self->namespace->get_syntax('negate');
  my $regex = $self->regex;
  my $nested  = $regex->{nested};
  my $attribs = $regex->{attribs};
  my $data  = $searches->[1]->{data};
  my $local = $searches->[0]->{data};
  my $search = [
    $local,
    $data,
    $searches->[2]->{data},
    $searches->[3]->{data},
  ];
  my $c = 0;  ## Current condition.
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
    my $value;
    for my $search (@{$searches}) {
      my $source = $search->{data};
      if (exists $source->{$varname}) {
        $value = $source->{$varname};
        last;
      }
    }
    if (!defined $value) { ## Couldn't find anything, skip it.
      $c++;
      next;
    }
    $value = $self->_get_attribs($value, $attrs, $search);
    if (($true && $value)||(!$true && !$value)) {
      my ($tempname, $tempsig) = _get_tempdef($c, \@actions, $nested);
      return $self->_callTemplate($tempname, $tempsig, $data, $local);
    }
    $c++;
  }
  my $acount = scalar @actions;
  if ($c < $acount) {
    my ($tempname, $tempsig) = _get_tempdef($c, \@actions, $nested);
    return $self->_callTemplate($tempname, $tempsig, $data, $local);
  }
  else {
    return ''; ## Death to failed conditionals.
  }
}

sub _expand {
  my ($self, $value, $data, $opts, $local) = @_;
  my $join = _getopt(qr/^sep/, $opts, '');
  my $valtype = ref $value;
  if ($valtype eq 'ARRAY') {
    $value = join($join, @{$value});
  }
  elsif ($valtype eq 'HASH') {
    $value = join($join, sort keys %{$value});
  }
  return $value;
}

sub _apply {
  my ($self, $value, $template, $params, $data, $opts, $local) = @_;
  my @values;
  my $join = _getopt(qr/^sep/, $opts, '');
  my $valtype = ref $value;
  my %local;
  for my $loc (keys %{$local}) {
    $local{$loc} = $local->{$loc};
  }
  if ($valtype eq 'ARRAY') {
    my $count = scalar @{$value};
    my $cur   = 0;
    for my $val (@{$value}) {
      ##[temp,apply]= $count, $cur
      my $repeat = Garden::Repeat->new($cur++, $count);
      $local{$template} = $repeat;
      my @rec = ($val);
      push(@values, $self->_callTemplate($template, $params, $data, 
        \%local, \@rec));
    }
  }
  elsif ($valtype eq 'HASH') {
    my @keys = sort keys %{$value};
    my $count = scalar @keys;
    my $cur   = 0;
    for my $key (@keys) {
      my $repeat = Garden::Repeat->new($cur++, $count);
      $local{$template} = $repeat;
      my $val = $value->{$key};
      my @rec = ($key, $val);
      push(@values, $self->_callTemplate($template, $params, $data, 
        \%local, \@rec));
    }
  }
  return join($join, @values);
}

sub _err_invalid_var {
  my ($self, $var) = @_;
  croak $self->name . " referenced invalid variable '$var'.";
}

## Call a template (internal method.)
sub _callTemplate {
  my ($self, $name, $sigtext, $data, $local, $recurse) = @_;
  ##[callTemp]= $data, $local
  my $search = [
    $local,
    $data,
    $self->namespace->dicts,
    $self->namespace->plugins,
  ];
  my $regex = $self->regex;
  my $nested  = $regex->{nested};
  my $attribs = $regex->{attribs};

  my $positional = $self->namespace->get_syntax('positional');
  my @signature = split(/\s*[;,]+\s*/, $sigtext);
  my %call; ## populate with the call parameters.
  my $rec=0; ## For recursion, what entry are we on?
  for my $sig (@signature) {
    if (! defined $sig || $sig eq '') { next; }
    if ($sig =~ /=/) {
      my ($tvar, $svar) = split(/\s*=\s*/, $sig);
      my $value;
      if ($svar =~ /^ $nested $/msx) {
        $value = $self->_callTemplate($1, $2, $data, $local, $recurse);
      }
      elsif ($svar =~ /^ (\w+) $attribs $/msx) {
        $value = _search($search, $1); ## Find the main one.
        if (defined $2) {
          $value = $self->_get_attribs($value, $2, $search);
        }
      }
      else {
        $self->_err_invalid_var($svar);
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
        my $value = _search($search, $1);
        if (defined $2) {
          $value = $self->_get_attribs($value, $2, $search);
        }
        $call{$sig} = $value;
      }
      else {
        $self->_err_invalid_var($sig);
      }
    }
  }
  if ($name =~ /^ \( (\w+) $attribs \) /x) {
    $name = _search($search, $1);
    if ($2) {
      $name = $self->_get_attribs($name, $2, $search);
    }
  }
  my $template = $self->namespace->get($name);
  return $template->render(\%call, $local);
}

=back

=cut

## End of class
1;