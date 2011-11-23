=head1 NAME

Garden - A functional template language

=head1 DESCRIPTION

A Perl 5 implementation of the Garden template language.
See https://github.com/supernovus/garden-spec/ for the specification.

=head1 USAGE

In ./templates/exampleTemplate.tmpl:

  exampleTemplate (name) {{
    Hello [[name]]
  }}

In your Perl 5 script:

  use Garden;
  my $garden = Garden->new(paths=>['./templates']);
  my $template = $garden->get('templateName');
  say $template->render(name=>"World");

Returns:

  Hello World

See the tests in the ./t/ folder and the specification for more details.

=cut

package Garden;

use Modern::Perl;
use Carp;

use Garden::Namespace;

## Our version number is a two digit number. The first represents a stable
## API for backwards compatibility of scripts and templates, and forwards
## compatibility of templates. Basically, any script written for version 1.0
## will work on version 1.x. Any template written for version 1.x will work 
## on version 1.y. The second digit is the number of updates that have been
## committed to the library in this stable version. So 1.11 would indicate
## 11 updates to the first major version.

our $VERSION = 0.11;

## Release date in ISO format.

our $RELEASE = "2011-11-23T00:10:00-0800";

#use Huri::Debug show => ['all'];

## I'm not documenting lines(). It's a private subroutine only.

sub lines {
  my $filename = shift;
  open (my $file, $filename);
  my @lines = <$file>;
  return @lines;
}

=head1 CLASS METHODS

=over 1

=item new()

Create a new Garden object. This can take several optional parameters:

  paths        Paths to look for templates in.                   []
  extension    The file extension for templates without a dot    'tmpl'
  delimiters   Delimiters for template expressions               ['[[', ']]']
  block        Delimiters for a template block                   ['{{', '}}']
  dictblock    Delimiters for a dictionary block                 ['{[', ']}']
  comment      Delimiters for a comment block                    ['/*', '*/']
  condition    Start and separator for conditional statements    [ '?', ';' ]
  note         Prefix for a here-to-newline comment              '//'
  positional   Prefix for positional parameters                  '*'
  apply        Symbol to apply a template                        ':'
  negate       Prefix to negate conditions                       '!'

The typical usage would be:

  my $garden = Garden->new(paths=>['./templates']);

=cut

sub new {
  my ($class, %opts) = @_;
  my %self = (
    extension  => 'tmpl', ## The file extension of templates.
    syntax => {
      delimiters => ['[[', ']]'],
      block      => ['{{', '}}'],
      dictblock  => ['{[', ']}'],
      comment    => ['/*', '*/'],
      condition  => ['?',';'],
      note       => '//',
      positional => '*',
      apply      => ':',
      negate     => '!',
    },
    paths      => [], ## Paths we search for files in.
    namespaces => {}, ## Each file we load, represents a Namespace.
    plugins    => {}, ## Plugins add additional functionality.
  );
  ## Now let's see if we've overridden any of them.
  for my $key (keys %self) {
    if (exists $opts{$key}) {
      $self{$key} = $opts{$key};
    }
  }
  for my $key (keys %{$self{syntax}}) {
    if (exists $opts{$key}) {
      $self{syntax}->{$key} = $opts{$key};
    }
  }
  ## Okay, now let's return our object.
  return bless \%self, $class;
}

sub syntax {
  return $_[0]->{syntax};
}

sub paths {
  my ($self, $copy) = @_;
  my @paths;
  if ($copy) {
    for my $path (@{$self->{paths}}) {
      push(@paths, $path);
    }
  }
  else {
    @paths = @{$_[0]->{paths}};
  }
  return @paths;
}

sub plugins {
  return $_[0]->{plugins};
}

sub addPath {
  my $self = shift;
  for my $path (reverse @_) {
    unshift(@{$self->{paths}}, $path);
  }
}

