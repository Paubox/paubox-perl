package Paubox_Email_SDK::ReceivingTest;
use strict;
use warnings;

use Paubox_Email_SDK;
use Paubox_Email_SDK::ApiHelper;

use JSON;
use HTTP::Response;
use REST::Client;
use Test::More;
use base qw(Test::Class);

my $base = "https://api.paubox.com/v1/email";
my $emailId = "3f1c2b9e-7a4d-4e8f-9b21-6c5d0e4a7f13";
my $attachmentId = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d";

# Stubs REST::Client::request so the SDK runs end to end without network.
# Returns the recorded requests; the call's return value and error land in
# the optional 'result' / 'error' scalar refs.
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

sub _listFixture {
    return encode_json({
        'object'   => 'list',
        'has_more' => JSON::false,
        'data'     => [{
            'email_id'       => $emailId,
            'from'           => [{ 'name' => 'Sender', 'address' => 'sender@example.com' }],
            'to'             => [{ 'name' => undef, 'address' => 'inbox@receiving.example.com' }],
            'subject'        => 'Lab results',
            'received_at'    => '2026-10-01T12:00:00Z',
            'has_attachment' => JSON::true,
            'spam'           => JSON::false,
            'size'           => 20480,
            'domain'         => 'receiving.example.com',
        }],
    });
}

sub _detailFixture {
    return encode_json({
        'data' => {
            'email_id'       => $emailId,
            'from'           => [{ 'name' => 'Sender', 'address' => 'sender@example.com' }],
            'to'             => [{ 'name' => undef, 'address' => 'inbox@receiving.example.com' }],
            'cc'             => [],
            'subject'        => 'Lab results',
            'date'           => 'Thu, 01 Oct 2026 12:00:00 +0000',
            'received_at'    => '2026-10-01T12:00:00Z',
            'message_id'     => ['<abc@example.com>'],
            'in_reply_to'    => undef,
            'references'     => undef,
            'spam'           => JSON::false,
            'spam_score'     => 0.1,
            'text_body'      => 'See attached.',
            'html_body'      => undef,
            'attachments'    => [{
                'id'           => $attachmentId,
                'filename'     => 'results.pdf',
                'content_type' => 'application/pdf',
                'size'         => 1024,
                'content_id'   => undef,
                'download_url' => "$base/receiving/$emailId/attachments/$attachmentId",
            }],
            'size'           => 20480,
            'authentication' => { 'spf' => 'pass', 'dkim' => 'pass', 'dmarc' => 'pass' },
            'domain'         => 'receiving.example.com',
            'headers'        => [{ 'name' => 'Subject', 'value' => 'Lab results' }],
        },
    });
}

sub methodsExist_Offline: Tests(12) {
    print "Executing tests for methodsExist_Offline:\n";

    ok(Paubox_Email_SDK->can('listReceivingDomains'), 'listReceivingDomains exists');
    ok(Paubox_Email_SDK->can('createReceivingDomain'), 'createReceivingDomain exists');
    ok(Paubox_Email_SDK->can('getReceivingDomain'), 'getReceivingDomain exists');
    ok(Paubox_Email_SDK->can('deleteReceivingDomain'), 'deleteReceivingDomain exists');
    ok(Paubox_Email_SDK->can('listMailboxes'), 'listMailboxes exists');
    ok(Paubox_Email_SDK->can('createMailbox'), 'createMailbox exists');
    ok(Paubox_Email_SDK->can('getMailbox'), 'getMailbox exists');
    ok(Paubox_Email_SDK->can('deleteMailbox'), 'deleteMailbox exists');
    ok(Paubox_Email_SDK->can('listReceivedEmails'), 'listReceivedEmails exists');
    ok(Paubox_Email_SDK->can('getReceivedEmail'), 'getReceivedEmail exists');
    ok(Paubox_Email_SDK->can('getReceivedEmailAttachment'), 'getReceivedEmailAttachment exists');
    ok(Paubox_Email_SDK::ApiHelper->can('callToAPIByDelete'), 'ApiHelper callToAPIByDelete exists');
}

