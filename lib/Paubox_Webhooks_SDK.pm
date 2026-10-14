package Paubox_Webhooks_SDK;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
                          listWebhookEndpoints
                          createWebhookEndpoint
                          getWebhookEndpoint
                          updateWebhookEndpoint
                          deleteWebhookEndpoint
                  );

our $VERSION = '2.3.1'; # x-release-please-version

use Paubox_Email_SDK::ApiHelper;

use JSON;
use Config::General;
use TryCatch;
use URI::Escape;

# The public gateway exposes only /v1/webhooks/endpoints and rewrites it onto
# the service's own /v1/endpoints, so the producers' event-ingest route is not
# reachable from here. The bare base is deliberately unrouted; every request
# below carries the /endpoints resource.
my $webhooksBaseURL = 'https://api.paubox.com/v1/webhooks';

#
# Constructor. Named param: 'apiKey' => a Paubox scoped API key.
#
# Unlike Paubox_Forms_SDK there are no public endpoints here, so every method
# needs a key. When no 'apiKey' param is given, WEBHOOKS_API_KEY is loaded
# from ./config.cfg when present.
#
sub new {
    my ($class, %params) = @_;
    my $this = {};

    if ( defined($params{'apiKey'}) && $params{'apiKey'} ne "" ) {
        $this -> {'apiKey'} = $params{'apiKey'};
    }
    else {
        # A missing or broken config file must surface as the clearer
        # "apiKey is required" die from _getAuthHeader rather than a
        # Config::General parse error, so this lookup is wrapped in eval.
        eval {
            if ( -e 'config.cfg' ) {
                my $conf = Config::General -> new(
                    -ConfigFile => 'config.cfg',
                    -InterPolateVars => 1
                );
                my %config = $conf -> getall;
                if ( defined($config{'WEBHOOKS_API_KEY'}) && $config{'WEBHOOKS_API_KEY'} ne "" ) {
                    $this -> {'apiKey'} = $config{'WEBHOOKS_API_KEY'};
                }
            }
        };
    }

    bless $this, $class;
    return $this;
}

#
# Private methods
#

# Bearer, not the Email API's "Token token=" — the whole reason this is a
# separate package.
sub _getAuthHeader {
    my ($this) = @_;
    if ( !ref($this) || !defined($this -> {'apiKey'}) || $this -> {'apiKey'} eq "" ) {
        die "apiKey is required for this method. Pass 'apiKey' to Paubox_Webhooks_SDK->new() or set WEBHOOKS_API_KEY in config.cfg. Scoped API keys are generated in the Paubox admin dashboard.";
    }
    return "Bearer " . $this -> {'apiKey'};
}

