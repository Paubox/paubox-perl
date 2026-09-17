package Paubox_Email_SDK::WebhookTest;
use strict;
use warnings;

use Paubox_Email_SDK;
use Paubox_Email_SDK::ApiHelper;

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

1;
