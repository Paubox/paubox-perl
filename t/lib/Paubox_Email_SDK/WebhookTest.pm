package Paubox_Email_SDK::WebhookTest;
use strict;
use warnings;

use Paubox_Email_SDK;
use Paubox_Email_SDK::ApiHelper;
use Paubox_Email_SDK::ReceivingTest ();

use JSON;
use Test::More;
use base qw(Test::Class);

sub methodsExist_Offline: Tests(5) {
    print "Executing tests for webhook methodsExist_Offline:\n";

    ok(Paubox_Email_SDK->can('listWebhookEndpoints'), 'listWebhookEndpoints exists');
    ok(Paubox_Email_SDK->can('createWebhookEndpoint'), 'createWebhookEndpoint exists');
    ok(Paubox_Email_SDK->can('getWebhookEndpoint'), 'getWebhookEndpoint exists');
    ok(Paubox_Email_SDK->can('updateWebhookEndpoint'), 'updateWebhookEndpoint exists');
    ok(Paubox_Email_SDK->can('deleteWebhookEndpoint'), 'deleteWebhookEndpoint exists');
}

sub exportList_Offline: Tests(5) {
    print "Executing tests for webhook exportList_Offline:\n";

    my @expected = qw(
        listWebhookEndpoints
        createWebhookEndpoint
        getWebhookEndpoint
        updateWebhookEndpoint
        deleteWebhookEndpoint
    );

    foreach my $method (@expected) {
        ok(
            (grep { $_ eq $method } @Paubox_Email_SDK::EXPORT_OK),
            "$method is in \@EXPORT_OK"
        );
    }
}

sub createWebhookEndpoint_RejectsNonHash_Offline: Tests(1) {
    print "Executing tests for createWebhookEndpoint_RejectsNonHash_Offline:\n";

    SKIP: {
        skip "config.cfg not present; skipping", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        eval { $service -> createWebhookEndpoint("not-a-hash") };
        like($@, qr/params must be a hash reference/, 'rejects non-hash params');
    }
}

sub createWebhookEndpoint_RejectsMissingTargetUrl_Offline: Tests(1) {
    print "Executing tests for createWebhookEndpoint_RejectsMissingTargetUrl_Offline:\n";

    SKIP: {
        skip "config.cfg not present; skipping", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        eval { $service -> createWebhookEndpoint({ 'events' => ['api_mail_log_delivered'] }) };
        like($@, qr/target_url is required/, 'rejects missing target_url');
    }
}

sub createWebhookEndpoint_RejectsMissingEvents_Offline: Tests(1) {
    print "Executing tests for createWebhookEndpoint_RejectsMissingEvents_Offline:\n";

    SKIP: {
        skip "config.cfg not present; skipping", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        eval { $service -> createWebhookEndpoint({ 'target_url' => 'https://example.com' }) };
        like($@, qr/events is required/, 'rejects missing events');
    }
}

sub updateWebhookEndpoint_RejectsNonHash_Offline: Tests(1) {
    print "Executing tests for updateWebhookEndpoint_RejectsNonHash_Offline:\n";

    SKIP: {
        skip "config.cfg not present; skipping", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        eval { $service -> updateWebhookEndpoint(1, "not-a-hash") };
        like($@, qr/params must be a hash reference/, 'rejects non-hash params');
    }
}

sub listWebhookEndpoints_Live: Tests(1) {
    print "Executing tests for listWebhookEndpoints_Live:\n";

    SKIP: {
        skip "config.cfg not present; skipping live webhook tests", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        my $response = eval { $service -> listWebhookEndpoints() };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        my $apiResponsePERL = from_json($response);
        if ( ref($apiResponsePERL) eq 'ARRAY' || ref($apiResponsePERL) eq 'HASH' ) {
            is('Success', 'Success', 'Test passed');
        } else {
            is('Failure', 'Success', 'Test failed: unexpected response type');
        }
    }
}

# pb_email_api WebhookParams declares `active: Option<bool>`, so integers are rejected.
sub webhookActive_SentAsJsonBoolean_Offline: Tests(6) {
    print "Executing tests for webhookActive_SentAsJsonBoolean_Offline:\n";

    my $created = encode_json({ 'message' => 'Webhook created!', 'data' => { 'id' => 42 } });
    my $params = { 'target_url' => 'https://example.com/hook', 'events' => ['api_mail_log_delivered'], 'active' => 1 };
    my $requests = Paubox_Email_SDK::ReceivingTest::_withStubbedHttp(
        'status' => 201,
        'body'   => $created,
        'call'   => sub { Paubox_Email_SDK -> createWebhookEndpoint($params) },
    );
    my $sent = decode_json($requests -> [0]{'content'});
    ok(JSON::is_bool($sent -> {'active'}), 'create: active is a JSON boolean');
    ok($sent -> {'active'}, 'create: active => 1 sends true');
    is($params -> {'active'}, 1, "create: caller's hash is not modified");

    $requests = Paubox_Email_SDK::ReceivingTest::_withStubbedHttp(
        'body' => encode_json({ 'data' => { 'id' => 42 } }),
        'call' => sub { Paubox_Email_SDK -> updateWebhookEndpoint(42, { 'active' => 0 }) },
    );
    $sent = decode_json($requests -> [0]{'content'});
    ok(JSON::is_bool($sent -> {'active'}), 'update: active is a JSON boolean');
    ok(!$sent -> {'active'}, 'update: active => 0 sends false');

    $requests = Paubox_Email_SDK::ReceivingTest::_withStubbedHttp(
        'body' => encode_json({ 'data' => { 'id' => 42 } }),
        'call' => sub { Paubox_Email_SDK -> updateWebhookEndpoint(42, { 'target_url' => 'https://example.com/new' }) },
    );
    ok(!exists decode_json($requests -> [0]{'content'}) -> {'active'}, 'update: active is omitted when not given');
}

1;
