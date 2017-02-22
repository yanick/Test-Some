package Test::Some;
# ABSTRACT: test a subset of tests

use 5.10.0;

use strict;
use warnings;

use Test::More;

use List::MoreUtils qw/ none any /;
use Package::Stash;

our %filters;

our $BYPASS = 0;

my @init_namespaces;

sub INIT {
        # delaying stuff to INIT 
        # because Test::Some can be loaded before Test::More if used on the
        # prompt

    for my $caller ( keys %filters ) {
        my $original_subtest = $caller->can('subtest')
            or die "no function 'subtest' found in package $caller. Forgot to import Test::More?";

        Package::Stash->new($caller)->add_symbol( '&subtest' => 
            _subtest_maker( $original_subtest, $caller ) 
        );
    }
}

sub import {
    my $caller = caller;
    my(undef,@filters) = @_;

    no warnings 'uninitialized';
    @filters = split ',', $ENV{TEST_SOME} unless @filters;

    _groom_filter($caller,$_) for @filters;

}

sub _groom_filter { 
    my( $caller, $filter, $is_tag, $is_negated ) = @_;

    return $BYPASS = 1 if $filter eq '~';

    return _groom_filter( $caller, $filter, 1, $is_negated )
        if $filter =~ s/^://;

    return _groom_filter( $caller, $filter, $is_tag, 1 )
        if $filter =~ s/^!//;

    return _groom_filter( $caller, qr/$filter/, $is_tag, $is_negated )
        if $filter =~ s#^/##;

    my $sub = ref $filter eq 'CODE' ? $filter 
            : $is_tag               ? sub { 
                    return ref $filter ? any { /$filter/ } keys %_
                                       : $_{$filter};
                }
            :   sub { ref $filter ? /$filter/ : $_ eq $filter };

    if( $is_negated ) {
        my $prev_sub = $sub;
        $sub = sub { not $prev_sub->() };
    }

    push @{ $filters{$caller} }, $sub;
}

sub _should_be_skipped {
    my( $caller, $name, @tags ) = @_;

    return none {
        my $filter = $_;
        {
            local( $_, %_ ) = ( $name, map { $_ => 1 } @tags );
            $filter->();
        }
    } eval { @{ $filters{$caller} } };

}

sub _subtest_maker {
    my( $orig, $caller ) = @_;
    
    return sub {
        my ( $name, $code, @tags ) = @_;

        if( _should_be_skipped($caller,$name,@tags) ) {
            return if $BYPASS;
            $code = sub { 
                Test::More::plan( skip_all => 'Test::Some skipping' ); 
                $orig->($name, sub { } ) 
            }
        }

        $orig->( $name, $code );
    }
}

1;

__END__