sub exportList_Offline: Tests(11) {
    print "Executing tests for exportList_Offline:\n";

    my @expected = qw(
        listReceivingDomains
        createReceivingDomain
        getReceivingDomain
        deleteReceivingDomain
        listMailboxes
        createMailbox
        getMailbox
        deleteMailbox
        listReceivedEmails
        getReceivedEmail
        getReceivedEmailAttachment
    );

    foreach my $method (@expected) {
        ok(
            (grep { $_ eq $method } @Paubox_Email_SDK::EXPORT_OK),
            "$method is in \@EXPORT_OK"
        );
    }
}

sub apiHelperDeleteExport_Offline: Tests(1) {
    print "Executing tests for apiHelperDeleteExport_Offline:\n";

    ok(
        (grep { $_ eq 'callToAPIByDelete' } @Paubox_Email_SDK::ApiHelper::EXPORT_OK),
        'callToAPIByDelete is in ApiHelper \@EXPORT_OK'
    );
}

sub apiHelperDeletePattern_Offline: Tests(1) {
    print "Executing tests for apiHelperDeletePattern_Offline:\n";

    require File::Spec;
    my $module = File::Spec->catfile('lib','Paubox_Email_SDK','ApiHelper.pm');
    open my $fh, '<', $module or die "cannot open $module: $!";
    local $/;
    my $src = <$fh>;
    close $fh;
    like($src, qr/\$client\s*->\s*DELETE\(/,
        'ApiHelper callToAPIByDelete uses REST::Client DELETE');
}

sub listReceivedEmails_QueryString_Offline: Tests(10) {
    print "Executing tests for listReceivedEmails_QueryString_Offline:\n";

    my $requests = _withStubbedHttp(
        'body' => _listFixture(),
        'call' => sub {
            Paubox_Email_SDK -> listReceivedEmails();
            Paubox_Email_SDK -> listReceivedEmails({
                'limit'     => 100,
                'after'     => $emailId,
                'before'    => $attachmentId,
                'search'    => 'lab results & more=yes',
                'sort'      => 'received_at',
                'ascending' => 1,
                'page'      => 2,
            });
            Paubox_Email_SDK -> listReceivedEmails({ 'ascending' => 0 });
            Paubox_Email_SDK -> listReceivedEmails({ 'ascending' => 'false' });
            Paubox_Email_SDK -> listReceivedEmails({ 'ascending' => 'true' });
            Paubox_Email_SDK -> listReceivedEmails({ 'ascending' => JSON::false });
            Paubox_Email_SDK -> listReceivedEmails({ 'ascending' => JSON::true });
        },
    );

    is(scalar(@{$requests}), 7, 'one request per call');
    is($requests -> [0]{'method'}, 'GET', 'uses GET');
    is($requests -> [0]{'url'}, "$base/receiving", 'no params: bare /receiving');
    is(
        $requests -> [1]{'url'},
        "$base/receiving?limit=100&after=$emailId&before=$attachmentId"
            . "&search=lab%20results%20%26%20more%3Dyes&sort=received_at&ascending=true",
        'all contract params sent, values escaped, unknown keys dropped'
    );
    like($requests -> [1]{'headers'}{'Authorization'}, qr/^Token token=/, 'sends the Email API auth header');
    is($requests -> [2]{'url'}, "$base/receiving?ascending=false", 'ascending 0 -> false');
    is($requests -> [3]{'url'}, "$base/receiving?ascending=false", 'ascending "false" -> false');
    is($requests -> [4]{'url'}, "$base/receiving?ascending=true", 'ascending "true" -> true');
    is($requests -> [5]{'url'}, "$base/receiving?ascending=false", 'ascending JSON::false -> false');
    is($requests -> [6]{'url'}, "$base/receiving?ascending=true", 'ascending JSON::true -> true');
}

sub listReceivedEmails_ListShape_Offline: Tests(6) {
    print "Executing tests for listReceivedEmails_ListShape_Offline:\n";

    my $body = _listFixture();
    _withStubbedHttp(
        'body'   => $body,
        'call'   => sub { Paubox_Email_SDK -> listReceivedEmails({ 'limit' => 1 }) },
        'result' => \my $response,
    );

    is($response, $body, 'returns the response body unchanged');
    my $list = decode_json($response);
    is($list -> {'object'}, 'list', 'object is list');
    ok(exists $list -> {'has_more'}, 'has_more present');
    is($list -> {'data'}[0]{'email_id'}, $emailId, 'items are keyed by email_id');
    ok(!exists $list -> {'data'}[0]{'blob_id'}, 'items carry no blob_id');
    is($list -> {'data'}[0]{'from'}[0]{'address'}, 'sender@example.com', 'addresses are {name, address}');
}

sub getReceivedEmail_DetailShape_Offline: Tests(7) {
    print "Executing tests for getReceivedEmail_DetailShape_Offline:\n";

    my $body = _detailFixture();
    my $requests = _withStubbedHttp(
        'body'   => $body,
        'call'   => sub { Paubox_Email_SDK -> getReceivedEmail($emailId) },
        'result' => \my $response,
    );

    is($requests -> [0]{'url'}, "$base/receiving/$emailId", 'GET /receiving/{email_id}');
    is($response, $body, 'returns the response body unchanged');
    my $detail = decode_json($response) -> {'data'};
    is($detail -> {'email_id'}, $emailId, 'detail is keyed by email_id');
    is($detail -> {'attachments'}[0]{'id'}, $attachmentId, 'attachments carry a Paubox id');
    ok(!exists $detail -> {'attachments'}[0]{'blob_id'}, 'attachments carry no blob_id');
    like($detail -> {'attachments'}[0]{'download_url'}, qr{/attachments/\Q$attachmentId\E$}, 'download_url uses the attachment id');
    is($detail -> {'authentication'}{'dmarc'}, 'pass', 'authentication results present');
}

sub getReceivedEmailAttachment_RawBytes_Offline: Tests(6) {
    print "Executing tests for getReceivedEmailAttachment_RawBytes_Offline:\n";

    my $bytes = "%PDF-1.7\n\x00\x01\x02\xff\xfe\xfd\r\n%%EOF";
    my $requests = _withStubbedHttp(
        'body'    => $bytes,
        'headers' => [
            'Content-Type'        => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="results.pdf"',
        ],
        'call'    => sub { Paubox_Email_SDK -> getReceivedEmailAttachment($emailId, $attachmentId) },
        'result'  => \my $response,
        'error'   => \my $error,
    );

    is($error, '', 'does not die on binary content');
    is(
        $requests -> [0]{'url'},
        "$base/receiving/$emailId/attachments/$attachmentId",
        'GET /receiving/{email_id}/attachments/{attachment_id}'
    );
    is(ref($response), '', 'returns a plain scalar');
    is(length($response), length($bytes), 'byte length preserved');
    ok($response eq $bytes, 'returns the raw file bytes');

    my $jsonFile = '{"not":"decoded"}';
    _withStubbedHttp(
        'body'    => $jsonFile,
        'headers' => [ 'Content-Type' => 'application/json' ],
        'call'    => sub { Paubox_Email_SDK -> getReceivedEmailAttachment($emailId, $attachmentId) },
        'result'  => \my $jsonResponse,
    );
    is($jsonResponse, $jsonFile, 'a JSON attachment is returned as bytes, not parsed');
}

sub getReceivedEmailAttachment_Non2xxDies_Offline: Tests(2) {
    print "Executing tests for getReceivedEmailAttachment_Non2xxDies_Offline:\n";

    my $notFound = '{"errors":[{"code":404,"title":"attachment not found"}]}';
    _withStubbedHttp(
        'status' => 404,
        'body'   => $notFound,
        'call'   => sub { Paubox_Email_SDK -> getReceivedEmailAttachment($emailId, 'legacy-blob-id') },
        'error'  => \my $error,
    );
    like($error, qr/attachment not found/, '404 dies with the error body instead of returning it as file bytes');

    _withStubbedHttp(
        'status' => 502,
        'body'   => '',
        'call'   => sub { Paubox_Email_SDK -> getReceivedEmailAttachment($emailId, $attachmentId) },
        'error'  => \my $emptyError,
    );
    like($emptyError, qr/HTTP status 502/, 'empty non-2xx body dies with the status');
}

sub receivingPathSegments_Offline: Tests(7) {
    print "Executing tests for receivingPathSegments_Offline:\n";

    my @invalid = (
        [ sub { Paubox_Email_SDK -> getReceivedEmail(undef) }, qr/email_id is required/, 'getReceivedEmail requires email_id' ],
        [ sub { Paubox_Email_SDK -> getReceivedEmailAttachment($emailId, '') }, qr/attachment_id is required/, 'getReceivedEmailAttachment requires attachment_id' ],
        [ sub { Paubox_Email_SDK -> getReceivedEmailAttachment(undef, $attachmentId) }, qr/email_id is required/, 'getReceivedEmailAttachment requires email_id' ],
        [ sub { Paubox_Email_SDK -> getReceivedEmail('..') }, qr/invalid email_id/, 'rejects a dot-segment email_id' ],
    );
    my $sent = 0;
    foreach my $case (@invalid) {
        my ($call, $pattern, $name) = @{$case};
        my $error;
        $sent += scalar(@{ _withStubbedHttp('body' => '', 'call' => $call, 'error' => \$error) });
        like($error, $pattern, $name);
    }
    is($sent, 0, 'no request is sent for invalid ids');

    my $escaped = _withStubbedHttp(
        'body' => '',
        'call' => sub { Paubox_Email_SDK -> getReceivedEmailAttachment('a/b', 'c?d#e') },
    );
    is($escaped -> [0]{'url'}, "$base/receiving/a%2Fb/attachments/c%3Fd%23e", 'attachment path segments are escaped');

    my $escapedEmail = _withStubbedHttp(
        'body' => '{}',
        'call' => sub { Paubox_Email_SDK -> getReceivedEmail('x/raw') },
    );
    is($escapedEmail -> [0]{'url'}, "$base/receiving/x%2Fraw", 'email path segment is escaped');
}

sub listReceivingDomains_Live: Tests(1) {
    print "Executing tests for listReceivingDomains_Live:\n";

    SKIP: {
        skip "config.cfg not present; skipping live receiving tests", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        my $response = eval { $service -> listReceivingDomains() };

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

sub receivedEmails_Live: Tests(5) {
    print "Executing tests for receivedEmails_Live:\n";

    SKIP: {
        skip "config.cfg not present; skipping live receiving tests", 5
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        my $list = eval { from_json($service -> listReceivedEmails({ 'limit' => 1 })) };
        if ($@ || ref($list) ne 'HASH') {
            fail('listReceivedEmails failed: ' . ($@ || 'unexpected response type'));
            skip "no list response", 4;
        }
        is($list -> {'object'}, 'list', 'listReceivedEmails returns a list object');

        my $item = $list -> {'data'}[0];
        skip "no received emails on this account", 3 unless $item;
        ok(defined $item -> {'email_id'} && !exists $item -> {'blob_id'}, 'list items are keyed by email_id');

        my $detail = eval { from_json($service -> getReceivedEmail($item -> {'email_id'})) -> {'data'} };
        is(ref($detail) eq 'HASH' ? $detail -> {'email_id'} : $@, $item -> {'email_id'}, 'getReceivedEmail resolves the email_id');

        my $attachment = ref($detail) eq 'HASH' ? $detail -> {'attachments'}[0] : undef;
        skip "latest received email has no attachments", 2 unless $attachment;
        ok(defined $attachment -> {'id'} && !exists $attachment -> {'blob_id'}, 'attachments are keyed by id');

        my $bytes = eval { $service -> getReceivedEmailAttachment($detail -> {'email_id'}, $attachment -> {'id'}) };
        if ($@) {
            fail('getReceivedEmailAttachment failed: ' . $@);
        } elsif (defined $attachment -> {'size'}) {
            is(length($bytes), $attachment -> {'size'}, 'downloaded byte count matches the attachment size');
        } else {
            ok(defined $bytes, 'downloaded attachment bytes');
        }
    }
}

1;
