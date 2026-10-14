package Paubox_Webhooks_SDK::Test;
use strict;
use warnings;

use Paubox_Webhooks_SDK;
use Paubox_Email_SDK::ApiHelper;

use JSON;
use HTTP::Response;
use REST::Client;
use Test::More;
use base qw(Test::Class);

my $apiKey     = 'scoped-test-key';
my $base       = 'https://api.paubox.com/v1/webhooks';
my $endpointId = '2ec66c21-bf48-48eb-8d28-f80b2d6b77c7';

sub _client { return Paubox_Webhooks_SDK -> new('apiKey' => $apiKey); }

sub _endpoint {
    return {
        'id'         => $endpointId,
        'target_url' => 'https://hooks.example.com/paubox',
        'status'     => 'active',
        'events'     => ['forms.submission.created'],
        'created_at' => '2026-10-09T01:43:41.639968+00:00',
        'updated_at' => '2026-10-09T01:43:41.639968+00:00',
    };
}

# Stubs REST::Client::request so the SDK runs end to end without network,
# borrowed from ReceivingTest. The legacy webhook tests had no equivalent and
# skipped every behavioural assertion unless a config.cfg happened to exist,
# which meant they asserted nothing in CI.
sub _withStubbedHttp {
    my (%args) = @_;
    my @requests;
    {
        no warnings 'redefine';
        local *REST::Client::request = sub {
            my ($self, $method, $url, $content, $headers) = @_;
            push @requests, {
                'method'  => $method,
                'url'     => $self -> getHost() . $url,
                'body'    => $content,
                'headers' => { %{ $self -> {'_headers'} || {} } },
            };
            $self -> {'_res'} = HTTP::Response -> new(
                $args{'status'} || 200, undef, $args{'headers'} || [], $args{'body'}
            );
            return $self;
        };
        my $result = eval { $args{'call'} -> () };
        my $error = $@;
        ${ $args{'result'} } = $result if $args{'result'};
        ${ $args{'error'} } = $error if $args{'error'};
    }
    return \@requests;
}

sub methodsExist_Offline: Tests(5) {
    ok(Paubox_Webhooks_SDK->can($_), "$_ exists") for qw(
        listWebhookEndpoints createWebhookEndpoint getWebhookEndpoint
        updateWebhookEndpoint deleteWebhookEndpoint
    );
}

sub exportList_Offline: Tests(5) {
    foreach my $method (qw(
        listWebhookEndpoints createWebhookEndpoint getWebhookEndpoint
        updateWebhookEndpoint deleteWebhookEndpoint
    )) {
        ok(
            (grep { $_ eq $method } @Paubox_Webhooks_SDK::EXPORT_OK),
            "$method is in \@EXPORT_OK"
        );
    }
}

sub list_SendsBearerToEndpointsResource_Offline: Tests(3) {
    my $body = encode_json({ 'data' => [_endpoint()], 'page_info' => { 'count' => 1, 'items' => 50 } });
    my $result;
    my $requests = _withStubbedHttp(
        'body' => $body, 'result' => \$result,
        'call' => sub { _client() -> listWebhookEndpoints() },
    );

    is($requests -> [0] -> {'method'}, 'GET', 'uses GET');
    is($requests -> [0] -> {'url'}, "$base/endpoints", 'hits the endpoints resource');
    # Bearer, not the Email API's "Token token=".
    is($requests -> [0] -> {'headers'} -> {'Authorization'}, "Bearer $apiKey", 'sends Bearer auth');
}

sub list_CountIsTheTotalNotThePageLength_Offline: Tests(2) {
    my $body = encode_json({ 'data' => [_endpoint()], 'page_info' => { 'count' => 2, 'items' => 1 } });
    my $result;
    _withStubbedHttp(
        'body' => $body, 'result' => \$result,
        'call' => sub { _client() -> listWebhookEndpoints() },
    );

    my $parsed = decode_json($result);
    is($parsed -> {'page_info'} -> {'count'}, 2, 'count is the total');
    is(scalar(@{ $parsed -> {'data'} }), 1, 'data holds only this page');
}

sub list_SendsPagination_Offline: Tests(1) {
    my $requests = _withStubbedHttp(
        'body' => encode_json({ 'data' => [], 'page_info' => {} }),
        'call' => sub { _client() -> listWebhookEndpoints({ 'page' => 2, 'items' => 1 }) },
    );

    is($requests -> [0] -> {'url'}, "$base/endpoints?page=2&items=1", 'appends pagination');
}

sub create_ReturnsSigningSecret_Offline: Tests(3) {
    my $created = { %{ _endpoint() }, 'signing_secret' => 'whsec_abc123' };
    my $body = encode_json({ 'data' => $created, 'message' => 'Store this signing_secret now' });
    my $result;
    my $requests = _withStubbedHttp(
        'status' => 201, 'body' => $body, 'result' => \$result,
        'call' => sub {
            _client() -> createWebhookEndpoint({
                'target_url' => 'https://hooks.example.com/paubox',
                'events'     => ['forms.submission.created'],
            });
        },
    );

    is($requests -> [0] -> {'method'}, 'POST', 'uses POST');
    my $sent = decode_json($requests -> [0] -> {'body'});
    is($sent -> {'target_url'}, 'https://hooks.example.com/paubox', 'sends target_url');
    # The service returns the secret only here; losing it means replacing the
    # endpoint.
    is(decode_json($result) -> {'data'} -> {'signing_secret'}, 'whsec_abc123', 'returns the signing secret');
}

