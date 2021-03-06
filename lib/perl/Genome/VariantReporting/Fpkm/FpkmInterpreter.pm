package Genome::VariantReporting::Fpkm::FpkmInterpreter;

use strict;
use warnings;
use Genome;

class Genome::VariantReporting::Fpkm::FpkmInterpreter {
    is => ['Genome::VariantReporting::Framework::Component::Interpreter', 'Genome::VariantReporting::Fpkm::EntryParser'],
};

sub name {
    return 'fpkm';
}

sub requires_annotations {
    ('fpkm');
}

sub available_fields {
    return qw/
        fpkm
    /;
}

sub _interpret_entry {
    my $self = shift;
    my $entry = shift;
    my $passed_alt_alleles = shift;

    my %return_values;
    my %fpkm_for_genotype_allele = $self->fpkm_for_genotype_allele($entry);
    for my $variant_allele (@$passed_alt_alleles) {
        $return_values{$variant_allele} = {
            fpkm => $fpkm_for_genotype_allele{$variant_allele},
        };
    }
    return %return_values;
}

1;
