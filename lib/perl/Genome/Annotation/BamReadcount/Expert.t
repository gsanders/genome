#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use above 'Genome';
use File::Slurp qw(write_file);
use Genome::Utility::Test qw(compare_ok);
use Genome::Annotation::TestHelpers qw(
    get_test_somatic_variation_build
);
use Genome::Annotation::Plan::TestHelpers qw(
    set_what_interpreter_x_requires
);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

my $pkg = 'Genome::Annotation::BamReadcount::Expert';
use_ok($pkg) || die;

my $VERSION = 1; # Bump this each time test data changes
my $test_dir = Genome::Utility::Test->data_dir($pkg, "v$VERSION");
if (-d $test_dir) {
    note "Found test directory ($test_dir)";
} else {
    die "Failed to find test directory ($test_dir)";
}

set_what_interpreter_x_requires('bam-readcount');
my $build = get_test_somatic_variation_build($VERSION, File::Spec->join($test_dir, 'plan.yaml'));

my $expert = $pkg->create();
my $dag = $expert->dag();
test_dag_xml($dag);

done_testing();

sub test_dag_xml {
    my $dag = shift;
    my $xml_path = Genome::Sys->create_temp_file_path;
    write_file($xml_path, $dag->get_xml);
    my $expected_xml = File::Spec->join($test_dir, 'expected.xml');
    compare_ok($xml_path, $expected_xml, "Xml looks as expected");
}
