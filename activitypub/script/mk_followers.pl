#!/usr/bin/env perl

use Catmandu;
use Data::UUID;
use Getopt::Long;

my $base_url = 'http://somewhere.org/user';

GetOptions("host=s" => \$base_url);

my $num = shift // 0;

my $exporter = Catmandu->exporter('YAML');
my $gen      = Data::UUID->new;

for (my $i = 0 ; $i < $num ; $i++) {
    $exporter->add({ _id => $base_url . "/" . $gen->create_str()});
}
