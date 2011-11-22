## The example from the README, since it should be a test.

use strict;
use warnings;
use Test::More tests=>2;

BEGIN {
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);
my $test   = $garden->get('testTemplate');
ok ref $test eq 'Garden::Template', 'get() testTemplate';

my $data   = {
  name   => "World",
  users  => {
    Bob     => { roles => ['user'],          leader => 0 },
    Kevin   => { roles => ['user','admin'],  leader => 0 },
    Joe     => { roles => ['user','tester'], leader => 1 },
  },
};

my $text =<<ENDOF_TEXT;
Hello World, how are you?
3 users said hi:
  * Bob: #1 user 
  * Joe: #1 user, #2 tester -- Is a team leader.
  * Kevin: #1 user, #2 admin 

ENDOF_TEXT

is $test->render($data), $text, 'render() sample template.';