sub appendPath {
  my $self = shift;
  for my $path (@_) {
    push(@{$self->{paths}}, $path);
  }
}

sub addPlugin {
  my ($self, %plugins) = @_;
  for my $plug (keys %plugins) {
    next if exists $self->{plugins}->{$plug}; ## No redefining.
    my $plugin = $plugins{$plug};
    if (! ref $plugin) {
      require $plugin;
      $plugin = $plugin->new(engine=>$self);
    }
    $self->{plugins}->{$plug} = $plugin;
  }
}

## Add a namespace object to our cache.
## Currently, it's a simple wrapper, may do better checking in the future.
sub add_namespace {
  my ($self, $name, $object) = @_;
  $self->{namespaces}->{$name} = $object;
}

## Load a namespace, adds it to our cache.
sub load_namespace_file {
  my ($self, $file, $name) = @_;
  my @lines = lines($file);
  my $namespace = Garden::Namespace->new(engine=>$self, lines=>\@lines);
  $self->add_namespace($name, $namespace);
  return $namespace;
}

## Get a template.
sub get {
  my ($self, $name, %opts) = @_;
  my @paths;
  if (exists $opts{paths}) {
    @paths = @{$opts{paths}};
  }
  else {
    @paths = $self->paths;
  }
  ## If the name starts or ends with a slash, remove it.
  $name =~ s/^\/+//g;
  $name =~ s/\/+$//g;
  ## Now, let's get the template name, and a possible namespace name.
  my $tname = $name;
  my $sname;
  if ($name =~ /\//) {
    my @parts = split(/\//, $name);
    $tname = pop(@parts);
    $sname = join('/', @parts);
  }

  ## First, see if the template is an existing namespace.
  if (exists $self->{namespaces}->{$name}) {
    my $template = $self->{namespaces}->{$name}->get($tname, only=>1);
    return $template if defined $template;
  }
  ## Next, see if we have a prefixed namespace in our cache.
  if (defined $sname && exists $self->{namespaces}->{$sname}) {
    my $template = $self->{namespaces}->{$sname}->get($tname, only=>1);
    return $template if defined $template;
  }
  ## Okay, now, lets see if we can find a template file.
  my $ext = $self->{extension};
  $ext =~ s/^\.//g;
  my $file  = $name  . '.' . $ext;
  my $sfile;
  if (defined $sname) {
    $sfile = $sname . '.' . $ext;
  }
  for my $path (@paths) {
    my $fpath = $path . '/' . $file;
    my $spath;
    if (defined $sfile) {
      $spath = $path . '/' . $sfile;
    }
    ##[all,get]= $fpath $spath
    if (-f $fpath) {
      my $namespace = $self->load_namespace_file($fpath, $tname);
      my $template = $namespace->get($tname, only=>1);
      return $template if defined $template;
    }
    elsif (defined $spath && -f $spath) {
      my $namespace = $self->load_namespace_file($spath, $sname);
      my $template = $namespace->get($tname, only=>1);
      return $template if defined $template;
    }
  }
  croak "Template '$name' was not found, cannot continue.";
}

## Get a namespace. Yeah, it duplicates a bunch of stuff above.
## I'll probably refactor this at some point, right now I just
## want a working version.
sub get_namespace {
  my ($self, $name, %opts) = @_;
  my @paths;
  if (exists $opts{paths}) {
    @paths = @{$opts{paths}};
  }
  else {
    @paths = $self->paths;
  }
  $name =~ s/^\/+//g;
  $name =~ s/\/+$//g;
  if (exists $self->{namespaces}->{$name}) {
    return $self->{namespaces}->{$name};
  }
  my $file = $name . '.' . $self->{extension};
  for my $path (@paths) {
    my $fpath = $path . '/' . $file;
    if (-f $fpath) {
      return $self->load_namespace_file($fpath, $name);
    }
  }
  croak "Namespace '$name' was not found, cannot continue.";
}

## End of class.
1;