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

our $VERSION = 0.25; ## This is 1.0-RC2

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
  alias        Start and separator for alias statements          ['::', '=' ]
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
      condition  => [ '?', ';' ],
      alias      => ['::', '=' ],
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

=back

=head1 PUBLIC METHODS

=over 1

=item syntax

Returns the Hash reference representing the top-level syntax settings.

=cut

sub syntax {
  my ($self) = @_;
  return $self->{syntax};
}

=item paths

Returns an array of paths. If passed 1, it builds a full copy
of the paths before returning them.

=cut

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

=item plugins

Returns the list of global plugins.

=cut

sub plugins {
  my ($self) = @_;
  return $self->{plugins};
}

=item addPath($path,...)

Add a path to look for templates in. The path will be added to the
top of the search list (so it will be looked in first.)

You can specify multiple paths if you want.

=cut

sub addPath {
  my $self = shift;
  for my $path (reverse @_) {
    unshift(@{$self->{paths}}, $path);
  }
}

=item appendPath($path,...)

Add a path to look for templates in. The path will be added to the
bottom of the search list (so it will be looked in after existing paths.)

You can specify multiple paths if you want.

=cut

sub appendPath {
  my $self = shift;
  for my $path (@_) {
    push(@{$self->{paths}}, $path);
  }
}

=item addPlugin(name=>$plugin, ...)

Adds a plugin (or plugins) that will be made available to all templates.
The name is what the template will call the plugin via.

The $plugin part can either be an object, a class name, or path to a
Perl file. addPlugin will figure out how to handle it.

=cut

sub load_plugin {
  my ($self, $plugin) = @_;
  if ($plugin !~ /\.p[ml]/) {
    $plugin .= '.pm';
  }
  $plugin =~ s|::|/|g;
  if (eval { require $plugin; 1; }) {
    return 1;
  }
  return 0;
}

sub addPlugin {
  my ($self, %plugins) = @_;
  for my $plug (keys %plugins) {
    next if exists $self->{plugins}->{$plug}; ## No redefining.
    my $plugin = $plugins{$plug};
    if (! ref $plugin) {
      $self->load_plugin($plugin);
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

=item get($name)

Get a template. Pass it the name of the template you are looking for,
and it will find it and return it.

=cut

## We don't document the paths option, as it's not a part of the public API.
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

## Get a namespace. Not a public API call, this is used by Namespace.
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

=back

=head1 DEPENDENCIES

=over 1

=item Modern::Perl

All of the libraries use Modern::Perl to enforce some sane defaults.

=item Test::More

Used for testing.

=item Test::Exception

Used for testing.

=back

=head1 AUTHOR

Timothy Totten <https://github.com/supernovus/>

=head1 LICENSE

Artistic License 2.0

=cut

## End of class.
1;