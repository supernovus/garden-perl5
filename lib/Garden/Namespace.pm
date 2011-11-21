## Represents a template namespace. Typically the contents of a file.

package Garden::Namespace;

use Modern::Perl;
use Carp;

use Garden::Template;

#use Huri::Debug show => ['load'];

sub need_opt {
  my ($what, $opts) = @_;
  if (exists $opts->{$what}) {
    return $opts->{$what};
  }
  else {
    croak "Required parameter '$what' was not specified.";
  }
}

sub new {
  my ($class, %opts) = @_;
  my %self = (
    templates => {},  ## The templates in this namespace.
    syntax    => {},  ## Overridden syntax settings.
    plugins   => {},  ## Section-specific plugins.
    dicts     => {},  ## Namespace dictionaries.
  );
  my $engine = need_opt('engine', \%opts);
  my $lines  = need_opt('lines',  \%opts);
  $self{engine} = $engine;
  my @paths = $engine->paths(1);
  $self{paths} = \@paths;
  my $self = bless \%self, $class;
  $self->load_defs(@{$lines});
  return $self;
}

sub engine {
  return $_[0]->{engine};
}

sub templates {
  return $_[0]->{templates};
}

sub dicts {
  return $_[0]->{dicts};
}

## This returns the appropriate value.
## If you don't specify a type, it returns a hash
## representing the current syntax for this namespace.
sub get_syntax {
  my ($self, $type) = @_;
  if (!defined $type) {
    my %syntax;
    my %localsyn  = %{$self->{syntax}};
    my %globalsyn = %{$self->engine->syntax};
    for my $syn (keys %globalsyn) {
      $syntax{$syn} = $globalsyn{$syn};
    }
    for my $syn (keys %localsyn) {
      $syntax{$syn} = $localsyn{$syn};
    }
    return \%syntax;
  }
  my @namespaces = ($self->{syntax}, $self->engine->syntax);
  for my $ns (@namespaces) {
    if (exists $ns->{$type}) {
      my $synval = $ns->{$type};
      if (ref $synval eq 'ARRAY') {
        return @{$synval};
      }
      else {
        return $synval;
      }
    }
  }
  croak "Invalid syntax type '$type' requested.";
}

## This sets the appropriate value, only once mind you.
sub set_syntax {
  my ($self, $type, $value) = @_;
  if (exists $self->{syntax}->{$type}) {
    warn "Attempt to redefine syntax '$type' more than once.";
    return;
  }
  $self->{syntax}->{$type} = $value;
}

## Add a plugin
sub add_plugin {
  my ($self, $plugid, $plugclass) = @_;
  if (exists $self->{plugins}->{$plugid}) {
    warn "Attempt to redefine '$plugid' plugin.";
    return;
  }
  require $plugclass;
  my $plugin = $plugclass->new(namespace=>$self, engine=>$self->engine);
  $self->{plugins}->{$plugid} = $plugin;
}

## Get a plugin (local plugins override global ones.)
sub get_plugin {
  my ($self, $plugid) = @_;
  if (exists $self->{plugins}->{$plugid}) {
    return $self->{plugins}->{$plugid};
  }
  my $global_plugins = $self->engine->plugins;
  if (exists $global_plugins->{$plugid}) {
    return $global_plugins->{$plugid};
  }
  croak "Invalid plugin '$plugid' requested.";
}

## Add a path. No, there's no append path method here.
## This is used by the "include" statement. That's all.
sub add_path {
  my ($self, $path) = @_;
  unshift(@{$self->{paths}}, $path);
}

## Import the templates and dicts from another namespace.
sub import_namespace {
  my ($self, $nsid) = @_;
  my $namespace = $self->engine->get_namespace($nsid, paths => $self->{paths});
  my %templates = %{$namespace->templates};
  for my $tid (keys %templates) {
    $self->{templates}->{$tid} = $templates{$tid};
  }
  my %dicts = %{$namespace->dicts};
  for my $did (keys %dicts) {
    $self->{dicts}->{$did} = $dicts{$did};
  }
}

