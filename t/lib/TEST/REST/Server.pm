package TEST::REST::Server;
use base qw(HTTP::Server::Simple::CGI);
use Kinetic::Interface::REST;
use Kinetic::Util::Constants qw/:http/;

my $REST_SERVER;

sub new {
    my ( $class, $args ) = @_;
    $REST_SERVER = Kinetic::Interface::REST->new(
        domain => $args->{domain},
        path   => $args->{path}
    );
    $class->SUPER::new( @{ $args->{args} } );
}

my $DOC_ROOT      = 'WWW';
my $STATIC        = qr/(js|css)$/;
my %CONTENT_TYPES = (
    js  => 'text/javascript',
    css => 'text/css',
);

sub handle_request {
    my ( $self, $cgi ) = @_;
    my $NEWLINE = "\r\n";
    my ( $status, $type, $response );
    if ( $cgi->path_info =~ $STATIC ) {
        $type = $CONTENT_TYPES{$1};
        my $file = $DOC_ROOT . $cgi->path_info;
        local *FH;
        unless ( open FH, '<', $file ) {
            $status   = NOT_FOUND_STATUS;
            $type     = TEXT_CT;
            $response = 'No resource found to handle ' . $cgi->path_info;
        }
        else {
            $status   = OK_STATUS;
            $response = do { local $/; <FH> };
            close FH;
        }
    }
    else {
        $REST_SERVER->handle_request($cgi);
        $status   = $REST_SERVER->status;
        $type     = $REST_SERVER->content_type;
        $response = $REST_SERVER->response;
    }
    print "HTTP/1.0 $status$NEWLINE";
    print "Content-Type: $type${NEWLINE}Content-Length: ";
    print length($response), $NEWLINE, $NEWLINE, $response;
}

# supress "can connect" printing from HTTP:Server::Simple (grr ...)
sub print_banner { }

1;
