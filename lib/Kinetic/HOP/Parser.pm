package Kinetic::HOP::Parser;

use strict;
use warnings;

use base 'Exporter';
use Kinetic::HOP::Stream ':all';

our @EXPORT_OK = qw(parser nothing End_of_Input lookfor
  alternate concatenate star list_of
  operator T null_list match debug
  error action test);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

sub parser (&);    # Advance declaration - see below

## Chapter 8 section 3.1

sub nothing {
    my $input = shift;
    return ( undef, $input );
}

sub End_of_Input {
    my $input = shift;
    defined($input) ? () : ( undef, undef );
}

## Chapter 8 section 3.1

sub lookfor {
    my $wanted = shift;
    my $value  = shift || sub { $_[0][1] };
    my $u      = shift;

    $wanted = [$wanted] unless ref $wanted;
    my $parser = parser {
        my $input = shift;
        return unless defined $input;
        my $next = head($input);
        for my $i ( 0 .. $#$wanted ) {
            next unless defined $wanted->[$i];
            local $^W;    # supress unitialized warnings XXX
            return unless $wanted->[$i] eq $next->[$i];
        }
        my $wanted_value = $value->( $next, $u );
        return ( $wanted_value, tail($input) );
    };

    return $parser;
}

sub match { @_ = [@_]; goto &lookfor }

## Chapter 8 section 3.1

sub parser (&) { $_[0] }

## Chapter 8 section 3.2

sub concatenate {
    shift unless ref $_[0];
    my @p = @_;
    return \&nothing if @p == 0;
    return $p[0]     if @p == 1;

    my $parser = parser {
        my $input = shift;
        my $v;
        my @values;
        for (@p) {
            ( $v, $input ) = $_->($input) or return;
            push @values, $v;
        }
        return ( \@values, $input );
    };
}

## Chapter 8 section 3.2

sub alternate {
    my @p = @_;
    return parser { return () }
      if @p == 0;
    return $p[0] if @p == 1;
    my $parser = parser {
        my $input = shift;
        my ( $v, $newinput );
        for (@p) {
            if ( ( $v, $newinput ) = $_->($input) ) {
                return ( $v, $newinput );
            }
        }
        return;
    };
}

## Chapter 8 section 3.3

sub list_of {
    my ( $element, $separator ) = @_;
    $separator = lookfor('COMMA') unless defined $separator;

    return concatenate( $element, star( $separator, $element ) );
}

1;

## Chapter 8 section 4

sub T {
    my ( $parser, $transform ) = @_;
    return parser {
        my $input = shift;
        if ( my ( $value, $newinput ) = $parser->($input) ) {
            local $^W;    # using this to suppress 'uninitialized' warnings
            $value = [$value] if 'undef' eq $value;
            $value = $transform->(@$value);
            return ( $value, $newinput );
        }
        else {
            return;
        }
    };
}

## Chapter 8 section 4.3

sub null_list {
    my $input = shift;
    return ( [], $input );
}

sub star {
    my $p = shift;
    my $p_star;
    $p_star = alternate(
        T(
            concatenate( $p, parser { $p_star->(@_) } ),
            sub {
                my ( $first, $rest ) = @_;
                [ $first, @$rest ];
            }
        ),
        \&null_list
    );
}

## Chapter 8 section 4.4

sub operator {
    my ( $subpart, @ops ) = @_;
    my (@alternatives);
    for my $operator (@ops) {
        my ( $op, $opfunc ) = @$operator;
        push @alternatives, T(
            concatenate( $op, $subpart ),
            sub {
                my $subpart_value = $_[1];
                sub { $opfunc->( $_[0], $subpart_value ) }
            }
        );
    }
    my $result = T(
        concatenate( $subpart, star( alternate(@alternatives) ) ),
        sub {
            my ( $total, $funcs ) = @_;
            for my $f (@$funcs) {
                $total = $f->($total);
            }
            $total;
        }
    );
}

## Chapter 8 section 4.7.1

our %N;

sub error {
    my ( $checker, $continuation ) = @_;
    my $p;
    $p = parser {
        my $input = shift;

        while ( defined($input) ) {
            if ( my ( undef, $result ) = $checker->($input) ) {
                $input = $result;
                last;
            }
            else {
                drop($input);
            }
        }

        return unless defined $input;

        return $continuation->($input);
    };
    $N{$p} = "errhandler($N{$continuation} -> $N{$checker})";
    return $p;
}

## Chapter 8 section 6

sub action {
    my $action = shift;
    return parser {
        my $input = shift;
        $action->($input);
        return ( undef, $input );
    };
}

sub test {
    my $action = shift;
    return parser {
        my $input  = shift;
        my $result = $action->($input);
        return $result ? ( undef, $input ) : ();
    };
}

sub debug { shift; @_ }    # see Parser::Debug::debug

1;

__END__

=head1 Copyright and License

This software is derived from code in the book "Higher Order Perl" by Mark
Jason Dominus.  This software is licensed under the terms outlined in
L<Kinetic::HOP::License|Kinetic::HOP::License>.