sub create_ValidatesLocally_Offline: Tests(3) {
    my $client = _client();

    eval { $client -> createWebhookEndpoint("not-a-hash") };
    like($@, qr/params hashref/, 'rejects a non-hashref');

    eval { $client -> createWebhookEndpoint({ 'events' => ['x'] }) };
    like($@, qr/target_url is required/, 'rejects a missing target_url');

    eval { $client -> createWebhookEndpoint({ 'target_url' => 'https://e.test/h', 'events' => [] }) };
    like($@, qr/events is required/, 'rejects empty events');
}

# The catalog belongs to the service and grows without an SDK release, so an
# unrecognised name must reach the server rather than be rejected here.
sub create_DoesNotValidateEventNames_Offline: Tests(1) {
    my $requests = _withStubbedHttp(
        'status' => 201, 'body' => encode_json({ 'data' => _endpoint() }),
        'call' => sub {
            _client() -> createWebhookEndpoint({
                'target_url' => 'https://e.test/h',
                'events'     => ['some.future.event'],
            });
        },
    );

    is_deeply(
        decode_json($requests -> [0] -> {'body'}) -> {'events'},
        ['some.future.event'],
        'forwards an unknown event unchanged'
    );
}

sub get_RequestsTheEndpoint_Offline: Tests(2) {
    my $result;
    my $requests = _withStubbedHttp(
        'body' => encode_json({ 'data' => _endpoint() }), 'result' => \$result,
        'call' => sub { _client() -> getWebhookEndpoint($endpointId) },
    );

    is($requests -> [0] -> {'url'}, "$base/endpoints/$endpointId", 'hits the endpoint by id');
    is(decode_json($result) -> {'data'} -> {'id'}, $endpointId, 'returns the endpoint');
}

sub get_RejectsBadIds_Offline: Tests(4) {
    my $client = _client();

    foreach my $bad ('not-a-uuid', '../endpoints', '') {
        eval { $client -> getWebhookEndpoint($bad) };
        ok($@, "refuses " . ($bad eq '' ? "an empty id" : "'$bad'"));
    }

    eval { $client -> getWebhookEndpoint('<uuid>/../events') };
    like($@, qr/must not contain/, 'names the reason for a path-bearing id');
}

sub update_SendsOnlyTheKeysGiven_Offline: Tests(2) {
    my $requests = _withStubbedHttp(
        'body' => encode_json({ 'data' => { %{ _endpoint() }, 'status' => 'disabled' } }),
        'call' => sub { _client() -> updateWebhookEndpoint($endpointId, { 'status' => 'disabled' }) },
    );

    is($requests -> [0] -> {'method'}, 'PATCH', 'uses PATCH');
    is_deeply(decode_json($requests -> [0] -> {'body'}), { 'status' => 'disabled' }, 'omits unset keys');
}

sub update_RefusesAnEmptyChange_Offline: Tests(1) {
    eval { _client() -> updateWebhookEndpoint($endpointId, {}) };
    like($@, qr/at least one of/, 'refuses an update with nothing to change');
}

sub delete_HandlesEmpty204_Offline: Tests(3) {
    my $result;
    my $requests = _withStubbedHttp(
        'status' => 204, 'body' => '', 'result' => \$result,
        'call' => sub { _client() -> deleteWebhookEndpoint($endpointId) },
    );

    is($requests -> [0] -> {'method'}, 'DELETE', 'uses DELETE');
    is($requests -> [0] -> {'url'}, "$base/endpoints/$endpointId", 'hits the endpoint by id');
    is($result, 1, 'returns 1 since there is no body');
}

sub errors_PromoteTheServiceMessage_Offline: Tests(1) {
    my $error;
    _withStubbedHttp(
        'status' => 422,
        'body'   => encode_json({ 'message' => 'target_url: must be an https URL' }),
        'error'  => \$error,
        'call'   => sub {
            _client() -> createWebhookEndpoint({
                'target_url' => 'http://insecure.test', 'events' => ['x'],
            });
        },
    );

    like($error, qr/target_url: must be an https URL/, 'dies with the service message, not raw JSON');
}

sub errors_NameTheEventOn403_Offline: Tests(1) {
    my $error;
    _withStubbedHttp(
        'status' => 403,
        'body'   => encode_json({ 'message' => "events: not entitled to 'api_mail_log_delivered'" }),
        'error'  => \$error,
        'call'   => sub { _client() -> listWebhookEndpoints() },
    );

    like($error, qr/not entitled/, 'surfaces the refused event');
}

# A duplicate target_url is 422, not 409 — error handling keyed on 409 misses it.
sub errors_DuplicateTargetUrlIs422_Offline: Tests(1) {
    my $error;
    _withStubbedHttp(
        'status' => 422,
        'body'   => encode_json({ 'message' => 'target_url: an endpoint already exists for this URL' }),
        'error'  => \$error,
        'call'   => sub {
            _client() -> createWebhookEndpoint({ 'target_url' => 'https://e.test/h', 'events' => ['x'] });
        },
    );

    like($error, qr/already exists/, 'surfaces the duplicate-URL message');
}

sub errors_FallBackToTheRawBody_Offline: Tests(1) {
    my $error;
    _withStubbedHttp(
        'status' => 500, 'body' => 'plain text failure', 'error' => \$error,
        'call'   => sub { _client() -> listWebhookEndpoints() },
    );

    like($error, qr/plain text failure/, 'falls back to the body when it is not the usual shape');
}

sub missingApiKey_DiesBeforeAnyRequest_Offline: Tests(2) {
    my $client = Paubox_Webhooks_SDK -> new();
    # A config.cfg in the working directory would supply a key and defeat this.
    return if -e 'config.cfg';

    my $requests = _withStubbedHttp(
        'call' => sub { $client -> listWebhookEndpoints() },
    );

    is(scalar(@$requests), 0, 'no request is made');
    eval { $client -> listWebhookEndpoints() };
    like($@, qr/apiKey is required/, 'names the missing key');
}

1;
