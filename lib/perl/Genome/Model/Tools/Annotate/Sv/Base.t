#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test;

my $class = "Genome::Model::Tools::Annotate::Sv::Base";
use_ok($class);

my $data_dir = Genome::Utility::Test->data_dir($class);
my $version = 1;
my $base_dir = join("/", $data_dir, "v$version");

my $expected_structure = {
    1 => {
        20972052 => {
            20971165 => [
                {
                  bin => "11",
                  chrom => "1",
                  chromStart => "20971165",
                  chromEnd => "20972052",
                  name => "rs71646557",
                  extra => ["some","other","columns"],
                },
            ],
        },
    },
};
my $file = join("/", $base_dir, "example_ucsc");
my $annot = Genome::Model::Tools::Annotate::Sv::Base->read_ucsc_annotation($file);

is_deeply($annot, $expected_structure) or diag explain [$annot, $expected_structure];

done_testing;
