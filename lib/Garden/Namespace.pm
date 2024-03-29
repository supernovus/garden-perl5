=head1 NAME

Garden::Namespace - A collection of templates in a single file/namespace.

=head1 DESCRIPTION

This class represents a Namespace object (typically the contents of a single
file) and is not initialized manually, but through the Garden object.

A template's namespace can be accessed via $template->namespace.

=head1 PUBLIC METHODS

=over 1

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
    templates  => {},  ## The templates in this namespace.
    syntax     => {},  ## Overridden syntax settings.
    plugins    => {},  ## Section-specific plugins.
    dicts      => {},  ## Namespace dictionaries.
    exports    => [],  ## Namespaces we export do (they must allow exports.)
    export_ok  => 1,   ## Allow (1), require (2) or disallow (0) exports.
    extensions => {},  ## Our known extensions, and if they are enabled.
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
  my ($self) = @_;
  return $self->{export_ok};
}

## Do we require exports?
sub requires_export {
  my ($self) = @_;
  return ($self->{export_ok} > 1);
}

=item engine

Returns the engine which loaded this namespace.

=cut

sub engine {
  my ($self) = @_;
  return $self->{engine};
}

=item templates

Returns a hash of all known templates in this namespace.
The key is the name of the template, the value is the Template object.

=cut

sub templates {
  my ($self) = @_;
  return $self->{templates};
}

=item dicts

Returns a Hash representing all of the dictionary objects in this namespace.

=cut

sub dicts {
  my ($self) = @_;
  return $self->{dicts};
}

sub add_export {
  my ($self, $export) = @_;
  push(@{$self->{exports}}, $export);
}

=item get_syntax()

Returns a Hash containing all of the syntax rules for this namespace.

=cut

=item get_syntax($type)

Returns the syntax rules for the specific syntax type. If the type takes
two parameters, it returns two values.

=cut

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

=item plugins

Returns all plugins (including global) that are available in this
namespace. Namespace specific plugins override global ones.

=cut

