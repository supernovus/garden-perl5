#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
  push @INC, './t/lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('CustomSyntax');
ok ref $test eq 'Garden::Template', 'get() CustomSyntax';

my $data = {
  title  => "Hello",
  users => [
    {
      name => "Bob",
      admin => 0,
    },
    {
      name => "Kevin",
      admin => 1,
    },
  ],
};

is $test->render($data),
   "---\nHello World\n  * Bob (user)\n  * Kevin (admin)\n\n", 
   'render() with customized template syntax.';

