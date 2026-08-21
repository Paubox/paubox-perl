package Paubox_Email_SDK::ApiHelper;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
                          callToAPIByGet
                          callToAPIByPost
                          callToAPIByPut
                          responseCode
                  );

our $VERSION = '2.0.0'; # x-release-please-version

use REST::Client;

#
# Default Constructor
#
sub new {
    my $this = {};
    bless $this;
    return $this
}

sub callToAPIByGet {

    my($class, $baseUrl, $apiUrl, $authHeader) = @_;

    my $client = REST::Client -> new();
    $client -> setTimeout(30);

    $client -> addHeader('Content-Type', 'application/json');
    $client -> addHeader('Authorization', $authHeader) if $authHeader;

    $client -> setHost($baseUrl);
    $client -> GET(
        $apiUrl
    );
    $class -> {'responseCode'} = $client -> responseCode() if ref($class);
    return $client -> responseContent();
}

sub callToAPIByPost {

    my($class, $baseUrl, $apiUrl, $authHeader, $reqBody) = @_;

    my $client = REST::Client -> new();
    $client -> setTimeout(30);

    $client -> addHeader('Content-Type', 'application/json');
    $client -> addHeader('Authorization', $authHeader) if $authHeader;
    $client -> addHeader('Accept', 'application/json');

    $client -> setHost($baseUrl);
    $client -> POST(
        $apiUrl,
        $reqBody
    );
    $class -> {'responseCode'} = $client -> responseCode() if ref($class);
    return $client -> responseContent();
}

sub callToAPIByPut {

    my($class, $baseUrl, $apiUrl, $authHeader, $reqBody) = @_;

    my $client = REST::Client -> new();
    $client -> setTimeout(30);

    $client -> addHeader('Content-Type', 'application/json');
    $client -> addHeader('Authorization', $authHeader) if $authHeader;
    $client -> addHeader('Accept', 'application/json');

    $client -> setHost($baseUrl);
    $client -> PUT(
        $apiUrl,
        $reqBody
    );
    $class -> {'responseCode'} = $client -> responseCode() if ref($class);
    return $client -> responseContent();
}

sub responseCode {
    my ($class) = @_;
    return ref($class) ? $class -> {'responseCode'} : undef;
}

1;
