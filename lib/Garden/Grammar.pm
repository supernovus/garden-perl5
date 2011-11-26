## TODO: document this
package Garden::Grammar;

use Modern::Perl;
use Regexp::Grammars;

#use Huri::Debug show => ['grammar'];

## Here's the main grammar which we parse from.
## The "TOP" rule is the rule which defines valid statements.
## This grammar requires a special SYNTAX variable, which must be
## passed to the parse() function (see below.)
qr{
  <grammar: Grammar::Garden>
  
  <token: TOP>
    <Alias> |
    <Conditional> |
    <Application> |
    <VariableCall> |
    <TemplateCall>

  <rule: Alias>  
    <.startEx>
    (??{ quotemeta $SYNTAX->{alias}[0] })
    <alias=(\w+)>
    (??{ quotemeta $SYNTAX->{alias}[1] })
    <Variable>
    <.endEx>
    \s*?\n?

  <token: Conditional>
    <.startEx>
    (??{ quotemeta $SYNTAX->{condition}[0] })
    <[Condition]>+
    <.Apply>
    <[Actions]>+
    <.endEx>

  <rule: Condition>
    <Negated>? 
    <Variable> (??{ quotemeta $SYNTAX->{condition}[1] })?

  <rule: Actions>
    <Template> (??{ quotemeta $SYNTAX->{condition}[1]})?

  <rule: Variable>
    <var=(\w+)>
    <[Attrib]>*

  <token: Attrib>
     \. ( <name=(\w+)> | <var=Indirect> ) <Method>?

  <rule: Method>
    \( <[Params]>* \)

  <rule: Params>
    ( <Positional> | <NamedParam> | <Param> ) \,?

  <rule: Positional>
    (??{ quotemeta $SYNTAX->{positional} }) <var=(\w+)>

  <rule: Negated>
    (??{ quotemeta $SYNTAX->{negate} })

  <rule: Param>
    <Variable> | <Template>

  <rule: NamedParam>
    <name=(\w+)> \= <Param>

  <token: Template>
    ( <name=(\w+)> | <var=Indirect> ) <Method>

  <rule: Indirect>
    \( <Variable> \)

  <token: TemplateCall> 
    <.startEx> <Template> <.endEx>

  <token: Application>
    <.startEx> <Variable> <.Apply> <Template> <Opts>? <.endEx>

  <token: VariableCall>
    <.startEx> <Variable> <Opts>? <.endEx>

  <token: startEx>
    (??{ quotemeta $SYNTAX->{delimiters}[0] })

  <token: endEx>
    (??{ quotemeta $SYNTAX->{delimiters}[1] })

  <rule: Apply>
    (??{ quotemeta $SYNTAX->{apply} })

  <rule: Opts>
    ; <[Opt]>+

  <rule: Opt>
    <name=(\w+)> \= " <value=(.*?)> "
  
}x;

## This call takes the TOP match, finds out what "kind" of match it was,
## and sends it to the appropriate method in the Actions object.
## This is never called directly, but used by parse() below.
sub call_routine {
  my ($match, $actions) = @_;
  my @keys = keys %{$match};
  for my $key (@keys) {
    if ($key eq "") { next; }
    ##[grammar] >>> Found a $key statement
    my $method = "parse$key";
    if ($actions->can($method)) {
      return $actions->$method($match->{$key});
    }
  }
  return '';
}

## Take a template, search for any known statements, then
## replace those statements with contents returned from the call_routine
## routine. Note: this defines a "magic" SYNTAX variable, which is used
## in the grammar. Use of the grammar in a block without the SYNTAX
## variable will break horribly.
sub parse {
  my ($SYNTAX, $template, $actions) = @_;
  my $regex;
  { no warnings;
    $regex = qr {
      <extends: Grammar::Garden>
      <TOP>
    }x;
  }
  $template =~ s|$regex|call_routine($/{TOP}, $actions)|gmsex;
  return $template;
}

## End of library.
1;