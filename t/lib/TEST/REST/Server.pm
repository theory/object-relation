package TEST::REST::Server;
use base qw(HTTP::Server::Simple::CGI);
use Kinetic::Interface::REST;

my $REST_SERVER;
sub new {
    my ($class, $args) = @_;
    $REST_SERVER = Kinetic::Interface::REST->new(
        domain => $args->{domain},
        path   => $args->{path}
    );
    $class->SUPER::new(@{$args->{args}});
}

sub handle_request {
    my ($self, $cgi) = @_;
    my $NEWLINE = "\r\n";
    $REST_SERVER->handle_request($cgi);
    my $status   = $REST_SERVER->status;
    my $type     = $REST_SERVER->content_type;
    my $response = $REST_SERVER->response;
    print "HTTP/1.0 $status$NEWLINE";
    print "Content-Type: $type${NEWLINE}Content-Length: ";
    print length($response),
          $NEWLINE,
          $NEWLINE,
          $response;
}

# supress "can connect" printing from HTTP:Server::Simple (grr ...)
sub print_banner {}

1;