## Parse the file.
sub load_defs {
  my ($self, @lines) = @_;
  ##[ns] In load_defs()
  my $in_statements = 1; ## Once a block is found, set to 0.
  my $in_block = 0; ## Set to 1 for Template blocks, and 2 for Dict blocks.
  my $block_text = '';
  my $current_block;
  my $syntax = $self->get_syntax;
  LINES: for my $line (@lines) {
    ## Okay, first, let's see if we're parsing statements.
    if ($in_statements) {
      for my $syntwo ('delimiters','block','dictblock','comment') {
        if ($line =~ /^\s*$syntwo\s+\"(.*?)\",\s*\"(.*?)\"/) {
          my $value = [ $1, $2 ];
          $self->set_syntax($syntwo, $value);
          next LINES;
        }
      }
      for my $synone ('note', 'positional', 'sysvar', 'dictvar', 'apply') {
        if ($line =~ /^\s*$synone\s+"(.*?)\"/) {
          my $value = $1;
          $self->set_syntax($synone, $value);
          next LINES;
        }
      }
      if ($line =~ /^\s*include\s+\"(.*?)\"/) {
        $self->add_path($1);
        next;
      }
      if ($line =~ /^\s*import\s+\"(.*?)\"/) {
        $self->import_namespace($1);
        next;
      }
      ## Okay, plugins. Specify a name, and a class.
      ## NOTE: Plugins are NOT imported with the import statement.
      ## if you want a plugin in a namespace, add it in that namespace.
      if ($line =~ /^\s*plugin\s+\"(.*?)\",\s*\"(.*?)\"/) {
        $self->add_plugin($1, $2);
        next;
      }
    }
    ## Next, let's see if we're parsing a block.
    if ($in_block) {
      my $end_block;
      if ($in_block == 1) {
        $end_block = $syntax->{block}[1];
      }
      elsif ($in_block == 2) {
        $end_block = $syntax->{dictblock}[1];
      }
      ##[ns,load]= $end_block
      if ($line =~ /^\s*\Q$end_block\E\s*$/sm) {
        ##[ns,load] Found end template block.
        if ($in_block == 1) {
          $current_block->set_template($block_text);
        }
        undef($current_block);
        $block_text = '';
        $in_block = 0;
      }
      else {
        if ($in_block == 1) {
          $block_text .= $line;
        }
        elsif ($in_block == 2) {
          if ($line =~ /^\s*\"(.*?)\"\s*:\s*\"(.*?)\"/) {
            $current_block->{$1} = $2;
          }
        }
      }
    }
    else {
      my $start_template = $syntax->{block}[0];
      my $end_template   = $syntax->{block}[1];
      my $start_dict     = $syntax->{dictblock}[0];
      my $blockname = '\s*(\w+)\s*';
      my $signature = '\((.*?)\)\s*';
      if ($line =~ /^ $blockname $signature \Q$start_template\E 
          \s* (.*?) \s* \Q$end_template\E/x) {
        ##[ns,load] Found single-line template block.
        my @signature = split(/[,\s]+/, $2);
        my $template = Garden::Template->new(
          name      => $1,
          namespace => $self,
          signature => \@signature,
        );
        $template->set_template($3);
        $self->{templates}->{$1} = $template;
        next;
      }
      elsif ($line =~ /^ $blockname $signature \Q$start_template\E/x) {
        ##[ns,load] Found multi-line template block.
        my @signature = split(/[,\s]+/, $2);
        $current_block = Garden::Template->new(
          name      => $1,
          namespace => $self, 
          signature => \@signature,
        );
        $self->{templates}->{$1} = $current_block;
        $in_block = 1;
        next;
      }
      elsif ($line =~ /^ $blockname \Q$start_dict\E/x) {
        $current_block = {};
        $self->{dicts}->{$1} = $current_block;
        $in_block = 2;
        next;
      }
    }
  }
}

sub get {
  my ($self, $name, %opts) = @_;
  ##[ns,get]= $name
  ##[deep]= $self->{templates}
  my $deep = 1;
  if ($opts{only}) { $deep = 0; }
  if (exists $self->{templates}->{$name}) {
    return $self->{templates}->{$name};
  }
  if ($deep) {
    return $self->engine->get($name, paths => $self->{paths});
  }
  return;
}

## End of class.
1;