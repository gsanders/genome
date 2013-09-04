#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

my $pkg = "Genome::File::Vcf::Genotype";
use_ok($pkg);

my $wild_type = $pkg->new("A", \("T"), "0/0");
ok($wild_type->is_wildtype, "Wild type is wild type");
ok(!$wild_type->is_variant, "Wild type is not variant");
ok($wild_type->is_homozygous, "Wild type is homozygous");
ok(!$wild_type->is_heterozygous, "Wild type is not heterozygous");

my $hom_variant = $pkg->new("A", \("T"), "1/1");
ok($hom_variant->is_homozygous, "Hom is homozygous");
ok(!$hom_variant->is_heterozygous, "Hom is not heterozygous");
ok(!$hom_variant->is_wildtype, "Hom is not wildtype");
ok($hom_variant->is_variant, "Hom is variant");

my $het_variant = $pkg->new("A", \("T"), "0/1");
ok(!$het_variant->is_homozygous, "Het is not homozygous");
ok($het_variant->is_heterozygous, "Het is heterozygous");
ok($het_variant->is_wildtype, "Het is wildtype");
ok($het_variant->is_variant, "Het variant is variant");
is($het_variant->get_allele_by_index(0), 0, "First allele is A");
is($het_variant->get_allele_by_index(1), 1, "Second allele is T");
is($het_variant->get_allele_by_index(2), undef, "There is no third allele");

my @multi_alts = ("T", "C");
my $het2 = $pkg->new("A", \@multi_alts, "1/2");
ok(!$het2->is_homozygous, "Het2 is not homozygous");
ok($het2->is_heterozygous, "Het2 is heterozygous");
ok(!$het2->is_wildtype, "Het2 is not wildtype");
ok($het2->is_variant, "Het2 is variant");

my $missing = Genome::File::Vcf::Genotype->new("A", \("T"), ".");
ok($missing->is_missing, "Missing is missing");
ok(!$missing->is_homozygous, "Missing is not homozygous");
ok(!$missing->is_heterozygous, "Missing is not heterozygous");
ok(!$missing->is_wildtype, "Missing is not wildtype");
ok(!$missing->is_variant, "Missing is not variant");

done_testing;
