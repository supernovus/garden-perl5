package Garden;

use Modern::Perl;
use Carp;

use Garden::Namespace;

#use Huri::Debug show => ['all'];

sub lines {
  my $filename = shift;
  open (my $file, $filename);
  my @lines = <$file>;
  return @lines;
}

sub new {
  my ($class, %opts) = @_;
  my %self = (
    extension  => 'tmpl', ## The file extension of templates.
    syntax => {
      delimiters => ['[[', ']]'],
      block      => ['{{', '}}'],
      dictblock  => ['{[', ']}'],
      comment    => ['/*', '*/'],
      note       => '//',
      positional => '*',
      sysvar     => '^',
      dictvar    => '%',
      apply      => ':',
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
  my $file = $name . $self->{extension};
  for my $path (@paths) {
    if (-f $path.$file) {
      return $self->load_namespace_file($path.$file, $name);
    }
  }
  croak "Namespace '$name' was not found, cannot continue.";
}

## End of class.
1;