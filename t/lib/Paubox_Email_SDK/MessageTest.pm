package Paubox_Email_SDK::MessageTest;
use strict;
use warnings;

use Paubox_Email_SDK;
use Paubox_Email_SDK::Message;
use Paubox_Email_SDK::ReceivingTest ();

use JSON;
use Test::More;
use base qw(Test::Class);

# Response shapes from pb_email_api `create` (CreateResponse) and V1Error::into_response.
my $sendOk = encode_json({ 'sourceTrackingId' => '6e1cf9a4-7bde-4834-8200-ed424b50c8a7', 'data' => 'Service OK' });
my $badRequest = encode_json({ 'errors' => [{ 'code' => 400, 'title' => 'Bad Request', 'details' => 'invalid data' }] });

sub _send {
    my (%args) = @_;
    my $message = Paubox_Email_SDK::Message -> new(
        'from' => 'sender@example.com',
        'to' => ['recipient@example.com'],
        'subject' => 'Test',
        'text_content' => 'Hello',
        %{ $args{'message'} || {} },
    );
    my $service = $args{'service'} || 'Paubox_Email_SDK';
    my $method = $args{'method'} || 'sendMessage';
    my @extra = $method eq 'scheduleMessage' ? ('2030-01-01T00:00:00Z') : ();
    my $requests = Paubox_Email_SDK::ReceivingTest::_withStubbedHttp(
        'status' => $args{'status'},
        'body'   => $args{'body'} || $sendOk,
        'call'   => sub { $service -> $method($message, @extra) },
        'result' => $args{'result'},
        'error'  => $args{'error'},
    );
    return decode_json($requests -> [0]{'content'}) -> {'data'}{'message'};
}

sub allowNonTLS_SentAsJsonBoolean_Offline: Tests(14) {
    print "Executing tests for allowNonTLS_SentAsJsonBoolean_Offline:\n";

    my @cases = (
        [ {},                         JSON::false, 'default' ],
        [ { 'allowNonTLS' => 0 },     JSON::false, '0' ],
        [ { 'allowNonTLS' => 1 },     JSON::true,  '1' ],
        [ { 'allowNonTLS' => 'true' },  JSON::true,  "'true'" ],
        [ { 'allowNonTLS' => 'false' }, JSON::false, "'false'" ],
        [ { 'allowNonTLS' => JSON::true }, JSON::true, 'JSON::true' ],
    );
    foreach my $case (@cases) {
        my ($fields, $expected, $label) = @{$case};
        my $sent = _send('message' => $fields);
        ok(JSON::is_bool($sent -> {'allowNonTLS'}), "sendMessage $label: allowNonTLS is a JSON boolean");
        is(0 + $sent -> {'allowNonTLS'}, 0 + $expected, "sendMessage $label: allowNonTLS value");
    }

    my $scheduled = _send('method' => 'scheduleMessage');
    ok(JSON::is_bool($scheduled -> {'allowNonTLS'}), 'scheduleMessage: allowNonTLS is a JSON boolean');
    ok(!$scheduled -> {'allowNonTLS'}, 'scheduleMessage: allowNonTLS defaults to false');
}

sub responseCode_ExposesHttpStatus_Offline: Tests(5) {
    print "Executing tests for responseCode_ExposesHttpStatus_Offline:\n";

    my $service = bless {}, 'Paubox_Email_SDK';
    is($service -> responseCode(), undef, 'undef before any request');

    _send('service' => $service, 'status' => 400, 'body' => $badRequest,
        'result' => \my $result, 'error' => \my $error);
    is($error, '', 'an API error does not die');
    is($result, $badRequest, 'the error body is returned');
    is($service -> responseCode(), 400, 'responseCode reports the HTTP status');

    _send('service' => $service);
    is($service -> responseCode(), 200, 'responseCode tracks the latest request');
}

1;
