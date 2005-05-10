package Parser::Debug;
use base 'Exporter';
use Parser ':all';
use Stream ':all';
@EXPORT_OK = @Parser::EXPORT_OK;
%EXPORT_TAGS = %Parser::EXPORT_TAGS;

use Data::Dumper;

sub debug;

use B::Deparse;
my $DEPARSE = B::Deparse->new("-p", "-sC");

my $CON = 'A';
sub _concatenate {
  my $id;
  if (ref $_[0]) { $id = "Unnamed concatenation $CON"; $CON++ }
  else {           $id = shift } 

  my @p = @_;
  return \&nothing if @p == 0;
  return $p[0]  if @p == 1;

  my $parser = parser {
    my $input = shift;
    debug "Looking for $id\n";
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse  = 1;
    debug "Current token: ". Data::Dumper::Dumper($input->[0])."\n";
    my $v;
    my @values;
    my ($q, $np) = (0, scalar @p);
    for (@p) {
      $q++;
      debug "*_*_* About to match ".Dumper($input)."\n";
      debug "_*_*_ Next match is ".Dumper(tail($input))."\n";
#      my $body = $DEPARSE->coderef2text($_);
#      debug ">>>>>>>>> about to execute sub $body\n";
      unless (($v, $input) = $_->($input)) {
        debug "Failed concatenated component $q/$np ($id)\n";
        return;
      }
      debug "Matched concatenated component $q/$np ($id)\n";
      push @values, $v;
    }
   debug "Finished matching $id\n";
   return \@values;
  };
  $N{$parser} = $id;
  return $parser;
}

sub _ { 
    @_ = [@_];
    goto &lookfor 
}

sub lookfor {
  my $wanted = shift;
  my $value = shift || sub { $_[0][1] };
  my $u = shift;

  $wanted = [$wanted] unless ref $wanted;
  my $parser = parser {
    my $input = shift;
    return unless defined $input;
    my $next = head($input);
    {
        local $Data::Dumper::Indent = 0;
        local $Data::Dumper::Terse  = 1;
        debug "Trying to match "
            . Dumper($wanted)
            . " and found "
            . Dumper($next)."\n";
    }
    for my $i (0 .. $#$wanted) {
      next unless defined $wanted->[$i];
      return unless $wanted->[$i] eq $next->[$i];
    }
    my $wanted_value = $value->($next, $u);
    return ($wanted_value, tail($input));
  };

  return $parser;
}

## Chapter 8 section 4.5

sub debug {
  return unless $DEBUG || $ENV{DEBUG};
  my $msg = shift;
  my $i = 0;
  $i++ while caller($i);
  $I = "| " x ($i-2);
  print $I, $msg;
  @_;
}


### Chapter 8 section 4.5
#
#my $ALT = 'A';
#sub alternate {
#  my $id;
#  if (ref $_[0]) { $id = "Unnamed alternation $ALT"; $ALT++ }
#  else {           $id = shift }
#  $id = "alternate($id)";
#  my @p = @_;
#  return parser { return () } if @p == 0;
#  return $p[0]                if @p == 1;
#  my $parser = parser {
#    my $input = shift;
#    my ($v, $newinput);
#    for (@p) {
#      if (($v, $newinput) = $_->($input)) {
##        debug "Matched alternated component ($id)\n";
#        return ($v, $newinput);
#      }
#      else {
##        debug "Failed alternated component ($id)\n";
#      }
#    }
#    return;
#  };
#}
#
### Chapter 8 section 4.7.1
#
#sub error {
#  my ($checker, $continuation) = @_;
#  my $p;
#  $p = parser {
#    my $input = shift;
#    debug "Error in $N{$continuation}\n";
#    debug "Discarding up to $N{$checker}\n";
#    my @discarded; 
#    while (defined($input)) {
#      my $h = head($input);
#      if (my (undef, $result) = $checker->($input)) {
#        debug "Discarding $N{$checker}\n";
#        push @discarded, $N{$checker};
#        $input = $result;
#        last;
#      } else {
#        debug "Discarding token [@$h]\n";
#        push @discarded, $h->[1];
#        drop($input);
#      }
#    }
#    warn "Erroneous input: ignoring '@discarded'\n" if @discarded;
#    return unless defined $input;
#    debug "Continuing with $N{$continuation} after error recovery\n";
#    $continuation->($input);
#  };
#  $N{$p} = "errhandler($N{$continuation} -> $N{$checker})";
#  return $p;
#}

1;
