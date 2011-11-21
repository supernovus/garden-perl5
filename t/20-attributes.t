#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>6;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('attrTest');
ok ref $test eq 'Garden::Template', 'get() attrTest';

my $user = {
  name     => 'Bob',
  greeting => 'how are you today?',
  job      => {
    title  => 'CEO',
    since  => 'yesterday',
    salary => 'infinite',
  },
  mail => [
    {
      title => 'A test',
      from  => 'me@mine.com',
    },
    {
      title => 'Another test',
      from  => 'him@another.com',
    },
    {
      title => 'A final test',
      from  => 'you@yourself.com',
    },
  ],
};

is $test->render(user=>$user), "Hello Bob, how are you today?", 'render() with simple attribute access.';

$test = $garden->get('attrTest/Multilevel');
ok ref $test eq 'Garden::Template', 'get() Multilevel';

is $test->render(user=>$user), "Hello Bob, I see you are the CEO here.", 'render() with deep attribute access.';

$test = $garden->get('attrTest/Recurse');
ok ref $test eq 'Garden::Template', 'get() Recurse';

is $test->render(user=>$user), "Hello Bob, you have 3 messages waiting.\n  #1 - A test <me\@mine.com>\n  #2 - Another test <him\@another.com>\n  #3 - A final test <you\@yourself.com>\n\n", 'render() with recursion against nested attributes.';

