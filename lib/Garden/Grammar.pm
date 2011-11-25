## TODO: document this
package Garden::Grammar;

use Modern::Perl;
use Regexp::Grammars;

## Let's set up our grammar.
qr{
  <grammar: Grammar::Garden>

  <rule: Alias>  
    <.startEx>
    (??{ quotemeta $SYNTAX->{alias}[0] })
    <alias=(\w+)>
    (??{ quotemeta $SYNTAX->{alias}[1] })
    <Variable>
    <.endEx>
    \s*?\n?
  <rule: Conditional>
    <.startEx>
    (??{ quotemeta $SYNTAX->{condition}[0] })
    <[Condition]>+
    <.Apply>
    <[Actions]>+
  <rule: Condition>
    <negate=(?{ quotemeta $SYNTAX->{negate} })>? 
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
    (?{ quotemeta $SYNTAX->{positional} }) <var=(\w+)>
  <rule: Param>
    <Variable> | <Template>
  <rule: NamedParam>
    <name=(\w+)> \= <Param>
  <token: Template>
    ( <name=(\w+)> | <var=Indirect> ) <Method>
  <rule: Indirect>
    \( <Variable> \)
  <rule: TemplateCall> <.startEx> <Template> <.endEx>
  <rule: Application>  <.startEx> <Variable> <.Apply> <Template> <Opts>? <.endEx>
  <rule: VariableCall> <.startEx> <Variable> <Opts>? <.endEx>
  <rule: startEx>
    (?{ quotemeta $SYNTAX->{delimiters}[0] })
  <rule: endEx>
    (?{ quotemeta $SYNTAX->{delimiters}[1] })
  <rule: Apply>
    (?{ quotemeta $SYNTAX->{apply} })
  <rule: Opts>
    ; <[Opt]>+
  <rule: Opt>
    <name=(\w+)> \= " <value=(.*?)> "
  
}x;

sub alias {
  my ($SYNTAX) = @_;
  no warnings;
  return qr {
    <extends: Grammar::Garden>
    <Alias>
  }x;
}

sub conditional {
  my ($SYNTAX) = @_;
  no warnings;
  return qr {
    <extends: Grammar::Garden>
    <Conditional>
  }x;
}

 sub application {
  my ($SYNTAX) = @_;
  no warnings;
  return qr {
    <extends: Grammar::Garden>
    <Application>
  }x;
}

sub variable {
  my ($SYNTAX) = @_;
  no warnings;
  return qr {
    <extends: Grammar::Garden>
    <VariableCall>
  }x;
}

sub template {
  my ($SYNTAX) = @_;
  no warnings;
  return qr {
    <extends: Grammar::Garden>
    <TemplateCall>
  }x;
}

## End of library.
1;