# Sanitizes a caller-supplied endpoint id before interpolation into a URL.
# Without this a value like "<uuid>/../events" would change which endpoint is
# called, and because the Authorization header goes on the same host the
# bearer token rides along on the retargeted request. Every id on this
# service is a UUID, so unlike Paubox_Forms_SDK there is no non-UUID
# fallback. Returns the value percent-encoded so any residual reserved
# character is safe inside a single path segment.
sub _pathSegment {
    my ($value, %opts) = @_;
    my $name = defined($opts{'name'}) ? $opts{'name'} : 'path segment';
    if ( !defined($value) || $value eq "" ) {
        die $name . " is required.";
    }
    if ( $value =~ m{[/?#\r\n]} ) {
        die "invalid " . $name . ": must not contain '/', '?', '#' or newline characters.";
    }
    if ( $value !~ /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/ ) {
        die "invalid " . $name . ": '" . $value . "' does not match the documented UUID format.";
    }
    return uri_escape($value);
}

# Builds a query string from the allow-listed keys only, so a stray key in
# the caller's hash cannot be appended to the URL.
sub _buildQueryString {
    my ($params, @allowedKeys) = @_;
    return "" unless defined($params) && ref($params) eq 'HASH';

    my @pairs;
    foreach my $key (@allowedKeys) {
        next unless defined($params -> {$key}) && $params -> {$key} ne "";
        push @pairs, uri_escape($key) . "=" . uri_escape($params -> {$key});
    }
    return @pairs ? "?" . join("&", @pairs) : "";
}

# The service answers failures as {"message": "..."}, so that text is used as
# the die message: a caller sees "target_url: must be an https URL" rather
# than a raw JSON blob. Falls back to the body, then to the status code.
sub _assertSuccess {
    my ($apiHelper, $apiResponseJSON) = @_;

    my $responseCode = $apiHelper -> responseCode();
    return if defined($responseCode) && $responseCode =~ /^2\d\d$/;

    my $message;
    if ( defined($apiResponseJSON) && $apiResponseJSON ne "" ) {
        my $parsed = eval { from_json($apiResponseJSON) };
        if ( !$@ && ref($parsed) eq 'HASH' && defined($parsed -> {'message'}) ) {
            $message = $parsed -> {'message'};
        }
        else {
            $message = $apiResponseJSON;
        }
    }
    else {
        $message = "Request failed with HTTP status "
            . ( defined($responseCode) ? $responseCode : "unknown" ) . ".";
    }

    die $message;
}

#
# List webhook endpoints (authenticated)
#
# Optional \%params: page, items.
#
# Endpoints carrying an event this key is not scoped for are filtered out by
# the service, so the result is what the key may manage rather than
# everything on the account.
#
# Returns the raw JSON body: {"data": [...], "page_info": {...}}. Note
# page_info "count" is the total number of matching endpoints, not the length
# of this page.
#
sub listWebhookEndpoints {
    my ($this, $params) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);

        my $apiUrl = "/endpoints" . _buildQueryString($params, qw(page items));
        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByGet($webhooksBaseURL, $apiUrl, $authHeader);

        _assertSuccess($apiHelper, $apiResponseJSON);

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Create a webhook endpoint (authenticated)
#
# Required \%params: target_url, events (arrayref).
#
# target_url must be an https URL resolving to a publicly routable address.
#
# Event names are not validated here on purpose: the catalog belongs to the
# service and grows without an SDK release. An unknown event comes back as
# 422, one this key is not scoped for as 403.
#
# Returns the raw JSON body, whose data carries "signing_secret" — the
# service returns it ONLY here. Store it on receipt; a lost secret means
# replacing the endpoint.
#
sub createWebhookEndpoint {
    my ($this, $params) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);

        die "params hashref with 'target_url' and 'events' is required."
            unless defined($params) && ref($params) eq 'HASH';
        die "target_url is required."
            unless defined($params -> {'target_url'}) && $params -> {'target_url'} ne "";
        die "events is required and must be a non-empty arrayref."
            unless defined($params -> {'events'})
                && ref($params -> {'events'}) eq 'ARRAY'
                && scalar(@{ $params -> {'events'} }) > 0;

        my $reqBody = to_json({
            target_url => $params -> {'target_url'},
            events     => $params -> {'events'},
        });

        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPost($webhooksBaseURL, "/endpoints", $authHeader, $reqBody);

        _assertSuccess($apiHelper, $apiResponseJSON);

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Get a webhook endpoint by UUID (authenticated)
#
# The response does not include the signing secret. A malformed UUID and
# another tenant's id both return 404 with the same message — the service
# gives no existence oracle.
#
sub getWebhookEndpoint {
    my ($this, $endpointId) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeId = _pathSegment($endpointId, name => 'endpointId');

        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByGet($webhooksBaseURL, "/endpoints/" . $safeId, $authHeader);

        _assertSuccess($apiHelper, $apiResponseJSON);

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Update a webhook endpoint (authenticated)
#
# Optional \%params: target_url, status ("active"|"disabled"), events
# (arrayref). Only the keys given are sent, so changing target_url leaves
# events and status untouched.
#
sub updateWebhookEndpoint {
    my ($this, $endpointId, $params) = @_;
    my $apiResponseJSON = "";
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeId = _pathSegment($endpointId, name => 'endpointId');

        die "params hashref is required."
            unless defined($params) && ref($params) eq 'HASH';

        my %body;
        foreach my $key (qw(target_url status events)) {
            $body{$key} = $params -> {$key} if defined($params -> {$key});
        }
        die "provide at least one of target_url, status, events." unless %body;

        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        $apiResponseJSON = $apiHelper->callToAPIByPatch(
            $webhooksBaseURL, "/endpoints/" . $safeId, $authHeader, to_json(\%body)
        );

        _assertSuccess($apiHelper, $apiResponseJSON);

    } catch($err) {
        die $err;
    };

    return $apiResponseJSON;
}

#
# Delete a webhook endpoint (authenticated)
#
# Stops every event on the endpoint. The service answers 204 with no body,
# so this returns 1 rather than a document.
#
sub deleteWebhookEndpoint {
    my ($this, $endpointId) = @_;
    try {
        my $authHeader = _getAuthHeader($this);
        my $safeId = _pathSegment($endpointId, name => 'endpointId');

        my $apiHelper = Paubox_Email_SDK::ApiHelper->new();
        my $apiResponseJSON = $apiHelper->callToAPIByDelete($webhooksBaseURL, "/endpoints/" . $safeId, $authHeader);

        _assertSuccess($apiHelper, $apiResponseJSON);

    } catch($err) {
        die $err;
    };

    return 1;
}

1;

__END__

=head1 NAME

Paubox_Webhooks_SDK - Manage Paubox webhook subscriptions

=head1 SYNOPSIS

  use Paubox_Webhooks_SDK;

  my $webhooks = Paubox_Webhooks_SDK->new('apiKey' => 'your-scoped-api-key');

  my $created = $webhooks->createWebhookEndpoint({
      target_url => 'https://hooks.example.com/paubox',
      events     => ['forms.submission.created'],
  });
  # The signing secret is in this response and nowhere else — store it now.

  my $list = $webhooks->listWebhookEndpoints({ page => 1, items => 50 });

=head1 DESCRIPTION

Client for the Paubox webhooks service: which URL Paubox notifies, and for
which events.

Authenticates with a Paubox scoped API key sent as C<Authorization: Bearer
E<lt>keyE<gt>> — the same scheme as L<Paubox_Forms_SDK>, and a different one
from the Email API's C<Token token=>. Every method requires a key; unlike the
Forms SDK there are no public endpoints.

Which events a key may subscribe to is decided by its scopes. Subscribing to
an event the key is not scoped for returns 403; an unrecognised event returns
422.

All methods return the raw JSON response body, except
C<deleteWebhookEndpoint>, which returns 1 because the service answers 204
with no body. Failures C<die> with the service's own message.

=head1 CONSTRUCTOR

=head2 new

  Paubox_Webhooks_SDK->new('apiKey' => '...')

Falls back to C<WEBHOOKS_API_KEY> in F<./config.cfg> when no key is passed.

=head1 METHODS

=head2 listWebhookEndpoints(\%params)

Optional keys: C<page>, C<items>. Returns C<{"data": [...], "page_info":
{...}}>. C<page_info.count> is the total, not the length of the page.

=head2 createWebhookEndpoint(\%params)

Required keys: C<target_url>, C<events> (arrayref). The response carries
C<signing_secret>, which the service returns only here.

=head2 getWebhookEndpoint($endpointId)

C<$endpointId> must be a UUID; anything else dies before a request is made.

=head2 updateWebhookEndpoint($endpointId, \%params)

Optional keys: C<target_url>, C<status> (C<active> or C<disabled>),
C<events>. Only the keys given are sent.

=head2 deleteWebhookEndpoint($endpointId)

Returns 1 on success.

=cut