sub plugins {
  my ($self) = @_;
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

=item extensions 

Returns a hash of our extensions, and if they are enabled or not.

=cut

sub extensions {
  my ($self) = @_;
  return $self->{extensions};
}

=item isext($extension)

Returns if the specified extension is enabled.

=cut

sub isext {
  my ($self, $ext) = @_;
  return $self->{extensions}{$ext};
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
  my ($self, $nsid, $opts) = @_;
  my @imports = ('templates','dicts');
  my $export  = 0;

  ## Parse any options passed.
  if ($opts) {
    $opts =~ s/\s*$//g;
    $opts =~ s/^\://g;
    my @opts = split(/\s*\:/, $opts);

    for my $opt (@opts) {
      if ($opt =~ /^e?x/) {
        $export = 1;
      }
      elsif ($opt =~ /^s/) {
        push(@imports, 'syntax');
      }
      elsif ($opt =~ /^p/) {
        ## If we didn't has extensions loaded, do it now.
        $self->{extensions}{plugins} = 1;
        push(@imports, 'plugins');
      }
    }
  }

  my $namespace = $self->engine->get_namespace($nsid, paths => $self->{paths});

  ## If an included namespace used globals, so do we.
  ## This doesn't go in reverse, sorry.
  if ($namespace->isext('globals')) {
    $self->{extensions}{globals} = 1;
  }

  ## Okay, now import what we've requested.
  for my $import (@imports) {
    my %import = %{$namespace->{$import}};
    for my $id (keys %import) {
      $self->{$import}->{$id} = $import{$id};
    }
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

=item add_template($name, $object)

Add a Template object to the namespace, with the given name.
If this Namespace is exporting to any other Namespaces, they will
have the template added as well.

=cut

sub add_template {
  my ($self, $tid, $template) = @_;
  $self->{templates}->{$tid} = $template;
  for my $export (@{$self->{exports}}) {
    $export->{templates}->{$tid} = $template;
  }
}

=item add_dict($name, $object)

Add a dictionary object (typically a hash) to this namespace.
If this Namespace is exporting to any other Namespaces, they will
have the dictionary added as well.

=cut

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
  my $in_block = 0; ## 1 Template, 2 Dict, 3 JSON (if supported.)
  my $block_text = '';
  my $current_block;
  my $overrides = $self->engine->syntax; ## Used if overriding syntax.
  my $syntax; ## We'll set this below. Once statements are parsed, this
              ## won't change anymore.

  ## Extensions. If we find a use statement for an extension we will
  ## ensure we can handle it, and enable it.
  my $exts = $self->extensions; 
  for my $ext ($self->engine->extensions) {
    $exts->{$ext} = 0;
  }

  LINES: for my $line (@lines) {
    ## Okay, first, let's see if we're parsing statements.
    if ($in_statements) {
      if ($line =~ /^version\s+(\d+)/) {
        my $needver = $1;
        my $minver = $self->engine->MIN_SPEC;
        my $maxver = $self->engine->MAX_SPEC;
        if (($needver > $maxver) || ($needver < $minver)) {
          croak "*** Attempted to load a version $needver template.\n    We can only parse from version $minver to version $maxver templates.\n    Please check for an updated release.\n";
        }
      }
      if ($line =~ /^use\s+(\w+)/) {
        my $extension = lc($1);
        if (!$self->engine->supports($extension)) {
          croak "*** Template requires the $extension extension.\n    This implementation does not support that extension, sorry.\n";
        }
        $exts->{$extension} = 1;
      }
      if ($exts->{globals} && $line =~ /^global\s+(\w+)/x) {
        if (! exists $self->engine->globals->{$1}) {
          croak "*** Template requested an unknown global variable: $1\n";
        }
      }
      for my $override (keys %{$overrides}) {
        if (ref $overrides->{$override} eq 'ARRAY') {
          ## Two part syntax.
          if ($line =~ /^$override \s+ \"(.*?)\" , \s* \"(.*?)\" /x) {
            my $value = [ $1, $2 ];
            $self->set_syntax($override, $value);
            next LINES;
          }
        }
        else {
          if ($line =~ /^$override \s+ "(.*?)\" /x) {
            my $value = $1;
            $self->set_syntax($override, $value);
            next LINES;
          }
        }
      }
      if ($line =~ /^include\s+\"(.*?)\"/) {
        $self->add_path($1);
        next;
      }
      if ($line =~ /^import\s+\"(.*?)\"\s*((?:\:\w+\s*)+)?/) {
        $self->import_namespace($1, $2);
        next;
      }
      if ($line =~ /^no[\-\s_]export/) {
        $self->{export_ok} = 0;
      }
      if ($line =~ /^require[\-\s_]export/) {
        $self->{export_ok} = 2;
      }

      ## The Plugins extension.
      if ($exts->{plugins} && $line =~ /^plugin\s+\"(.*?)\",\s*\"(.*?)\"/) {
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
      elsif ($in_block == 3) {
        $end_block = $syntax->{json}[1];
      }
      ##[ns,load]= $end_block
      if ($line =~ /^\s*\Q$end_block\E\s*$/sm) {
        ##[ns,load] Found end template block.
        if ($in_block == 1) {
          $current_block->set_template($block_text);
        }
        elsif ($in_block == 3) {
          require JSON;
          my $json = JSON->new->utf8->decode($block_text);
          $self->add_dict($current_block, $json);
        }
        undef($current_block);
        $block_text = '';
        $in_block = 0;
      }
      else {
        if ($in_block == 1 || $in_block == 3) {
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
      my $start_json     = $syntax->{json}[0];
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
      elsif ($exts->{json} && $line =~ /^ $blockname \Q$start_json\E/x) {
        $current_block = $1;
        $in_block = 3;
        $in_statements = 0;
        next;
      }
    }
  }
}

=item get($template, ...)

Get a template from this namespace. By default if the template is not
found in this namespace, we will forward the request to the engine's
get() method (using our own paths.) If you want to disable this recursion,
specify "only => 1" as the second parameter.

=cut

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

=back

=cut

## End of class.
1;