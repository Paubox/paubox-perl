<img src="https://avatars.githubusercontent.com/u/22528478?s=200&v=4" alt="Paubox" width="150px">

# Paubox Perl

This is the official Perl wrapper for the [Paubox Email API](https://www.paubox.com/solutions/email-api).

The Paubox Email API allows your application to send secure, HIPAA compliant email via Paubox and track deliveries and opens. The API wrapper also allows you to construct and send messages.

# Table of Contents
* [Installation](#installation)
* [Usage](#usage)
  * [Email API](#email-api)
  * [Forms API](#forms-api)
* [Contributing](#contributing)
* [License](#license)

<a name="#installation"></a>
## Installation

If you have App::cpanminus installed, you can install the module from CPAN like this:

```bash
cpanm Paubox_Email_SDK
```

Otherwise, you can install from the included archive.

```bash
git clone https://github.com/Paubox/paubox-perl-sdk.git
cd paubox-perl-sdk
cpanm Paubox_Email_SDK-1.2.tar.gz
```

### Getting Paubox API Credentials
You will need to have a Paubox account. You can [sign up here](https://www.paubox.com/join/see-pricing?unit=messages).

Once you have an account, follow the instructions on the Rest API dashboard to verify domain ownership and generate API credentials.

### Configuring API Credentials

Include your API credentials in "config.cfg" configuration file.

```bash
echo "API_KEY = YOUR_API_KEY" > config.cfg
echo "API_USERNAME = YOUR_ENDPOINT_NAME" >> config.cfg
echo "config.cfg" >> .gitignore
```

<a name="#usage"></a>
## Usage

<a name="#email-api"></a>
### Email API

To send an email, prepare a Message object and call the sendMessage method of Paubox_Email_SDK.

### Sending messages

```perl
use strict;
use warnings;
use Paubox_Email_SDK;

my $messageObj = new Paubox_Email_SDK::Message(
   'from' => 'sender@domain.com',   
   'to' => ['recipient@example.com'],
   'subject' => 'Testing!',
   'text_content' => 'Hello World!',
   'html_content' => '<html><body><h1>Hello World!</h1></body></html>'  
);

my $service = Paubox_Email_SDK -> new();
my $response = $service -> sendMessage($messageObj);
print $response;
```

### Allowing non-TLS message delivery

If you want to send non-PHI mail that does not need to be HIPAA-compliant, you can allow the message delivery to take place even if a TLS connection is unavailable.

This means the message will not be converted into a secure portal message when a nonTLS connection is encountered. To do this, include 'allowNonTLS' => 1 in the messageObj, as shown below:

```perl
use strict;
use warnings;
use Paubox_Email_SDK;

my $messageObj = new Paubox_Email_SDK::Message(
   'allowNonTLS' => 1,	
   'from' => 'sender@domain.com',   
   'to' => ['recipient@example.com'],
   'subject' => 'Testing!',
   'text_content' => 'Hello World!',
   'html_content' => '<html><body><h1>Hello World!</h1></body></html>'  
);
```

### Forcing Secure Notifications
Paubox Secure Notifications allow an extra layer of security, especially when coupled with an organization's requirement for message recipients to use 2-factor authentication to read messages (this setting is available to org administrators in the Paubox Admin Panel).

Instead of receiving an email with the message contents, the recipient will receive a notification email that they have a new message in Paubox.

```perl
use strict;
use warnings;
use Paubox_Email_SDK;

my $messageObj = new Paubox_Email_SDK::Message(
   'forceSecureNotification' => 'true',	
   'from' => 'sender@domain.com',   
   'to' => ['recipient@example.com'],
   'subject' => 'Testing!',
   'text_content' => 'Hello World!',
   'html_content' => '<html><body><h1>Hello World!</h1></body></html>'  
);
```

### Adding Attachments and Additional Headers

```perl
use strict;
use warnings;
use Paubox_Email_SDK;

use JSON;
use MIME::Base64;
use String::Util qw(trim);

my $encodedAttachmentContent = trim (encode_base64("Hello! This is the attachment content!") );

my $attachment = '[{
        "fileName": "hello_world.txt",
        "contentType": "text/plain",
        "content": "'.$encodedAttachmentContent.
      '" }]';

my @decoded_json_attachment = @{decode_json($attachment)};

my $messageObj = new Paubox_Email_SDK::Message(
   'from' => 'sender@domain.com',  
   'replyTo' => 'sender@domain.com', 
   'to' => ['recipient@example.com'],
   'bcc' => ['recipient@example.com'],
   'cc' => ['recipientcc@example.com'],
   'subject' => 'Testing!',
   'text_content' => 'Hello World!',
   'html_content' => '<html><body><h1>Hello World!</h1></body></html>', 
   'attachments' => [@decoded_json_attachment]
);
```


### Checking Email Dispositions

The SOURCE_TRACKING_ID of a message is returned in the response of the sendMessage method. To check the status for any email, use its source tracking id and call the getEmailDisposition method of Paubox_Email_SDK:

```perl
use strict;
use warnings;
use Paubox_Email_SDK;

my $service = Paubox_Email_SDK -> new();
my $response = $service -> getEmailDisposition("SOURCE_TRACKING_ID");
print $response;
```

<a name="#forms-api"></a>
### Forms API

The Paubox Forms API lets you retrieve form definitions and submit responses. These
endpoints are **public** — no API key or `config.cfg` is required.

The SDK also covers the authenticated form-management endpoints (listing, creating,
updating, archiving and copying forms, plus submission exports). See
[Managing forms](#managing-forms-authenticated) below.

#### Retrieving a form

```perl
use strict;
use warnings;
use Paubox_Forms_SDK;

my $forms = Paubox_Forms_SDK->new();
my $response = $forms->getForm("your-form-uuid");
print $response;
# Returns JSON with id, title, form_html, form_json, form_css, etc.
```

#### Submitting a form response

```perl
use strict;
use warnings;
use Paubox_Forms_SDK;

my $forms = Paubox_Forms_SDK->new();
my $response = $forms->submitForm(
    "your-form-uuid",
    { first_name => "Jane", last_name => "Doe", email => "jane\@example.com" }
);
# Returns empty body on success (HTTP 201)
```

#### Submitting a form response with attachments

Attachments must be base64-encoded. The maximum total request size is 250 MB.

```perl
use strict;
use warnings;
use Paubox_Forms_SDK;
use MIME::Base64;

my $forms = Paubox_Forms_SDK->new();

open(my $fh, '<:raw', 'consent.pdf') or die "Cannot open file: $!";
local $/;
my $encoded = encode_base64(<$fh>);
close($fh);

my $response = $forms->submitForm(
    "your-form-uuid",
    { first_name => "Jane", signature => "{signature_field}" },
    [ { name => "consent.pdf", content => $encoded } ]
);
```

<a name="#managing-forms-authenticated"></a>
#### Managing forms (authenticated)

The form-management methods (`listForms`, `getFormById`, `createForm`, `updateForm`,
`archiveForm`, `unarchiveForm`, `copyForm`, `getFormStats`, `listFormSubmissions`,
`getSubmissionsCsv`, `getSubmissionPdf`) require a **scoped API key**. Scoped API keys
are generated in the Paubox admin dashboard and must include the `forms` scope.

Pass the key to the constructor, or set `FORMS_API_KEY` in `config.cfg` and it will be
picked up automatically:

```perl
use strict;
use warnings;
use Paubox_Forms_SDK;

# Explicitly:
my $service = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_API_KEY');

# Or via config.cfg containing: FORMS_API_KEY = YOUR_SCOPED_API_KEY
my $service2 = Paubox_Forms_SDK->new();
```

#### Listing and creating forms

```perl
use strict;
use warnings;
use Paubox_Forms_SDK;

my $service = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_API_KEY');

# customer_id is required when using a scoped API key (your own customer id,
# or a related customer's id) — the server responds 403 Forbidden without it.
my $formList = $service->listForms({
    'customer_id' => 123,
    'search'      => 'intake',
    'items'       => 10,
});
print $formList;
# Returns JSON with "results" (array of forms) and "page_info"

my $created = $service->createForm({
    'title'       => 'Patient Intake',
    'form_json'   => { 'fields' => [] },
    'customer_id' => 123,
});
print $created;
# Returns JSON with the new form's "id"
```

#### Exporting a submission as PDF

`getSubmissionPdf` returns raw PDF bytes (and `getSubmissionsCsv` returns raw CSV text),
so write them straight to a file:

```perl
use strict;
use warnings;
use Paubox_Forms_SDK;

my $service = Paubox_Forms_SDK->new('apiKey' => 'YOUR_SCOPED_API_KEY');
my $pdf = $service->getSubmissionPdf("your-form-uuid", "submission-id");

open(my $fh, '>:raw', 'submission.pdf') or die "Cannot open file: $!";
print $fh $pdf;
close($fh);
```

See [api.md](api.md) for the full Forms API reference.

<a name="#contributing"></a>
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paubox/paubox-perl-sdk.


<a name="#license"></a>
## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Copyright
Copyright &copy; 2021, Paubox, Inc.

## 💬 Community & support

Questions, ideas, or want to share what you built? Join the **[Paubox Community](https://github.com/Paubox/community/discussions)** — the single home for discussions across every Paubox SDK and API.

🔐 Found a security issue? Email **devops@paubox.com** — please don't post it publicly.
