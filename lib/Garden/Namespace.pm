=head1 NAME

Garden::Namespace - A collection of templates in a single file/namespace.

=head1 DESCRIPTION

This class is used internally. There is no direct documentation for it,
as it is not a part of the public API. Read the Garden Spec instead,
as all user-level interaction with this class is done using commands
in template/namespace files.

=cut

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
    exports   => [],  ## Namespaces we export do (they must allow exports.)
    export_ok => 1,   ## Allow (1), require (2) or disallow (0) exports.
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

## Do we allow exports?
sub allows_export {
  my $self = shift;
  return $self->{export_ok};
}

## Do we require exports?
sub requires_export {
  my $self = shift;
  return ($self->{export_ok} > 1);
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

sub add_export {
  my ($self, $export) = @_;
  push(@{$self->{exports}}, $export);
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
  $self->engine->load_plugin($plugclass);
  my $plugin = $plugclass->new(namespace=>$self, engine=>$self->engine);
  $self->{plugins}->{$plugid} = $plugin;
}

## Return the list of plugins
sub plugins {
  my $self = shift;
  my %plugins;
  my %localplug  = %{$self->{plugins}};
  my %globalplug = %{$self->engine->plugins};
  for my $plug (keys %globalplug) {
    $plugins{$plug} = $globalplug{$plug};
  }
  for my $plug (keys %localplug) {
    $plugins{$plug} = $localplug{$plug};
  }
  return \%plugins;
}

## Add a path. No, there's no append path method here.
## This is used by the "include" statement. That's all.
sub add_path {
  my ($self, $path) = @_;
  if (-d $path) {
    unshift(@{$self->{paths}}, $path);
  }
  else {
    for my $curpath (@{$self->{paths}}) {
      my $newpath = $curpath . '/' . $path;
      if (-d $newpath) {
        unshift(@{$self->{paths}}, $newpath);
        last;
      }
    }
  }
}

## Import the templates and dicts from another namespace.
sub import_namespace {
  my ($self, $nsid, $export) = @_;
  my $namespace = $self->engine->get_namespace($nsid, paths => $self->{paths});
  my %templates = %{$namespace->templates};
  for my $tid (keys %templates) {
    $self->{templates}->{$tid} = $templates{$tid};
  }
  my %dicts = %{$namespace->dicts};
  for my $did (keys %dicts) {
    $self->{dicts}->{$did} = $dicts{$did};
  }
  ## Only use export if you really know what you're doing.
  if ($export) {
    if ($namespace->allows_export) {
      $self->add_export($namespace);
    }
    else {
      croak "Attempt to export to $nsid which does not allow exportation.";
    }
  }
  elsif ($namespace->requires_export) {
    croak "$nsid requires export.";
  }
}

sub add_template {
  my ($self, $tid, $template) = @_;
  $self->{templates}->{$tid} = $template;
  for my $export (@{$self->{exports}}) {
    $export->{templates}->{$tid} = $template;
  }
}

sub add_dict {
  my ($self, $did, $dict) = @_;
  $self->{dicts}->{$did} = $dict;
  for my $export (@{$self->{exports}}) {
    $export->{dicts}->{$did} = $dict;
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
  my $overrides = $self->engine->syntax; ## Used if overriding syntax.
  my $syntax; ## We'll set this below. Once statements are parsed, this
              ## won't change anymore.
  LINES: for my $line (@lines) {
    ## Okay, first, let's see if we're parsing statements.
    if ($in_statements) {
      for my $override (keys %{$overrides}) {
        if (ref $overrides->{$override} eq 'ARRAY') {
          ## Two part syntax.
          if ($line =~ /^ \s* $override \s+ \"(.*?)\" , \s* \"(.*?)\" /x) {
            my $value = [ $1, $2 ];
            $self->set_syntax($override, $value);
            next LINES;
          }
        }
        else {
          if ($line =~ /^ \s* $override \s+ "(.*?)\" /x) {
            my $value = $1;
            $self->set_syntax($override, $value);
            next LINES;
          }
        }
      }
      if ($line =~ /^\s*include\s+\"(.*?)\"/) {
        $self->add_path($1);
        next;
      }
      if ($line =~ /^\s*import\s+\"(.*?)\"\s*(\:export)?/) {
        $self->import_namespace($1, $2);
        next;
      }
      if ($line =~ /^\s*no[\-\s_]export/) {
        $self->{export_ok} = 0;
      }
      if ($line =~ /^\s*require[\-\s_]export/) {
        $self->{export_ok} = 2;
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
      if ($in_statements) {
        $syntax = $self->get_syntax;
      }
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
        $self->add_template($1, $template);
        $in_statements = 0;
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
        $self->add_template($1, $current_block);
        $in_block = 1;
        $in_statements = 0;
        next;
      }
      elsif ($line =~ /^ $blockname \Q$start_dict\E/x) {
        $current_block = {};
        $self->add_dict($1, $current_block);
        $in_block = 2;
        $in_statements = 0;
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