# allow a 2 pixel difference between the values in array ref 1 and array
# ref 2
sub main::aeq
{
    my ($a1, $a2, $e) = @_;
    $e = 0 unless $e;
    return 0 if @$a1 != @$a2;
    for (my $i = 0; $i < @$a1; $i++)
    {
        return 0 if $a1->[$i] > $a2->[$i] + $e || 
                    $a1->[$i] < $a2->[$i] - $e;
    }
    return 1;
}

1;
