#!/usr/bin/env perl

use Path::Tiny;
use ActivityPub;
use Catmandu -load ;
use Catmandu::Sane;
use JSON;
use Data::Dumper;

Catmandu->load(".");

my $pub = ActivityPub->new(
   scheme  => 'https',
   privkey => path(Catmandu->config->{keys}->{private})->slurp
);

$pub->send(
    'locahost:3000',
    '/actor/fidel/inbox',
    'https://cubanbar.hochstenbach.net/actor/fidel',
    encode_json({
        "test" => "123" ,
        "time" => time
    })
);
